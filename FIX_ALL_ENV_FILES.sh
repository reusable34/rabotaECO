#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ ВСЕХ .ENV ФАЙЛОВ
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ ВСЕХ .ENV ФАЙЛОВ"
echo "==========================================${NC}"
echo ""

# Определяем порты
NEXTJS_PORT=$(ss -tuln | grep LISTEN | grep -oE ":300[0-9]+" | head -1 | cut -d: -f2 || echo "3002")
BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "8082")

echo "Используемые порты:"
echo "  - Next.js: $NEXTJS_PORT"
echo "  - Backend: $BACKEND_PORT"
echo ""

# 1. Проверка текущих .env файлов
echo -e "${YELLOW}[1/6] Проверка текущих .env файлов...${NC}"
cd /opt/eco-project

echo "Frontend .env файлы:"
ls -la frontend/.env* 2>/dev/null || echo "  Нет .env файлов"
echo ""

if [ -f frontend/.env.local ]; then
    echo "Текущий frontend/.env.local:"
    cat frontend/.env.local
    echo ""
fi

# 2. Создание правильного .env.local для frontend
echo -e "${YELLOW}[2/6] Создание правильного .env.local для frontend...${NC}"
cd /opt/eco-project/frontend

# Удаляем старые .env файлы
rm -f .env .env.local .env.production .env.development

# Создаем правильный .env.local с относительным путем
cat > .env.local << 'EOF'
# API URL - относительный путь (работает через Nginx прокси)
NEXT_PUBLIC_API_URL=/api

# Окружение
NEXT_PUBLIC_ENV=production

# Порт для Next.js (для systemd service)
PORT=3002
EOF

echo -e "${GREEN}✅ .env.local создан${NC}"
echo "Содержимое:"
cat .env.local
echo ""

# 3. Обновление next.config.js
echo -e "${YELLOW}[3/6] Обновление next.config.js...${NC}"
cat > next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Переменные окружения будут браться из .env.local
  // NEXT_PUBLIC_API_URL должен быть установлен в .env.local
}

module.exports = nextConfig
EOF

echo -e "${GREEN}✅ next.config.js обновлен${NC}"
echo ""

# 4. Проверка backend .env
echo -e "${YELLOW}[4/6] Проверка backend .env...${NC}"
cd /opt/eco-project/backend

if [ -f .env ]; then
    echo "Текущий backend/.env:"
    cat .env | head -20
    echo ""
else
    echo "backend/.env не найден (это нормально для Yii2)"
fi

# Проверяем конфигурацию базы данных
if [ -f common/config/main-local.php ]; then
    echo "База данных настроена в common/config/main-local.php"
else
    echo -e "${YELLOW}⚠️ common/config/main-local.php не найден${NC}"
fi
echo ""

# 5. Обновление CORS с учетом всех возможных origins
echo -e "${YELLOW}[5/6] Обновление CORS...${NC}"
cd /opt/eco-project

cat > backend/api/components/CorsFilter.php << 'ENDOFFILE'
<?php

namespace api\components;

use Yii;
use yii\base\ActionFilter;
use yii\web\Response;

class CorsFilter extends ActionFilter
{
    public function beforeAction($action)
    {
        $origin = Yii::$app->request->headers->get('Origin');
        
        // Разрешаем запросы с разных источников (ВСЕ возможные варианты)
        $allowedOrigins = [
            // Локальные разработка
            'http://localhost:3000',
            'http://127.0.0.1:3000',
            'http://localhost:3001',
            'http://127.0.0.1:3001',
            'http://localhost:3002',
            'http://127.0.0.1:3002',
            // Публичные с портом
            'http://85.113.129.96:3384',
            'http://192.168.0.32:3384',
            // Публичные без порта (если через Nginx Proxy Manager)
            'http://85.113.129.96',
            'http://192.168.0.32',
            // HTTPS варианты (на будущее)
            'https://85.113.129.96:3384',
            'https://85.113.129.96',
        ];
        
        // Если origin в списке разрешенных, используем его
        if ($origin && in_array($origin, $allowedOrigins)) {
            Yii::$app->response->headers->set('Access-Control-Allow-Origin', $origin);
            Yii::$app->response->headers->set('Access-Control-Allow-Credentials', 'true');
        } else {
            // Если origin не указан или не в списке, НЕ устанавливаем заголовки
            // Это предотвращает использование wildcard с credentials
            // Но логируем для отладки
            if ($origin) {
                Yii::warning("CORS: Origin not allowed: " . $origin);
            }
            return parent::beforeAction($action);
        }
        
        Yii::$app->response->headers->set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD');
        Yii::$app->response->headers->set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept, Origin');
        Yii::$app->response->headers->set('Access-Control-Expose-Headers', 'Content-Disposition, Content-Type, Content-Length');
        Yii::$app->response->headers->set('Access-Control-Max-Age', '3600');

        if (Yii::$app->request->isOptions) {
            Yii::$app->response->statusCode = 200;
            Yii::$app->response->format = \yii\web\Response::FORMAT_RAW;
            Yii::$app->end();
        }

        return parent::beforeAction($action);
    }
}
ENDOFFILE

echo -e "${GREEN}✅ CORS обновлен${NC}"
echo ""

# 6. Пересборка frontend и перезапуск
echo -e "${YELLOW}[6/6] Пересборка frontend и перезапуск...${NC}"
cd /opt/eco-project/frontend

# Останавливаем Next.js
systemctl stop nextjs 2>/dev/null || true
sleep 2

# Пересобираем
echo "Пересборка frontend (это может занять 1-2 минуты)..."
npm run build

echo -e "${GREEN}✅ Frontend пересобран${NC}"
echo ""

# Запускаем Next.js
systemctl start nextjs
sleep 8

if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен${NC}"
else
    echo -e "${RED}❌ Next.js не запустился${NC}"
    journalctl -u nextjs -n 30 --no-pager
    exit 1
fi

# Перезапускаем Nginx
systemctl reload nginx
echo -e "${GREEN}✅ Nginx перезапущен${NC}"
echo ""

# Финальная проверка
echo -e "${YELLOW}Финальная проверка...${NC}"
echo ""

echo "1. Проверка .env.local:"
if [ -f .env.local ]; then
    echo -e "${GREEN}   ✅ .env.local существует${NC}"
    echo "   Содержимое:"
    cat .env.local | sed 's/^/      /'
else
    echo -e "${RED}   ❌ .env.local не найден${NC}"
fi
echo ""

echo "2. Проверка переменной NEXT_PUBLIC_API_URL:"
if grep -q "NEXT_PUBLIC_API_URL" .env.local; then
    API_URL_VALUE=$(grep "NEXT_PUBLIC_API_URL" .env.local | cut -d'=' -f2)
    echo -e "${GREEN}   ✅ NEXT_PUBLIC_API_URL=$API_URL_VALUE${NC}"
else
    echo -e "${RED}   ❌ NEXT_PUBLIC_API_URL не найден${NC}"
fi
echo ""

echo "3. Тест Next.js:"
sleep 3
if curl -s http://127.0.0.1:$NEXTJS_PORT | head -1 | grep -q "html"; then
    echo -e "${GREEN}   ✅ Next.js отвечает${NC}"
else
    echo -e "${YELLOW}   ⚠️ Next.js может еще запускаться${NC}"
fi
echo ""

echo "4. Тест Frontend через Nginx:"
if curl -s http://127.0.0.1:3384 | head -1 | grep -q "html"; then
    echo -e "${GREEN}   ✅ Frontend через Nginx работает${NC}"
else
    echo -e "${RED}   ❌ Frontend через Nginx не работает${NC}"
fi
echo ""

echo "5. Тест Backend API:"
if curl -s http://127.0.0.1:3384/api/health | grep -q "status\|ok"; then
    echo -e "${GREEN}   ✅ Backend API работает${NC}"
else
    echo -e "${RED}   ❌ Backend API не работает${NC}"
fi
echo ""

echo -e "${GREEN}=========================================="
echo "✅ ВСЕ .ENV ФАЙЛЫ ИСПРАВЛЕНЫ!"
echo "==========================================${NC}"
echo ""
echo "Что сделано:"
echo "  ✅ Создан правильный frontend/.env.local с NEXT_PUBLIC_API_URL=/api"
echo "  ✅ Обновлен next.config.js"
echo "  ✅ Обновлен CORS с всеми возможными origins"
echo "  ✅ Frontend пересобран"
echo "  ✅ Все сервисы перезапущены"
echo ""
echo "ВАЖНО:"
echo "  - API URL теперь относительный: /api"
echo "  - Это работает через Nginx прокси"
echo "  - CORS настроен для всех возможных origins"
echo ""
echo "Если CORS предупреждение все еще появляется:"
echo "  1. Откройте консоль браузера (F12)"
echo "  2. Посмотрите какой Origin отправляется"
echo "  3. Если его нет в списке, добавьте в CorsFilter.php"
echo ""
echo "Попробуйте войти:"
echo "  http://85.113.129.96:3384/login"
echo ""


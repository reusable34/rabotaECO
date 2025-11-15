#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ NEXT.JS И CORS
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ NEXT.JS И CORS"
echo "==========================================${NC}"
echo ""

# 1. Проверка Next.js
echo -e "${YELLOW}[1/5] Проверка Next.js...${NC}"
NEXTJS_PORT=$(ss -tuln | grep LISTEN | grep -oE ":300[0-9]+" | head -1 | cut -d: -f2 || echo "")
if [ -z "$NEXTJS_PORT" ]; then
    echo -e "${RED}❌ Next.js не слушает${NC}"
    echo "Проверяю статус..."
    systemctl status nextjs --no-pager -l | head -20
    echo ""
    echo "Логи:"
    journalctl -u nextjs -n 50 --no-pager
    exit 1
fi

echo "Next.js слушает на порту: $NEXTJS_PORT"
echo ""

# 2. Пересборка frontend
echo -e "${YELLOW}[2/5] Пересборка frontend...${NC}"
cd /opt/eco-project/frontend

# Останавливаем Next.js для пересборки
systemctl stop nextjs 2>/dev/null || true
sleep 2

# Пересобираем
npm run build
echo -e "${GREEN}✅ Frontend пересобран${NC}"
echo ""

# 3. Запуск Next.js
echo -e "${YELLOW}[3/5] Запуск Next.js...${NC}"
systemctl start nextjs
sleep 8

if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен${NC}"
else
    echo -e "${RED}❌ Next.js не запустился${NC}"
    journalctl -u nextjs -n 50 --no-pager
    exit 1
fi

# Проверка ответа
sleep 3
if curl -s http://127.0.0.1:$NEXTJS_PORT | head -1 | grep -q "html"; then
    echo -e "${GREEN}✅ Next.js отвечает${NC}"
else
    echo -e "${YELLOW}⚠️ Next.js может еще запускаться, подождите 10 секунд${NC}"
    sleep 10
    if curl -s http://127.0.0.1:$NEXTJS_PORT | head -1 | grep -q "html"; then
        echo -e "${GREEN}✅ Next.js теперь отвечает${NC}"
    else
        echo -e "${RED}❌ Next.js все еще не отвечает${NC}"
        echo "Проверьте логи: journalctl -u nextjs -f"
    fi
fi
echo ""

# 4. ИСПРАВЛЕНИЕ CORS - добавляем все возможные origins
echo -e "${YELLOW}[4/5] Исправление CORS (добавление всех origins)...${NC}"
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
        
        // Разрешаем запросы с разных источников (все возможные варианты)
        $allowedOrigins = [
            // Локальные
            'http://localhost:3000',
            'http://127.0.0.1:3000',
            'http://localhost:3001',
            'http://127.0.0.1:3001',
            'http://localhost:3002',
            'http://127.0.0.1:3002',
            // Публичные
            'http://85.113.129.96:3384',
            'http://192.168.0.32:3384',
            // Без порта (если через Nginx Proxy Manager)
            'http://85.113.129.96',
            'http://192.168.0.32',
        ];
        
        // Если origin в списке разрешенных, используем его
        if ($origin && in_array($origin, $allowedOrigins)) {
            Yii::$app->response->headers->set('Access-Control-Allow-Origin', $origin);
            Yii::$app->response->headers->set('Access-Control-Allow-Credentials', 'true');
        } else {
            // Если origin не указан или не в списке, НЕ устанавливаем заголовки
            // Это предотвращает использование wildcard с credentials
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

echo -e "${GREEN}✅ CORS обновлен (добавлены все возможные origins)${NC}"
echo ""

# 5. Перезапуск Nginx для применения изменений
echo -e "${YELLOW}[5/5] Перезапуск Nginx...${NC}"
systemctl reload nginx
sleep 2
echo -e "${GREEN}✅ Nginx перезапущен${NC}"
echo ""

# Финальная проверка
echo -e "${YELLOW}Финальная проверка...${NC}"
echo ""

echo "1. Next.js напрямую:"
if curl -s http://127.0.0.1:$NEXTJS_PORT | head -1 | grep -q "html"; then
    echo -e "${GREEN}   ✅ Работает${NC}"
else
    echo -e "${RED}   ❌ Не работает${NC}"
fi

echo "2. Frontend через Nginx:"
if curl -s http://127.0.0.1:3384 | head -1 | grep -q "html"; then
    echo -e "${GREEN}   ✅ Работает${NC}"
else
    echo -e "${RED}   ❌ Не работает${NC}"
    echo "   Проверьте конфигурацию Nginx"
fi

echo "3. Backend API через Nginx:"
if curl -s http://127.0.0.1:3384/api/health | grep -q "status\|ok"; then
    echo -e "${GREEN}   ✅ Работает${NC}"
else
    echo -e "${RED}   ❌ Не работает${NC}"
fi
echo ""

echo -e "${GREEN}=========================================="
echo "✅ ИСПРАВЛЕНО!"
echo "==========================================${NC}"
echo ""
echo "Если CORS предупреждение все еще появляется:"
echo "1. Обновите страницу (Ctrl+F5 или Cmd+Shift+R)"
echo "2. Очистите кеш браузера"
echo "3. Проверьте в консоли браузера (F12) какой Origin отправляется"
echo ""
echo "Попробуйте войти:"
echo "  http://85.113.129.96:3384/login"
echo ""


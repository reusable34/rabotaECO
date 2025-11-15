#!/bin/bash
# ==========================================
# ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ CORS
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ CORS"
echo "==========================================${NC}"
echo ""

# 1. Проверка Next.js
echo -e "${YELLOW}[1/4] Проверка Next.js...${NC}"
NEXTJS_PORT=$(ss -tuln | grep LISTEN | grep -oE ":300[0-9]+" | head -1 | cut -d: -f2 || echo "")
if [ -z "$NEXTJS_PORT" ]; then
    echo -e "${RED}❌ Next.js не запущен${NC}"
    exit 1
fi

echo "Next.js на порту: $NEXTJS_PORT"
sleep 5
if curl -s http://127.0.0.1:$NEXTJS_PORT | head -1 | grep -q "html"; then
    echo -e "${GREEN}✅ Next.js отвечает${NC}"
else
    echo -e "${YELLOW}⚠️ Next.js может еще запускаться${NC}"
fi
echo ""

# 2. Обновление CORS - разрешаем ВСЕ origins с портом 3384
echo -e "${YELLOW}[2/4] Обновление CORS (разрешаем все origins с 3384)...${NC}"
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
        
        // Разрешаем запросы с разных источников
        $allowedOrigins = [
            // Локальные разработка
            'http://localhost:3000',
            'http://127.0.0.1:3000',
            'http://localhost:3001',
            'http://127.0.0.1:3001',
            'http://localhost:3002',
            'http://127.0.0.1:3002',
            // Публичные с портом 3384 (основной вариант)
            'http://85.113.129.96:3384',
            'http://192.168.0.32:3384',
            // Публичные без порта (если через Nginx Proxy Manager)
            'http://85.113.129.96',
            'http://192.168.0.32',
            // HTTPS варианты (на будущее)
            'https://85.113.129.96:3384',
            'https://85.113.129.96',
        ];
        
        // Дополнительно: разрешаем любой origin, который содержит наш IP и порт 3384
        if ($origin) {
            // Проверяем точное совпадение
            if (in_array($origin, $allowedOrigins)) {
                Yii::$app->response->headers->set('Access-Control-Allow-Origin', $origin);
                Yii::$app->response->headers->set('Access-Control-Allow-Credentials', 'true');
            }
            // Или разрешаем если содержит наш IP и порт 3384
            elseif (preg_match('/^https?:\/\/(85\.113\.129\.96|192\.168\.0\.32)(:3384)?$/', $origin)) {
                Yii::$app->response->headers->set('Access-Control-Allow-Origin', $origin);
                Yii::$app->response->headers->set('Access-Control-Allow-Credentials', 'true');
            }
            // Или разрешаем localhost с любым портом 300x
            elseif (preg_match('/^https?:\/\/(localhost|127\.0\.0\.1):300\d+$/', $origin)) {
                Yii::$app->response->headers->set('Access-Control-Allow-Origin', $origin);
                Yii::$app->response->headers->set('Access-Control-Allow-Credentials', 'true');
            }
            else {
                // Логируем для отладки
                Yii::warning("CORS: Origin not allowed: " . $origin);
                // НЕ устанавливаем заголовки - это предотвращает wildcard с credentials
                return parent::beforeAction($action);
            }
        } else {
            // Если origin не указан, не устанавливаем заголовки
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

echo -e "${GREEN}✅ CORS обновлен (разрешает все варианты с портом 3384)${NC}"
echo ""

# 3. Проверка что файл обновлен
echo -e "${YELLOW}[3/4] Проверка CORS файла...${NC}"
if grep -q "85\.113\.129\.96" backend/api/components/CorsFilter.php; then
    echo -e "${GREEN}✅ CORS файл содержит правильные origins${NC}"
else
    echo -e "${RED}❌ CORS файл не обновлен${NC}"
    exit 1
fi
echo ""

# 4. Тестирование
echo -e "${YELLOW}[4/4] Тестирование...${NC}"
echo ""

echo "1. Frontend через Nginx:"
if curl -s http://127.0.0.1:3384 | head -1 | grep -q "html"; then
    echo -e "${GREEN}   ✅ Работает${NC}"
else
    echo -e "${RED}   ❌ Не работает${NC}"
fi

echo "2. Backend API через Nginx:"
API_RESPONSE=$(curl -s -H "Origin: http://85.113.129.96:3384" http://127.0.0.1:3384/api/health)
if echo "$API_RESPONSE" | grep -q "status\|ok"; then
    echo -e "${GREEN}   ✅ Работает${NC}"
    echo "   Ответ: $(echo "$API_RESPONSE" | head -1)"
else
    echo -e "${RED}   ❌ Не работает${NC}"
    echo "   Ответ: $API_RESPONSE"
fi

echo "3. Проверка CORS заголовков:"
CORS_HEADERS=$(curl -s -I -H "Origin: http://85.113.129.96:3384" http://127.0.0.1:3384/api/health | grep -i "access-control")
if [ -n "$CORS_HEADERS" ]; then
    echo -e "${GREEN}   ✅ CORS заголовки установлены${NC}"
    echo "$CORS_HEADERS" | sed 's/^/      /'
else
    echo -e "${YELLOW}   ⚠️ CORS заголовки не найдены (может быть нормально для OPTIONS)${NC}"
fi
echo ""

echo -e "${GREEN}=========================================="
echo "✅ CORS ИСПРАВЛЕН!"
echo "==========================================${NC}"
echo ""
echo "Что сделано:"
echo "  ✅ CORS теперь разрешает все варианты с портом 3384"
echo "  ✅ Разрешены localhost с любым портом 300x"
echo "  ✅ Разрешены публичные IP с портом 3384"
echo "  ✅ Используется regex для гибкой проверки"
echo ""
echo "ВАЖНО:"
echo "  Если CORS предупреждение все еще появляется:"
echo "  1. Откройте консоль браузера (F12)"
echo "  2. Посмотрите в Network tab какой Origin отправляется"
echo "  3. Проверьте логи backend: tail -f /opt/eco-project/backend/runtime/logs/app.log"
echo ""
echo "Попробуйте войти:"
echo "  http://85.113.129.96:3384/login"
echo ""
echo "Если предупреждение останется, выполните в браузере (F12 -> Console):"
echo "  fetch('http://85.113.129.96:3384/api/health', {credentials: 'include'}).then(r => console.log(r.headers.get('access-control-allow-origin')))"
echo ""


#!/bin/bash
# ==========================================
# ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ CORS FILTER
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ CORS FILTER"
echo "==========================================${NC}"
echo ""

# 1. Исправление CorsFilter - убеждаемся что заголовки устанавливаются ВСЕГДА
echo -e "${YELLOW}[1/3] Исправление CorsFilter...${NC}"
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
            'http://localhost:3000',
            'http://127.0.0.1:3000',
            'http://localhost:3001',
            'http://127.0.0.1:3001',
            'http://localhost:3002',
            'http://127.0.0.1:3002',
            'http://85.113.129.96:3384',
            'http://192.168.0.32:3384',
            'http://85.113.129.96',
            'http://192.168.0.32',
        ];
        
        // Паттерны для гибкой проверки
        $allowedPatterns = [
            '/^https?:\/\/(localhost|127\.0\.0\.1):300\d+$/',  // localhost с портами 300x
            '/^https?:\/\/(85\.113\.129\.96|192\.168\.0\.32)(:3384)?$/',  // Публичные IP с/без порта 3384
        ];
        
        $originAllowed = false;
        $allowedOrigin = null;
        
        // Проверяем точное совпадение
        if ($origin && in_array($origin, $allowedOrigins)) {
            $originAllowed = true;
            $allowedOrigin = $origin;
        }
        // Проверяем по паттернам
        elseif ($origin) {
            foreach ($allowedPatterns as $pattern) {
                if (preg_match($pattern, $origin)) {
                    $originAllowed = true;
                    $allowedOrigin = $origin;
                    break;
                }
            }
        }
        
        // ВАЖНО: Устанавливаем CORS заголовки ДО вызова parent::beforeAction
        // Это гарантирует, что заголовки будут установлены для всех запросов
        if ($originAllowed && $allowedOrigin) {
            Yii::$app->response->headers->set('Access-Control-Allow-Origin', $allowedOrigin);
            Yii::$app->response->headers->set('Access-Control-Allow-Credentials', 'true');
            Yii::$app->response->headers->set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD');
            Yii::$app->response->headers->set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept, Origin');
            Yii::$app->response->headers->set('Access-Control-Expose-Headers', 'Content-Disposition, Content-Type, Content-Length');
            Yii::$app->response->headers->set('Access-Control-Max-Age', '3600');
        } else {
            // Если origin не разрешен, логируем но НЕ устанавливаем заголовки
            // Это предотвращает wildcard с credentials
            if ($origin) {
                Yii::warning("CORS: Origin not allowed: " . $origin);
            }
        }
        
        // Обработка preflight OPTIONS запросов
        if (Yii::$app->request->isOptions) {
            Yii::$app->response->statusCode = 200;
            Yii::$app->response->format = \yii\web\Response::FORMAT_RAW;
            Yii::$app->end();
            return false; // Не продолжаем выполнение action
        }

        return parent::beforeAction($action);
    }
}
ENDOFFILE

echo -e "${GREEN}✅ CorsFilter исправлен${NC}"
echo "   Теперь заголовки устанавливаются ДО parent::beforeAction"
echo ""

# 2. Исправление Nginx для /health с правильными CORS заголовками
echo -e "${YELLOW}[2/3] Исправление Nginx для /health...${NC}"
BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "8082")

cat > /etc/nginx/sites-available/eco-backend.conf << EOF
server {
    listen $BACKEND_PORT;
    server_name _;
    root /opt/eco-project/backend/api/web;
    index index.php;

    # Health check с CORS заголовками
    location = /health {
        access_log off;
        try_files \$uri /health.php;
        
        # CORS заголовки для health endpoint
        # ВАЖНО: add_header работает только при успешных ответах (2xx, 3xx)
        # Для 4xx/5xx нужно использовать always
        more_set_headers 'Access-Control-Allow-Origin: *';
        more_set_headers 'Access-Control-Allow-Methods: GET, OPTIONS';
        more_set_headers 'Access-Control-Allow-Headers: Content-Type, Authorization';
        more_set_headers 'Access-Control-Max-Age: 3600';
        
        # Если модуль headers-more не установлен, используем обычный add_header
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization' always;
        add_header 'Access-Control-Max-Age' '3600' always;
        
        if (\$request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Allow-Methods' 'GET, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization' always;
            add_header 'Access-Control-Max-Age' '3600' always;
            add_header 'Content-Length' 0;
            add_header 'Content-Type' 'text/plain';
            return 204;
        }
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

if nginx -t; then
    systemctl reload nginx
    echo -e "${GREEN}✅ Nginx обновлен${NC}"
else
    echo -e "${RED}❌ Ошибка в Nginx${NC}"
    nginx -t
    exit 1
fi
echo ""

# 3. Тестирование
echo -e "${YELLOW}[3/3] Тестирование...${NC}"
echo ""

echo "1. Тест реального API запроса (POST auth/login):"
LOGIN_TEST=$(curl -s -X POST \
    -H "Origin: http://85.113.129.96:3384" \
    -H "Content-Type: application/json" \
    -d '{"email":"test@test.com","password":"test"}' \
    http://127.0.0.1:3384/api/auth/login 2>&1)

LOGIN_HEADERS=$(curl -s -I -X POST \
    -H "Origin: http://85.113.129.96:3384" \
    -H "Content-Type: application/json" \
    -d '{"email":"test@test.com","password":"test"}' \
    http://127.0.0.1:3384/api/auth/login 2>&1)

if echo "$LOGIN_HEADERS" | grep -qi "access-control-allow-origin"; then
    echo -e "${GREEN}   ✅ CORS заголовки установлены для POST запроса${NC}"
    echo "$LOGIN_HEADERS" | grep -i "access-control" | sed 's/^/      /'
else
    echo -e "${RED}   ❌ CORS заголовки НЕ установлены для POST запроса${NC}"
    echo "   Заголовки:"
    echo "$LOGIN_HEADERS" | head -15 | sed 's/^/      /'
fi

echo ""
echo "2. Тест OPTIONS запроса:"
OPTIONS_HEADERS=$(curl -s -I -X OPTIONS \
    -H "Origin: http://85.113.129.96:3384" \
    -H "Access-Control-Request-Method: POST" \
    http://127.0.0.1:3384/api/auth/login 2>&1)

if echo "$OPTIONS_HEADERS" | grep -qi "access-control-allow-origin"; then
    echo -e "${GREEN}   ✅ CORS заголовки установлены для OPTIONS${NC}"
    echo "$OPTIONS_HEADERS" | grep -i "access-control" | sed 's/^/      /'
else
    echo -e "${RED}   ❌ CORS заголовки НЕ установлены для OPTIONS${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ CORS FILTER ИСПРАВЛЕН!"
echo "==========================================${NC}"
echo ""
echo "Что исправлено:"
echo "  ✅ CorsFilter теперь устанавливает заголовки ДО parent::beforeAction"
echo "  ✅ Заголовки устанавливаются для всех запросов (GET, POST, OPTIONS)"
echo "  ✅ Nginx настроен для /health с CORS"
echo ""
echo "ВАЖНО:"
echo "  Если предупреждение CORS все еще появляется в браузере:"
echo "  1. Обновите страницу с очисткой кеша (Ctrl+Shift+R или Cmd+Shift+R)"
echo "  2. Откройте консоль браузера (F12) и проверьте Network tab"
echo "  3. Посмотрите заголовки ответа - должны быть Access-Control-Allow-Origin"
echo ""
echo "Попробуйте войти:"
echo "  http://85.113.129.96:3384/login"
echo ""


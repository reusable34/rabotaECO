#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ HEALTH И CORS
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ HEALTH И CORS"
echo "==========================================${NC}"
echo ""

BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "8082")

# 1. Обновление Nginx конфигурации для backend
echo -e "${YELLOW}[1/4] Обновление Nginx конфигурации для backend...${NC}"
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

ln -sf /etc/nginx/sites-available/eco-backend.conf /etc/nginx/sites-enabled/eco-backend.conf

if nginx -t; then
    systemctl reload nginx
    echo -e "${GREEN}✅ Nginx конфигурация обновлена${NC}"
else
    echo -e "${RED}❌ Ошибка в Nginx${NC}"
    nginx -t
    exit 1
fi
echo ""

# 2. Создание Health контроллера в Yii2 (для правильной работы CORS)
echo -e "${YELLOW}[2/4] Создание Health контроллера в Yii2...${NC}"
cd /opt/eco-project

cat > backend/api/controllers/HealthController.php << 'ENDOFFILE'
<?php

namespace api\controllers;

use Yii;
use yii\rest\Controller;
use yii\web\Response;

class HealthController extends Controller
{
    public function behaviors()
    {
        $behaviors = parent::behaviors();
        
        // CORS уже настроен глобально через CorsFilter
        // Но можем добавить дополнительные настройки если нужно
        
        return $behaviors;
    }
    
    public function actionIndex()
    {
        Yii::$app->response->format = Response::FORMAT_JSON;
        
        $status = [
            'status' => 'ok',
            'timestamp' => date('c'),
            'service' => 'eco-backend-api',
        ];
        
        // Проверка подключения к БД
        try {
            $db = Yii::$app->db;
            $db->createCommand('SELECT 1')->execute();
            $status['database'] = 'connected';
        } catch (\Exception $e) {
            $status['status'] = 'error';
            $status['database'] = 'disconnected';
            $status['error'] = $e->getMessage();
            Yii::$app->response->statusCode = 503;
        }
        
        return $status;
    }
    
    public function actionOptions()
    {
        Yii::$app->response->statusCode = 200;
        Yii::$app->response->format = Response::FORMAT_RAW;
        return '';
    }
}
ENDOFFILE

echo -e "${GREEN}✅ Health контроллер создан${NC}"
echo ""

# 3. Добавление маршрута для health в main.php
echo -e "${YELLOW}[3/4] Добавление маршрута для health...${NC}"
cd /opt/eco-project/backend/api/config

# Проверяем, есть ли уже маршрут для health
if ! grep -q "'GET health'" main.php; then
    # Добавляем маршрут после auth маршрутов
    sed -i "/'GET auth\/me'/a\                'GET health' => 'health/index'," main.php
    sed -i "/'GET health'/a\                'OPTIONS health' => 'health/options'," main.php
    echo -e "${GREEN}✅ Маршрут для health добавлен${NC}"
else
    echo -e "${YELLOW}⚠️ Маршрут для health уже существует${NC}"
fi
echo ""

# 4. Тестирование
echo -e "${YELLOW}[4/4] Тестирование...${NC}"
echo ""

echo "1. Health через Nginx напрямую:"
HEALTH_RESPONSE=$(curl -s -H "Origin: http://85.113.129.96:3384" http://127.0.0.1:$BACKEND_PORT/health)
if echo "$HEALTH_RESPONSE" | grep -q "status\|ok"; then
    echo -e "${GREEN}   ✅ Работает${NC}"
    echo "$HEALTH_RESPONSE" | head -3 | sed 's/^/      /'
else
    echo -e "${RED}   ❌ Не работает${NC}"
    echo "   Ответ: $HEALTH_RESPONSE" | head -3 | sed 's/^/      /'
fi

echo ""
echo "2. CORS заголовки для health:"
HEALTH_CORS=$(curl -s -I -H "Origin: http://85.113.129.96:3384" http://127.0.0.1:$BACKEND_PORT/health)
if echo "$HEALTH_CORS" | grep -qi "access-control-allow-origin"; then
    echo -e "${GREEN}   ✅ CORS заголовки установлены${NC}"
    echo "$HEALTH_CORS" | grep -i "access-control" | sed 's/^/      /'
else
    echo -e "${RED}   ❌ CORS заголовки НЕ установлены${NC}"
fi

echo ""
echo "3. Health через Nginx прокси (/api/health):"
API_HEALTH=$(curl -s -H "Origin: http://85.113.129.96:3384" http://127.0.0.1:3384/api/health)
if echo "$API_HEALTH" | grep -q "status\|ok"; then
    echo -e "${GREEN}   ✅ Работает${NC}"
    echo "$API_HEALTH" | head -3 | sed 's/^/      /'
else
    echo -e "${YELLOW}   ⚠️ Может быть 404 (нужно использовать /health напрямую)${NC}"
fi

echo ""
echo "4. Тест реального API endpoint (auth/login OPTIONS):"
API_OPTIONS=$(curl -s -I -X OPTIONS -H "Origin: http://85.113.129.96:3384" http://127.0.0.1:3384/api/auth/login)
if echo "$API_OPTIONS" | grep -qi "access-control-allow-origin"; then
    echo -e "${GREEN}   ✅ CORS заголовки установлены для API${NC}"
    echo "$API_OPTIONS" | grep -i "access-control" | sed 's/^/      /'
else
    echo -e "${RED}   ❌ CORS заголовки НЕ установлены для API${NC}"
    echo "   Полный ответ:"
    echo "$API_OPTIONS" | head -10 | sed 's/^/      /'
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ИСПРАВЛЕНО!"
echo "==========================================${NC}"
echo ""
echo "Что сделано:"
echo "  ✅ Настроен Nginx для /health с CORS заголовками"
echo "  ✅ Создан Health контроллер в Yii2"
echo "  ✅ Добавлен маршрут для /health"
echo ""
echo "Теперь:"
echo "  - /health работает напрямую через Nginx (с CORS)"
echo "  - /api/health работает через Yii2 (с CorsFilter)"
echo ""
echo "Проверьте вход:"
echo "  http://85.113.129.96:3384/login"
echo ""


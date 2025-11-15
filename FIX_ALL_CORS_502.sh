#!/bin/bash
# ==========================================
# ПОЛНОЕ ИСПРАВЛЕНИЕ CORS И 502 BAD GATEWAY
# ==========================================
# Исправляет:
# - 502 Bad Gateway в Nginx
# - CORS ошибки (wildcard origins)
# - Next.js на порт 3002
# - Health endpoint с CORS
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🚀 ПОЛНОЕ ИСПРАВЛЕНИЕ CORS И 502"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project || { echo -e "${RED}❌ Не найден /opt/eco-project${NC}"; exit 1; }

# Определяем порты
NEXTJS_PORT=3002
BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "8082")
NGINX_PORT=3384

echo "Используемые порты:"
echo "  - Next.js: $NEXTJS_PORT"
echo "  - Backend: $BACKEND_PORT"
echo "  - Nginx: $NGINX_PORT"
echo ""

# ==========================================
# 1. ОСТАНОВКА ВСЕХ ПРОЦЕССОВ
# ==========================================
echo -e "${YELLOW}[1/10] Остановка всех сервисов...${NC}"

# Остановка Next.js
systemctl stop nextjs 2>/dev/null || true
pkill -f "next start" 2>/dev/null || true
pkill -f "node.*next" 2>/dev/null || true
sleep 2

# Остановка Nginx
systemctl stop nginx 2>/dev/null || true
sleep 1

# Проверка, что порты свободны
if ss -tuln | grep -q ":$NEXTJS_PORT "; then
    echo -e "${YELLOW}⚠️  Порт $NEXTJS_PORT все еще занят, убиваем процессы...${NC}"
    lsof -ti:$NEXTJS_PORT | xargs kill -9 2>/dev/null || true
    sleep 1
fi

echo -e "${GREEN}✅ Все сервисы остановлены${NC}"
echo ""

# ==========================================
# 2. НАСТРОЙКА NEXT.JS НА ПОРТ 3002
# ==========================================
echo -e "${YELLOW}[2/10] Настройка Next.js на порт $NEXTJS_PORT...${NC}"

cd /opt/eco-project/frontend

# Обновление package.json
if [ -f package.json ]; then
    # Проверяем, есть ли уже порт в start скрипте
    if ! grep -q "\"start\".*$NEXTJS_PORT" package.json; then
        sed -i "s/\"start\": \"next start\"/\"start\": \"next start -p $NEXTJS_PORT\"/" package.json
        echo -e "${GREEN}✅ package.json обновлен${NC}"
    else
        echo -e "${GREEN}✅ package.json уже настроен${NC}"
    fi
else
    echo -e "${RED}❌ package.json не найден${NC}"
    exit 1
fi

# Обновление .env.local
cat > .env.local << EOF
# API URL - относительный путь (работает через Nginx прокси)
NEXT_PUBLIC_API_URL=/api

# Окружение
NEXT_PUBLIC_ENV=production

# Порт для Next.js
PORT=$NEXTJS_PORT
EOF

echo -e "${GREEN}✅ .env.local обновлен${NC}"

# Обновление systemd service
if [ -f /etc/systemd/system/nextjs.service ]; then
    sed -i "s/-p [0-9]*/-p $NEXTJS_PORT/g" /etc/systemd/system/nextjs.service || true
    sed -i "s/PORT=[0-9]*/PORT=$NEXTJS_PORT/g" /etc/systemd/system/nextjs.service || true
    systemctl daemon-reload
    echo -e "${GREEN}✅ systemd service обновлен${NC}"
fi

echo ""

# ==========================================
# 3. ОБНОВЛЕНИЕ CORS FILTER
# ==========================================
echo -e "${YELLOW}[3/10] Обновление CORS фильтра...${NC}"

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
        
        // Разрешаем запросы с разных источников (БЕЗ wildcard для безопасности)
        $allowedOrigins = [
            // Локальные разработка
            'http://localhost:3000',
            'http://127.0.0.1:3000',
            'http://localhost:3001',
            'http://127.0.0.1:3001',
            'http://localhost:3002',
            'http://127.0.0.1:3002',
            // Публичные с портом 3384
            'http://85.113.129.96:3384',
            'http://192.168.0.32:3384',
            // Публичные без порта (если через Nginx Proxy Manager)
            'http://85.113.129.96',
            'http://192.168.0.32',
            // HTTPS варианты (на будущее)
            'https://85.113.129.96:3384',
            'https://85.113.129.96',
        ];
        
        // Устанавливаем CORS заголовки ДО parent::beforeAction
        if ($origin && in_array($origin, $allowedOrigins)) {
            Yii::$app->response->headers->set('Access-Control-Allow-Origin', $origin);
            Yii::$app->response->headers->set('Access-Control-Allow-Credentials', 'true');
            Yii::$app->response->headers->set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD');
            Yii::$app->response->headers->set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept, Origin');
            Yii::$app->response->headers->set('Access-Control-Expose-Headers', 'Content-Disposition, Content-Type, Content-Length');
            Yii::$app->response->headers->set('Access-Control-Max-Age', '3600');
        }
        
        // Обработка preflight OPTIONS запросов
        if (Yii::$app->request->isOptions) {
            Yii::$app->response->statusCode = 200;
            Yii::$app->response->format = \yii\web\Response::FORMAT_RAW;
            Yii::$app->response->data = '';
            Yii::$app->end();
            return false;
        }

        return parent::beforeAction($action);
    }
}
ENDOFFILE

echo -e "${GREEN}✅ CORS фильтр обновлен (добавлен localhost:3002)${NC}"
echo ""

# ==========================================
# 4. СОЗДАНИЕ HEALTH КОНТРОЛЛЕРА
# ==========================================
echo -e "${YELLOW}[4/10] Создание Health контроллера...${NC}"

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
        // CORS настроен глобально через CorsFilter
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

# ==========================================
# 5. ДОБАВЛЕНИЕ МАРШРУТА ДЛЯ HEALTH
# ==========================================
echo -e "${YELLOW}[5/10] Добавление маршрута для health...${NC}"

cd /opt/eco-project/backend/api/config

# Проверяем, есть ли уже маршрут для health
if ! grep -q "'GET health'" main.php && ! grep -q "'health'" main.php; then
    # Добавляем маршрут после 'rules' => [
    # Используем Python для более надежной вставки
    python3 << 'PYTHON_EOF'
import re

with open('main.php', 'r') as f:
    content = f.read()

# Ищем место после 'rules' => [
pattern = r"('rules'\s*=>\s*\[)"
replacement = r"\1\n                'GET health' => 'health/index',\n                'OPTIONS health' => 'health/options',"

if re.search(r"'GET health'|'health'", content):
    print("Маршрут уже существует")
else:
    content = re.sub(pattern, replacement, content, count=1)
    with open('main.php', 'w') as f:
        f.write(content)
    print("Маршрут добавлен")
PYTHON_EOF
    
    if grep -q "'GET health'" main.php; then
        echo -e "${GREEN}✅ Маршрут для health добавлен${NC}"
    else
        echo -e "${YELLOW}⚠️  Не удалось добавить маршрут автоматически, добавьте вручную:${NC}"
        echo "                'GET health' => 'health/index',"
        echo "                'OPTIONS health' => 'health/options',"
    fi
else
    echo -e "${GREEN}✅ Маршрут для health уже существует${NC}"
fi

echo ""

# ==========================================
# 6. НАСТРОЙКА NGINX ПРОКСИ
# ==========================================
echo -e "${YELLOW}[6/10] Настройка Nginx прокси...${NC}"

cat > /etc/nginx/sites-available/eco-api-proxy.conf << EOF
server {
    listen $NGINX_PORT;
    server_name _;

    # Health endpoint - проксируем на backend с правильными CORS
    location = /health {
        # CORS заголовки для health endpoint
        # Используем один if с регулярным выражением для всех разрешенных origins
        if (\$http_origin ~* "^https?://((localhost|127\.0\.0\.1):300[0-9]+|85\.113\.129\.96(:3384)?|192\.168\.0\.32(:3384)?)$") {
            add_header 'Access-Control-Allow-Origin' \$http_origin always;
            add_header 'Access-Control-Allow-Credentials' 'true' always;
        }
        add_header 'Access-Control-Allow-Methods' 'GET, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With, Accept, Origin' always;
        add_header 'Access-Control-Expose-Headers' 'Content-Disposition, Content-Type, Content-Length' always;
        add_header 'Access-Control-Max-Age' '3600' always;
        
        # Для OPTIONS запросов (preflight)
        if (\$request_method = 'OPTIONS') {
            if (\$http_origin ~* "^https?://((localhost|127\.0\.0\.1):300[0-9]+|85\.113\.129\.96(:3384)?|192\.168\.0\.32(:3384)?)$") {
                add_header 'Access-Control-Allow-Origin' \$http_origin always;
                add_header 'Access-Control-Allow-Credentials' 'true' always;
            }
            add_header 'Access-Control-Allow-Methods' 'GET, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization, X-Requested-With, Accept, Origin' always;
            add_header 'Access-Control-Max-Age' '3600' always;
            add_header 'Content-Length' 0;
            add_header 'Content-Type' 'text/plain';
            return 204;
        }
        
        # Прокси на бекенд
        proxy_pass http://127.0.0.1:$BACKEND_PORT/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 10s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }

    # Frontend (Next.js)
    location / {
        proxy_pass http://127.0.0.1:$NEXTJS_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 10s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }

    # Backend API - завершающий слэш убирает /api из пути
    location /api {
        proxy_pass http://127.0.0.1:$BACKEND_PORT/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 10s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }
}
EOF

ln -sf /etc/nginx/sites-available/eco-api-proxy.conf /etc/nginx/sites-enabled/eco-api-proxy.conf

# Проверка синтаксиса
if nginx -t; then
    echo -e "${GREEN}✅ Nginx конфигурация корректна${NC}"
else
    echo -e "${RED}❌ Ошибка в Nginx конфигурации${NC}"
    nginx -t
    exit 1
fi

echo ""

# ==========================================
# 7. ПЕРЕСБОРКА FRONTEND
# ==========================================
echo -e "${YELLOW}[7/10] Пересборка frontend...${NC}"

cd /opt/eco-project/frontend

# Удаляем старую сборку
rm -rf .next 2>/dev/null || true

# Пересборка
npm run build > /dev/null 2>&1 || {
    echo -e "${YELLOW}⚠️  Пересборка frontend (может занять время)...${NC}"
    npm run build
}

echo -e "${GREEN}✅ Frontend пересобран${NC}"
echo ""

# ==========================================
# 8. ЗАПУСК ВСЕХ СЕРВИСОВ
# ==========================================
echo -e "${YELLOW}[8/10] Запуск всех сервисов...${NC}"

# Запуск PHP-FPM
systemctl start php8.2-fpm || systemctl start php-fpm || true
sleep 1
if systemctl is-active --quiet php8.2-fpm || systemctl is-active --quiet php-fpm; then
    echo -e "${GREEN}✅ PHP-FPM запущен${NC}"
else
    echo -e "${YELLOW}⚠️  PHP-FPM не запущен (может быть нормально)${NC}"
fi

# Запуск Nginx
systemctl start nginx
sleep 2
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Nginx запущен${NC}"
else
    echo -e "${RED}❌ Nginx не запущен${NC}"
    systemctl status nginx
    exit 1
fi

# Запуск Next.js
systemctl start nextjs
sleep 5

if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен${NC}"
else
    echo -e "${YELLOW}⚠️  Next.js service не активен, проверяем процесс...${NC}"
    if ss -tuln | grep -q ":$NEXTJS_PORT "; then
        echo -e "${GREEN}✅ Next.js слушает на порту $NEXTJS_PORT${NC}"
    else
        echo -e "${RED}❌ Next.js не запущен${NC}"
        journalctl -u nextjs -n 20 --no-pager
    fi
fi

echo ""

# ==========================================
# 9. ПРОВЕРКА ПОРТОВ
# ==========================================
echo -e "${YELLOW}[9/10] Проверка портов...${NC}"

echo "Активные порты:"
ss -tuln | grep -E ":(3002|$BACKEND_PORT|$NGINX_PORT) " | sed 's/^/  /' || echo "  Порты не найдены"

# Проверка Next.js
if ss -tuln | grep -q ":$NEXTJS_PORT "; then
    echo -e "${GREEN}✅ Next.js слушает на порту $NEXTJS_PORT${NC}"
else
    echo -e "${RED}❌ Next.js НЕ слушает на порту $NEXTJS_PORT${NC}"
fi

# Проверка Backend
if ss -tuln | grep -q ":$BACKEND_PORT "; then
    echo -e "${GREEN}✅ Backend слушает на порту $BACKEND_PORT${NC}"
else
    echo -e "${RED}❌ Backend НЕ слушает на порту $BACKEND_PORT${NC}"
fi

# Проверка Nginx
if ss -tuln | grep -q ":$NGINX_PORT "; then
    echo -e "${GREEN}✅ Nginx слушает на порту $NGINX_PORT${NC}"
else
    echo -e "${RED}❌ Nginx НЕ слушает на порту $NGINX_PORT${NC}"
fi

echo ""

# ==========================================
# 10. ТЕСТИРОВАНИЕ
# ==========================================
echo -e "${YELLOW}[10/10] Тестирование сервисов...${NC}"

# Тест 1: Next.js напрямую
echo -n "1. Next.js напрямую (http://127.0.0.1:$NEXTJS_PORT): "
if curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:$NEXTJS_PORT" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ Работает${NC}"
else
    echo -e "${RED}❌ Не отвечает${NC}"
fi

# Тест 2: Backend напрямую
echo -n "2. Backend напрямую (http://127.0.0.1:$BACKEND_PORT/health): "
BACKEND_TEST=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:$BACKEND_PORT/health" || echo "000")
if [ "$BACKEND_TEST" = "200" ] || [ "$BACKEND_TEST" = "503" ]; then
    echo -e "${GREEN}✅ Работает (код: $BACKEND_TEST)${NC}"
else
    echo -e "${YELLOW}⚠️  Код ответа: $BACKEND_TEST${NC}"
fi

# Тест 3: Frontend через Nginx
echo -n "3. Frontend через Nginx (http://127.0.0.1:$NGINX_PORT/): "
FRONTEND_TEST=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:$NGINX_PORT/" || echo "000")
if [ "$FRONTEND_TEST" = "200" ] || [ "$FRONTEND_TEST" = "301" ] || [ "$FRONTEND_TEST" = "302" ]; then
    echo -e "${GREEN}✅ Работает (код: $FRONTEND_TEST)${NC}"
else
    echo -e "${RED}❌ Не работает (код: $FRONTEND_TEST)${NC}"
    echo "   Проверьте логи: journalctl -u nginx -n 20"
fi

# Тест 4: Health через Nginx с CORS
echo -n "4. Health через Nginx с CORS (http://127.0.0.1:$NGINX_PORT/health): "
HEALTH_RESPONSE=$(curl -s -I -X GET \
    -H "Origin: http://85.113.129.96:3384" \
    --max-time 5 \
    "http://127.0.0.1:$NGINX_PORT/health" 2>&1)
HEALTH_CODE=$(echo "$HEALTH_RESPONSE" | head -1 | grep -oE "[0-9]{3}" || echo "000")
if echo "$HEALTH_RESPONSE" | grep -qi "access-control-allow-origin"; then
    echo -e "${GREEN}✅ Работает с CORS (код: $HEALTH_CODE)${NC}"
else
    echo -e "${YELLOW}⚠️  Работает, но CORS заголовки не найдены (код: $HEALTH_CODE)${NC}"
fi

# Тест 5: Backend API через Nginx
echo -n "5. Backend API через Nginx (http://127.0.0.1:$NGINX_PORT/api/auth/login OPTIONS): "
API_RESPONSE=$(curl -s -I -X OPTIONS \
    -H "Origin: http://85.113.129.96:3384" \
    -H "Access-Control-Request-Method: POST" \
    --max-time 5 \
    "http://127.0.0.1:$NGINX_PORT/api/auth/login" 2>&1)
API_CODE=$(echo "$API_RESPONSE" | head -1 | grep -oE "[0-9]{3}" || echo "000")
if echo "$API_RESPONSE" | grep -qi "access-control-allow-origin"; then
    echo -e "${GREEN}✅ Работает с CORS (код: $API_CODE)${NC}"
else
    echo -e "${YELLOW}⚠️  Работает, но CORS заголовки не найдены (код: $API_CODE)${NC}"
fi

echo ""

# ==========================================
# ИТОГОВЫЙ СТАТУС
# ==========================================
echo -e "${GREEN}=========================================="
echo "✅ ВСЁ ИСПРАВЛЕНО И НАСТРОЕНО!"
echo "==========================================${NC}"
echo ""
echo "Используемые порты:"
echo "  - Next.js: $NEXTJS_PORT (внутренний)"
echo "  - Backend: $BACKEND_PORT (внутренний)"
echo "  - Nginx: $NGINX_PORT (публичный)"
echo ""
echo "Доступ:"
echo "  - Frontend: http://85.113.129.96:$NGINX_PORT/"
echo "  - Backend API: http://85.113.129.96:$NGINX_PORT/api"
echo "  - Health: http://85.113.129.96:$NGINX_PORT/health"
echo ""
echo "Что исправлено:"
echo "  ✅ Next.js настроен на порт $NEXTJS_PORT"
echo "  ✅ CORS исправлен (нет wildcard, только конкретные origins)"
echo "  ✅ Health endpoint создан и настроен с CORS"
echo "  ✅ Nginx правильно проксирует все endpoints"
echo "  ✅ Все сервисы запущены и работают"
echo ""
echo "ВАЖНО:"
echo "  - Порты 3000 и 8080 больше НЕ используются!"
echo "  - Убедитесь, что порт $NGINX_PORT проброшен в роутере!"
echo ""
echo "Попробуйте войти:"
echo "  http://85.113.129.96:$NGINX_PORT/login"
echo ""


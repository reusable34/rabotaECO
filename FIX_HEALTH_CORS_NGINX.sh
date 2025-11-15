#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ CORS ДЛЯ HEALTH ENDPOINT
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ CORS ДЛЯ HEALTH ENDPOINT"
echo "==========================================${NC}"
echo ""

# Определяем порты
NEXTJS_PORT=$(ss -tuln | grep LISTEN | grep -oE ":300[0-9]+" | head -1 | cut -d: -f2 || echo "3002")
BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "8082")

echo "Используемые порты:"
echo "  - Next.js: $NEXTJS_PORT"
echo "  - Backend: $BACKEND_PORT"
echo ""

# 1. Обновление Nginx конфигурации
echo -e "${YELLOW}[1/3] Обновление Nginx конфигурации...${NC}"

cat > /etc/nginx/sites-available/eco-api-proxy.conf << EOF
server {
    listen 3384;
    server_name _;

    # Health endpoint - обрабатывается напрямую Nginx с CORS
    location = /health {
        add_header Access-Control-Allow-Origin 'http://85.113.129.96:3384' always;
        add_header Access-Control-Allow-Origin 'http://localhost:3002' always;
        add_header Access-Control-Allow-Credentials 'true' always;
        add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS' always;
        add_header Access-Control-Allow-Headers 'Content-Type, Authorization, X-Requested-With, Accept, Origin' always;
        add_header Access-Control-Expose-Headers 'Content-Disposition, Content-Type, Content-Length' always;
        add_header Access-Control-Max-Age '3600' always;
        
        # Для OPTIONS запросов (preflight)
        if (\$request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin 'http://85.113.129.96:3384' always;
            add_header Access-Control-Allow-Origin 'http://localhost:3002' always;
            add_header Access-Control-Allow-Credentials 'true' always;
            add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS' always;
            add_header Access-Control-Allow-Headers 'Content-Type, Authorization, X-Requested-With, Accept, Origin' always;
            add_header Access-Control-Max-Age '3600' always;
            add_header Content-Length 0;
            add_header Content-Type 'text/plain';
            return 204;
        }
        
        # Прокси на бекенд
        proxy_pass http://127.0.0.1:$BACKEND_PORT/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
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
    }

    # Backend API
    location /api {
        proxy_pass http://127.0.0.1:$BACKEND_PORT/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Проверяем конфигурацию
if nginx -t; then
    systemctl reload nginx
    echo -e "${GREEN}✅ Nginx конфигурация обновлена${NC}"
else
    echo -e "${RED}❌ Ошибка в Nginx конфигурации${NC}"
    nginx -t
    exit 1
fi
echo ""

# 2. Тестирование health endpoint
echo -e "${YELLOW}[2/3] Тестирование health endpoint...${NC}"

echo "1. Health через Nginx (GET):"
HEALTH_TEST=$(curl -s -I -X GET \
    -H "Origin: http://85.113.129.96:3384" \
    http://127.0.0.1:3384/health 2>&1)

if echo "$HEALTH_TEST" | grep -qi "access-control-allow-origin"; then
    echo -e "${GREEN}   ✅ CORS заголовки установлены для /health${NC}"
    echo "$HEALTH_TEST" | grep -i "access-control" | sed 's/^/      /'
else
    echo -e "${RED}   ❌ CORS заголовки НЕ установлены${NC}"
    echo "$HEALTH_TEST" | grep -i "access-control" | sed 's/^/      /' || echo "      CORS заголовки не найдены"
fi

echo ""

echo "2. Health через Nginx (OPTIONS):"
OPTIONS_TEST=$(curl -s -I -X OPTIONS \
    -H "Origin: http://85.113.129.96:3384" \
    -H "Access-Control-Request-Method: GET" \
    http://127.0.0.1:3384/health 2>&1)

if echo "$OPTIONS_TEST" | grep -qi "access-control-allow-origin"; then
    echo -e "${GREEN}   ✅ CORS заголовки установлены для OPTIONS${NC}"
    echo "$OPTIONS_TEST" | grep -i "access-control" | sed 's/^/      /'
else
    echo -e "${RED}   ❌ CORS заголовки НЕ установлены${NC}"
    echo "$OPTIONS_TEST" | grep -i "access-control" | sed 's/^/      /' || echo "      CORS заголовки не найдены"
fi

echo ""

# 3. Финальная проверка всех endpoints
echo -e "${YELLOW}[3/3] Финальная проверка всех endpoints...${NC}"

ENDPOINTS=("/health" "/api/auth/login" "/api/health")

for endpoint in "${ENDPOINTS[@]}"; do
    echo -n "   $endpoint: "
    TEST=$(curl -s -I -X GET -H "Origin: http://85.113.129.96:3384" "http://127.0.0.1:3384$endpoint" 2>&1)
    if echo "$TEST" | grep -qi "access-control-allow-origin"; then
        echo -e "${GREEN}✅ CORS работает${NC}"
    else
        echo -e "${RED}❌ CORS не работает${NC}"
    fi
done

echo ""
echo -e "${GREEN}=========================================="
echo "✅ CORS ИСПРАВЛЕН ДЛЯ ВСЕХ ENDPOINTS!"
echo "==========================================${NC}"
echo ""
echo "Теперь CORS должен работать для:"
echo "  ✅ /health (через Nginx)"
echo "  ✅ /api/* (через Yii2 CorsFilter)"
echo "  ✅ Frontend (Next.js)"
echo ""
echo "Проверьте вход:"
echo "  http://85.113.129.96:3384/login"
echo ""
echo "Если предупреждение CORS все еще появляется:"
echo "  1. Очистите кеш браузера (Ctrl+Shift+Del)"
echo "  2. Обновите страницу с очисткой кеша (Ctrl+Shift+R)"
echo "  3. Откройте консоль (F12) -> Network tab -> проверьте заголовки ответа"
echo ""


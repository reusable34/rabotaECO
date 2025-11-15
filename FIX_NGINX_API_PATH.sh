#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ ПУТИ /api В NGINX
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ ПУТИ /api"
echo "==========================================${NC}"
echo ""

# 1. Обновление конфигурации Nginx
echo -e "${YELLOW}[1/3] Обновление конфигурации Nginx...${NC}"

# Определяем порты
NEXTJS_PORT=$(ss -tuln | grep LISTEN | grep -oE ":300[0-9]+" | head -1 | cut -d: -f2 || echo "3000")
BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "8080")

echo "Next.js порт: $NEXTJS_PORT"
echo "Backend порт: $BACKEND_PORT"
echo ""

cat > /etc/nginx/sites-available/eco-api-proxy.conf << EOF
server {
    listen 3384;
    server_name _;

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

    # Backend API - ВАЖНО: завершающий слэш убирает /api из пути
    location /api {
        proxy_pass http://127.0.0.1:$BACKEND_PORT/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Для CORS
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type' always;
        
        if (\$request_method = 'OPTIONS') {
            return 204;
        }
    }
}
EOF

echo -e "${GREEN}✅ Конфигурация обновлена${NC}"
echo "Важно: proxy_pass теперь с завершающим слэшем, чтобы убрать /api из пути"
echo ""

# 2. Проверка синтаксиса
echo -e "${YELLOW}[2/3] Проверка синтаксиса...${NC}"
if nginx -t; then
    echo -e "${GREEN}✅ Синтаксис корректен${NC}"
else
    echo -e "${RED}❌ Ошибка в синтаксисе${NC}"
    nginx -t
    exit 1
fi
echo ""

# 3. Перезапуск Nginx
echo -e "${YELLOW}[3/3] Перезапуск Nginx...${NC}"
systemctl reload nginx || systemctl restart nginx
sleep 2
echo -e "${GREEN}✅ Nginx перезапущен${NC}"
echo ""

# 4. Тестирование
echo -e "${YELLOW}Тестирование...${NC}"
echo "1. Backend напрямую:"
curl -s http://127.0.0.1:$BACKEND_PORT/health | head -3
echo ""
echo "2. Backend через Nginx /api/health:"
API_RESPONSE=$(curl -s http://127.0.0.1:3384/api/health)
if echo "$API_RESPONSE" | grep -q "status\|ok"; then
    echo -e "${GREEN}✅ API работает!${NC}"
    echo "$API_RESPONSE" | head -3
else
    echo -e "${RED}❌ API не работает${NC}"
    echo "Ответ: $API_RESPONSE"
fi
echo ""

echo -e "${GREEN}=========================================="
echo "✅ ИСПРАВЛЕНО!"
echo "==========================================${NC}"
echo ""
echo "Теперь запросы работают так:"
echo "  /api/health → http://127.0.0.1:$BACKEND_PORT/health"
echo "  /api/auth/login → http://127.0.0.1:$BACKEND_PORT/auth/login"
echo ""
echo "Проверьте вход:"
echo "  http://85.113.129.96:3384/login"
echo ""


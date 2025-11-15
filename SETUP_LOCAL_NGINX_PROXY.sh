#!/bin/bash
# ==========================================
# НАСТРОЙКА ЛОКАЛЬНОГО NGINX ДЛЯ ПРОКСИРОВАНИЯ API
# ==========================================
# Выполните ВНУТРИ контейнера 102
# Это нужно, если Nginx Proxy Manager НЕ настроен

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 НАСТРОЙКА ЛОКАЛЬНОГО NGINX ДЛЯ API"
echo "==========================================${NC}"
echo ""

# 1. Проверка Nginx
if ! command -v nginx &> /dev/null; then
    echo -e "${RED}❌ Nginx не установлен${NC}"
    exit 1
fi

# 2. Создание конфигурации для проксирования API
echo -e "${YELLOW}[1/4] Создание конфигурации Nginx...${NC}"

cat > /etc/nginx/sites-available/eco-api-proxy.conf << 'EOF'
# Проксирование API запросов с frontend на backend
server {
    listen 3384;
    server_name _;

    # Frontend (Next.js)
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Backend API
    location /api {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Для CORS (если нужно)
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type' always;
        
        if ($request_method = 'OPTIONS') {
            return 204;
        }
    }
}
EOF

echo -e "${GREEN}✅ Конфигурация создана${NC}"
echo ""

# 3. Активация конфигурации
echo -e "${YELLOW}[2/4] Активация конфигурации...${NC}"
ln -sf /etc/nginx/sites-available/eco-api-proxy.conf /etc/nginx/sites-enabled/eco-api-proxy.conf
echo -e "${GREEN}✅ Конфигурация активирована${NC}"
echo ""

# 4. Проверка конфигурации
echo -e "${YELLOW}[3/4] Проверка конфигурации Nginx...${NC}"
if nginx -t; then
    echo -e "${GREEN}✅ Конфигурация корректна${NC}"
else
    echo -e "${RED}❌ Ошибка в конфигурации${NC}"
    exit 1
fi
echo ""

# 5. Перезапуск Nginx
echo -e "${YELLOW}[4/4] Перезапуск Nginx...${NC}"
systemctl reload nginx || systemctl restart nginx
echo -e "${GREEN}✅ Nginx перезапущен${NC}"
echo ""

# 6. Настройка frontend
echo -e "${YELLOW}[5/5] Настройка frontend...${NC}"
cd /opt/eco-project/frontend

cat > .env.local << 'EOF'
NEXT_PUBLIC_API_URL=/api
NEXT_PUBLIC_ENV=production
EOF

echo -e "${GREEN}✅ Frontend настроен на использование /api${NC}"
echo ""

# 7. Пересборка frontend
echo -e "${YELLOW}[6/6] Пересборка frontend...${NC}"
npm run build
echo -e "${GREEN}✅ Frontend пересобран${NC}"
echo ""

# 8. Перезапуск Next.js
echo -e "${YELLOW}[7/7] Перезапуск Next.js...${NC}"
systemctl restart nextjs
sleep 3

if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен${NC}"
else
    echo -e "${RED}❌ Next.js не запустился${NC}"
    journalctl -u nextjs -n 20 --no-pager
    exit 1
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Теперь всё работает через один порт:"
echo "  - Frontend: http://85.113.129.96:3384/"
echo "  - Backend API: http://85.113.129.96:3384/api"
echo ""
echo "Frontend обращается к API через относительный путь /api"
echo "Nginx автоматически проксирует /api на backend (localhost:8080)"
echo ""
echo -e "${YELLOW}ВАЖНО:${NC}"
echo "1. Убедитесь, что Next.js слушает на порту 3001 (не 3000)"
echo "2. Убедитесь, что backend слушает на порту 8080"
echo "3. Порт 3384 должен быть проброшен в роутере"
echo ""


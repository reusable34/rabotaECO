#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ CORS БЕЗОПАСНОСТИ
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ CORS БЕЗОПАСНОСТИ"
echo "==========================================${NC}"
echo ""

# 1. Убираем wildcard CORS из Nginx
echo -e "${YELLOW}[1/3] Обновление Nginx конфигурации...${NC}"

# Определяем порты
NEXTJS_PORT=$(ss -tuln | grep LISTEN | grep -oE ":300[0-9]+" | head -1 | cut -d: -f2 || echo "3000")
BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "8080")

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
        
        # НЕ устанавливаем CORS заголовки здесь - это делает backend
        # Backend сам управляет CORS с правильными origins
    }
}
EOF

echo -e "${GREEN}✅ Nginx конфигурация обновлена (убраны wildcard CORS заголовки)${NC}"
echo ""

# 2. Проверка синтаксиса
echo -e "${YELLOW}[2/3] Проверка синтаксиса Nginx...${NC}"
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

# 4. Информация о backend
echo -e "${YELLOW}Информация:${NC}"
echo "Backend CORS настроен в backend/api/components/CorsFilter.php"
echo "Разрешенные origins:"
echo "  - http://localhost:3000"
echo "  - http://127.0.0.1:3000"
echo "  - http://localhost:3001"
echo "  - http://127.0.0.1:3001"
echo "  - http://85.113.129.96:3384"
echo "  - http://192.168.0.32:3384"
echo ""
echo "Если нужно добавить другие origins, отредактируйте:"
echo "  backend/api/components/CorsFilter.php"
echo ""

echo -e "${GREEN}=========================================="
echo "✅ ИСПРАВЛЕНО!"
echo "==========================================${NC}"
echo ""
echo "Теперь CORS настроен безопасно:"
echo "  - Нет wildcard origins"
echo "  - Конкретные разрешенные origins"
echo "  - Credentials работают только с разрешенными origins"
echo ""
echo "Проверьте вход:"
echo "  http://85.113.129.96:3384/login"
echo ""


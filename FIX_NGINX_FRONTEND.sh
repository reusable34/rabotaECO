#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ NGINX ДЛЯ FRONTEND
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ NGINX ДЛЯ FRONTEND"
echo "==========================================${NC}"
echo ""

# 1. Проверка прав доступа
echo -e "${YELLOW}[1/4] Проверка прав доступа...${NC}"
chown -R www-data:www-data /opt/eco-project/frontend/.next
chmod -R 755 /opt/eco-project/frontend/.next
echo -e "${GREEN}✅ Права установлены${NC}"
echo ""

# 2. Создание правильной конфигурации Nginx для frontend
echo -e "${YELLOW}[2/4] Создание конфигурации Nginx...${NC}"

cat > /etc/nginx/sites-available/eco-frontend << 'NGINX_EOF'
server {
    listen 3001;
    server_name _;
    
    root /opt/eco-project/frontend/.next;
    index index.html;

    # Логи
    access_log /var/log/nginx/eco-frontend-access.log;
    error_log /var/log/nginx/eco-frontend-error.log;

    # Основные файлы
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache";
    }

    # Статические файлы Next.js
    location /_next/static {
        alias /opt/eco-project/frontend/.next/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Другие статические файлы
    location /static {
        alias /opt/eco-project/frontend/public;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Запрет доступа к скрытым файлам
    location ~ /\. {
        deny all;
    }
}
NGINX_EOF

# Создаем симлинк если его нет
ln -sf /etc/nginx/sites-available/eco-frontend /etc/nginx/sites-enabled/

echo -e "${GREEN}✅ Конфигурация создана${NC}"
echo ""

# 3. Проверка конфигурации
echo -e "${YELLOW}[3/4] Проверка конфигурации Nginx...${NC}"
if nginx -t; then
    echo -e "${GREEN}✅ Конфигурация корректна${NC}"
else
    echo -e "${RED}❌ Ошибка в конфигурации!${NC}"
    exit 1
fi
echo ""

# 4. Перезагрузка Nginx
echo -e "${YELLOW}[4/4] Перезагрузка Nginx...${NC}"
systemctl reload nginx
echo -e "${GREEN}✅ Nginx перезагружен${NC}"
echo ""

echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Проверьте:"
echo "  curl http://127.0.0.1:3001"
echo "  curl -I http://127.0.0.1:3001"
echo ""


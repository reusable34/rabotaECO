#!/bin/bash
# ==========================================
# ПРОВЕРКА И ЗАПУСК BACKEND
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔍 ПРОВЕРКА И ЗАПУСК BACKEND"
echo "==========================================${NC}"
echo ""

# 1. Проверка Nginx
echo -e "${YELLOW}[1/4] Проверка Nginx...${NC}"
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Nginx работает${NC}"
else
    echo -e "${YELLOW}⚠️ Nginx не работает, запускаю...${NC}"
    systemctl start nginx
    systemctl enable nginx
    echo -e "${GREEN}✅ Nginx запущен${NC}"
fi
echo ""

# 2. Проверка PHP-FPM
echo -e "${YELLOW}[2/4] Проверка PHP-FPM...${NC}"
if systemctl is-active --quiet php8.2-fpm; then
    echo -e "${GREEN}✅ PHP-FPM работает${NC}"
else
    echo -e "${YELLOW}⚠️ PHP-FPM не работает, запускаю...${NC}"
    systemctl start php8.2-fpm
    systemctl enable php8.2-fpm
    echo -e "${GREEN}✅ PHP-FPM запущен${NC}"
fi
echo ""

# 3. Проверка конфигурации Nginx для backend
echo -e "${YELLOW}[3/4] Проверка конфигурации Nginx для backend...${NC}"
if [ ! -f "/etc/nginx/sites-available/eco-backend" ]; then
    echo "Создание конфигурации Nginx для backend..."
    cat > /etc/nginx/sites-available/eco-backend << 'NGINX_EOF'
server {
    listen 8080;
    server_name _;
    root /opt/eco-project/backend/api/web;
    index index.php;

    access_log /var/log/nginx/eco-backend-access.log;
    error_log /var/log/nginx/eco-backend-error.log;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\. {
        deny all;
    }
}
NGINX_EOF

    ln -sf /etc/nginx/sites-available/eco-backend /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    echo -e "${GREEN}✅ Конфигурация создана${NC}"
else
    echo -e "${GREEN}✅ Конфигурация уже существует${NC}"
    nginx -t && systemctl reload nginx
fi
echo ""

# 4. Проверка Backend
echo -e "${YELLOW}[4/4] Проверка Backend...${NC}"
sleep 2
BACKEND_RESPONSE=$(curl -s http://127.0.0.1:8080/health 2>/dev/null || echo "ERROR")
if echo "$BACKEND_RESPONSE" | grep -q "connected"; then
    echo -e "${GREEN}✅ Backend работает, база данных подключена${NC}"
    echo "Ответ: $BACKEND_RESPONSE"
else
    echo -e "${YELLOW}⚠️ Backend не отвечает или база данных не подключена${NC}"
    echo "Ответ: $BACKEND_RESPONSE"
    echo ""
    echo "Проверьте:"
    echo "  systemctl status nginx"
    echo "  systemctl status php8.2-fpm"
    echo "  tail -20 /var/log/nginx/eco-backend-error.log"
fi
echo ""

echo -e "${GREEN}=========================================="
echo "✅ ПРОВЕРКА ЗАВЕРШЕНА"
echo "==========================================${NC}"
echo ""
echo "Проверьте:"
echo "  curl http://127.0.0.1:8080/health"
echo "  curl http://127.0.0.1:3001"
echo ""


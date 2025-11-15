#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ КОНФИГУРАЦИИ БЕЗ DOCKER
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ КОНФИГУРАЦИИ"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project

# 1. Создание .env файла для backend
echo -e "${YELLOW}[1/3] Создание .env файла для backend...${NC}"
cat > backend/.env << 'EOF'
DB_HOST=localhost
DB_NAME=eco_client
DB_USER=eco_admin
DB_PASSWORD=eco_pass
JWT_SECRET=supersecretkey
BACKEND_URL=http://localhost:8080
EOF

echo -e "${GREEN}✅ .env файл создан${NC}"
echo ""

# 2. Настройка переменных окружения в systemd для PHP-FPM
echo -e "${YELLOW}[2/3] Настройка переменных окружения для PHP-FPM...${NC}"

# Создаем файл окружения для PHP-FPM
cat > /etc/php/8.2/fpm/pool.d/www.conf.env << 'EOF'
env[DB_HOST] = localhost
env[DB_NAME] = eco_client
env[DB_USER] = eco_admin
env[DB_PASSWORD] = eco_pass
env[JWT_SECRET] = supersecretkey
env[BACKEND_URL] = http://localhost:8080
EOF

# Добавляем в основной конфиг PHP-FPM
if ! grep -q "include=/etc/php/8.2/fpm/pool.d/www.conf.env" /etc/php/8.2/fpm/pool.d/www.conf 2>/dev/null; then
    echo "include=/etc/php/8.2/fpm/pool.d/www.conf.env" >> /etc/php/8.2/fpm/pool.d/www.conf
fi

# Перезапускаем PHP-FPM
systemctl restart php8.2-fpm

echo -e "${GREEN}✅ PHP-FPM настроен${NC}"
echo ""

# 3. Исправление health.php
echo -e "${YELLOW}[3/3] Исправление health.php...${NC}"
sed -i "s/getenv('DB_HOST') ?: 'db'/getenv('DB_HOST') ?: 'localhost'/g" backend/api/web/health.php

echo -e "${GREEN}✅ health.php исправлен${NC}"
echo ""

# 4. Проверка Nginx конфигурации для frontend
echo -e "${YELLOW}[4/3] Проверка Nginx конфигурации...${NC}"

# Проверяем, есть ли конфигурация для frontend
if [ ! -f "/etc/nginx/sites-available/eco-frontend" ]; then
    echo "Создание конфигурации Nginx для frontend..."
    cat > /etc/nginx/sites-available/eco-frontend << 'NGINX_EOF'
server {
    listen 3001;
    server_name _;
    root /opt/eco-project/frontend/.next;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /_next/static {
        alias /opt/eco-project/frontend/.next/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
NGINX_EOF

    ln -sf /etc/nginx/sites-available/eco-frontend /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    echo -e "${GREEN}✅ Nginx конфигурация создана${NC}"
else
    echo -e "${GREEN}✅ Nginx конфигурация уже существует${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Проверьте:"
echo "  systemctl status php8.2-fpm"
echo "  curl http://127.0.0.1:8080/health"
echo "  curl http://127.0.0.1:3001"
echo ""


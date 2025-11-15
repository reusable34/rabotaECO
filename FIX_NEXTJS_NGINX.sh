#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ NGINX ДЛЯ NEXT.JS
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ NGINX ДЛЯ NEXT.JS"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project/frontend

# 1. Проверка структуры
echo -e "${YELLOW}[1/5] Проверка структуры Next.js...${NC}"
echo "Содержимое .next:"
ls -la .next/ | head -10
echo ""
echo "Поиск index.html:"
find .next -name "*.html" -type f 2>/dev/null | head -5
echo ""

# 2. Проверка package.json
echo -e "${YELLOW}[2/5] Проверка package.json...${NC}"
if grep -q '"output": "export"' package.json 2>/dev/null; then
    echo "Найден статический экспорт"
    EXPORT_MODE="static"
else
    echo "Статический экспорт не найден, используем Node.js сервер"
    EXPORT_MODE="server"
fi
echo ""

# 3. Если статический экспорт - создаем правильную структуру
if [ "$EXPORT_MODE" = "static" ]; then
    echo -e "${YELLOW}[3/5] Настройка для статического экспорта...${NC}"
    
    # Проверяем наличие out директории
    if [ -d "out" ]; then
        ROOT_DIR="/opt/eco-project/frontend/out"
        echo "Используем директорию out"
    elif [ -d ".next/export" ]; then
        ROOT_DIR="/opt/eco-project/frontend/.next/export"
        echo "Используем директорию .next/export"
    else
        # Создаем экспорт
        echo "Создание статического экспорта..."
        npm run build
        if [ -d "out" ]; then
            ROOT_DIR="/opt/eco-project/frontend/out"
        else
            ROOT_DIR="/opt/eco-project/frontend/.next"
        fi
    fi
else
    echo -e "${YELLOW}[3/5] Настройка для Node.js сервера...${NC}"
    ROOT_DIR="/opt/eco-project/frontend"
fi

echo "ROOT_DIR: $ROOT_DIR"
echo ""

# 4. Создание конфигурации Nginx
echo -e "${YELLOW}[4/5] Создание конфигурации Nginx...${NC}"

if [ "$EXPORT_MODE" = "static" ]; then
    # Статический экспорт
    cat > /etc/nginx/sites-available/eco-frontend << NGINX_EOF
server {
    listen 3001;
    server_name _;
    
    root $ROOT_DIR;
    index index.html;

    access_log /var/log/nginx/eco-frontend-access.log;
    error_log /var/log/nginx/eco-frontend-error.log;

    location / {
        try_files \$uri \$uri.html \$uri/ /index.html;
    }

    location /_next/static {
        alias /opt/eco-project/frontend/.next/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location ~ /\. {
        deny all;
    }
}
NGINX_EOF
else
    # Node.js сервер через proxy
    cat > /etc/nginx/sites-available/eco-frontend << NGINX_EOF
server {
    listen 3001;
    server_name _;

    access_log /var/log/nginx/eco-frontend-access.log;
    error_log /var/log/nginx/eco-frontend-error.log;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINX_EOF
    
    # Запускаем Next.js сервер в фоне
    echo "Запуск Next.js сервера..."
    cd /opt/eco-project/frontend
    nohup npm start > /var/log/nextjs.log 2>&1 &
    sleep 3
fi

ln -sf /etc/nginx/sites-available/eco-frontend /etc/nginx/sites-enabled/

echo -e "${GREEN}✅ Конфигурация создана${NC}"
echo ""

# 5. Установка прав и перезагрузка
echo -e "${YELLOW}[5/5] Установка прав и перезагрузка...${NC}"
chown -R www-data:www-data /opt/eco-project/frontend
chmod -R 755 /opt/eco-project/frontend

if nginx -t; then
    systemctl reload nginx
    echo -e "${GREEN}✅ Nginx перезагружен${NC}"
else
    echo -e "${RED}❌ Ошибка в конфигурации!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Проверьте:"
echo "  curl http://127.0.0.1:3001"
echo "  tail -f /var/log/nginx/eco-frontend-error.log"
echo ""


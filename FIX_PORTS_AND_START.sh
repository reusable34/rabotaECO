#!/bin/bash
# ==========================================
# НАСТРОЙКА НА СВОБОДНЫХ ПОРТАХ
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 НАСТРОЙКА НА СВОБОДНЫХ ПОРТАХ"
echo "==========================================${NC}"
echo ""

# Функция для поиска свободного порта
find_free_port() {
    local start_port=$1
    local port=$start_port
    while ss -tuln | grep -q ":$port "; do
        port=$((port + 1))
    done
    echo $port
}

# 1. Остановка всех сервисов
echo -e "${YELLOW}[1/8] Остановка сервисов...${NC}"
systemctl stop nextjs 2>/dev/null || true
systemctl stop php8.2-fpm 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
sleep 2
echo -e "${GREEN}✅ Сервисы остановлены${NC}"
echo ""

# 2. Поиск свободных портов
echo -e "${YELLOW}[2/8] Поиск свободных портов...${NC}"
NEXTJS_PORT=$(find_free_port 3002)
BACKEND_PORT=$(find_free_port 8081)
NGINX_PORT=3384

echo "Next.js будет на порту: $NEXTJS_PORT"
echo "Backend будет на порту: $BACKEND_PORT"
echo "Nginx будет на порту: $NGINX_PORT"
echo ""

# 3. Настройка Next.js
echo -e "${YELLOW}[3/8] Настройка Next.js на порт $NEXTJS_PORT...${NC}"
cd /opt/eco-project/frontend

# Обновляем package.json
if grep -q '"start":' package.json; then
    sed -i "s/\"start\":.*/\"start\": \"next start -p $NEXTJS_PORT\",/" package.json
else
    # Добавляем если нет
    sed -i '/"scripts": {/a\    "start": "next start -p '"$NEXTJS_PORT"'",' package.json
fi

echo -e "${GREEN}✅ package.json обновлен${NC}"
echo ""

# 4. Обновление systemd service для Next.js
echo -e "${YELLOW}[4/8] Обновление systemd service...${NC}"
cat > /etc/systemd/system/nextjs.service << EOF
[Unit]
Description=Next.js Frontend Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/eco-project/frontend
Environment=NODE_ENV=production
Environment=PORT=$NEXTJS_PORT
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo -e "${GREEN}✅ systemd service обновлен${NC}"
echo ""

# 5. Настройка backend на новый порт
echo -e "${YELLOW}[5/8] Настройка backend на порт $BACKEND_PORT...${NC}"
cd /opt/eco-project

# Обновляем Nginx конфигурацию для backend
if [ -f /etc/nginx/sites-available/eco-backend.conf ]; then
    sed -i "s/listen.*8080/listen $BACKEND_PORT/" /etc/nginx/sites-available/eco-backend.conf
    sed -i "s/proxy_pass.*8080/proxy_pass http:\/\/127.0.0.1:8080/" /etc/nginx/sites-available/eco-backend.conf
else
    # Создаем конфигурацию для backend
    cat > /etc/nginx/sites-available/eco-backend.conf << EOF
server {
    listen $BACKEND_PORT;
    server_name _;
    root /opt/eco-project/backend/api/web;
    index index.php;

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
fi

echo -e "${GREEN}✅ Backend настроен на порт $BACKEND_PORT${NC}"
echo ""

# 6. Обновление Nginx конфигурации для проксирования
echo -e "${YELLOW}[6/8] Обновление Nginx прокси...${NC}"
cat > /etc/nginx/sites-available/eco-api-proxy.conf << EOF
server {
    listen $NGINX_PORT;
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

    # Backend API
    location /api {
        proxy_pass http://127.0.0.1:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/eco-api-proxy.conf /etc/nginx/sites-enabled/eco-api-proxy.conf
echo -e "${GREEN}✅ Nginx прокси обновлен${NC}"
echo ""

# 7. Настройка frontend .env.local
echo -e "${YELLOW}[7/8] Настройка frontend .env.local...${NC}"
cd /opt/eco-project/frontend
cat > .env.local << EOF
NEXT_PUBLIC_API_URL=/api
NEXT_PUBLIC_ENV=production
PORT=$NEXTJS_PORT
EOF

echo -e "${GREEN}✅ .env.local обновлен${NC}"
echo ""

# 8. Запуск сервисов
echo -e "${YELLOW}[8/8] Запуск сервисов...${NC}"

# Проверка конфигурации Nginx
if nginx -t; then
    systemctl start nginx
    echo -e "${GREEN}✅ Nginx запущен${NC}"
else
    echo -e "${RED}❌ Ошибка в конфигурации Nginx${NC}"
    nginx -t
    exit 1
fi

# Запуск PHP-FPM
systemctl start php8.2-fpm
echo -e "${GREEN}✅ PHP-FPM запущен${NC}"

# Запуск Next.js
systemctl start nextjs
sleep 5

if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен на порту $NEXTJS_PORT${NC}"
else
    echo -e "${RED}❌ Next.js не запустился${NC}"
    journalctl -u nextjs -n 20 --no-pager
    exit 1
fi

# Проверка портов
echo ""
echo -e "${YELLOW}Проверка портов...${NC}"
echo "Порт $NEXTJS_PORT (Next.js):"
ss -tuln | grep ":$NEXTJS_PORT " && echo "  ✅ Слушает" || echo "  ❌ Не слушает"
echo "Порт $BACKEND_PORT (Backend):"
ss -tuln | grep ":$BACKEND_PORT " && echo "  ✅ Слушает" || echo "  ❌ Не слушает"
echo "Порт $NGINX_PORT (Nginx):"
ss -tuln | grep ":$NGINX_PORT " && echo "  ✅ Слушает" || echo "  ❌ Не слушает"
echo ""

# Тесты
echo -e "${YELLOW}Тестирование...${NC}"
echo "1. Backend health:"
curl -s http://127.0.0.1:$BACKEND_PORT/health | head -3 || echo "  ❌ Не отвечает"
echo ""
echo "2. Next.js:"
curl -s http://127.0.0.1:$NEXTJS_PORT | head -3 || echo "  ❌ Не отвечает"
echo ""
echo "3. API через Nginx:"
curl -s http://127.0.0.1:$NGINX_PORT/api/health | head -3 || echo "  ❌ Не отвечает"
echo ""

echo -e "${GREEN}=========================================="
echo "✅ ВСЁ НАСТРОЕНО!"
echo "==========================================${NC}"
echo ""
echo "Порты:"
echo "  - Next.js: $NEXTJS_PORT"
echo "  - Backend: $BACKEND_PORT"
echo "  - Nginx (публичный): $NGINX_PORT"
echo ""
echo "Доступ:"
echo "  - Frontend: http://85.113.129.96:$NGINX_PORT/"
echo "  - Backend API: http://85.113.129.96:$NGINX_PORT/api"
echo ""
echo -e "${YELLOW}ВАЖНО:${NC}"
echo "Убедитесь, что порт $NGINX_PORT проброшен в роутере!"
echo ""


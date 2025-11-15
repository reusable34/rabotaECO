#!/bin/bash
# ==========================================
# ПРИНУДИТЕЛЬНОЕ ИСПРАВЛЕНИЕ ПОРТА NEXT.JS
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ПРИНУДИТЕЛЬНОЕ ИСПРАВЛЕНИЕ ПОРТА NEXT.JS"
echo "==========================================${NC}"
echo ""

# Функция для поиска свободного порта
find_free_port() {
    local start_port=$1
    local port=$start_port
    while ss -tuln | grep -q ":$port "; do
        port=$((port + 1))
        if [ $port -gt 9999 ]; then
            echo "ERROR"
            return
        fi
    done
    echo $port
}

# 1. Остановка Next.js
echo -e "${YELLOW}[1/7] Остановка Next.js...${NC}"
systemctl stop nextjs 2>/dev/null || true
pkill -f "next start" 2>/dev/null || true
pkill -f "node.*next" 2>/dev/null || true
sleep 3
echo -e "${GREEN}✅ Next.js остановлен${NC}"
echo ""

# 2. Поиск свободного порта
echo -e "${YELLOW}[2/7] Поиск свободного порта...${NC}"
NEXTJS_PORT=$(find_free_port 3002)

if [ "$NEXTJS_PORT" = "ERROR" ]; then
    echo -e "${RED}❌ Не удалось найти свободный порт${NC}"
    exit 1
fi

echo "Найден свободный порт: $NEXTJS_PORT"
echo ""

# 3. Обновление package.json
echo -e "${YELLOW}[3/7] Обновление package.json...${NC}"
cd /opt/eco-project/frontend

# Удаляем старые start команды
sed -i '/"start":/d' package.json

# Добавляем новую start команду с правильным портом
# Находим строку со "scripts" и добавляем после неё
if grep -q '"scripts"' package.json; then
    sed -i '/"scripts": {/a\    "start": "next start -p '"$NEXTJS_PORT"'",' package.json
else
    # Если нет scripts, создаем
    sed -i '/"private":/a\  "scripts": {\n    "start": "next start -p '"$NEXTJS_PORT"'",\n    "dev": "next dev",\n    "build": "next build",\n    "lint": "next lint"\n  },' package.json
fi

echo -e "${GREEN}✅ package.json обновлен${NC}"
echo "Проверка:"
grep -A 5 '"scripts"' package.json | head -6
echo ""

# 4. Обновление .env.local
echo -e "${YELLOW}[4/7] Обновление .env.local...${NC}"
cat > .env.local << EOF
# API URL - относительный путь (работает через Nginx прокси)
NEXT_PUBLIC_API_URL=/api

# Окружение
NEXT_PUBLIC_ENV=production

# Порт для Next.js
PORT=$NEXTJS_PORT
EOF

echo -e "${GREEN}✅ .env.local обновлен${NC}"
cat .env.local
echo ""

# 5. Обновление systemd service
echo -e "${YELLOW}[5/7] Обновление systemd service...${NC}"
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

# 6. Обновление Nginx конфигурации
echo -e "${YELLOW}[6/7] Обновление Nginx конфигурации...${NC}"
BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "8082")

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

if nginx -t; then
    systemctl reload nginx
    echo -e "${GREEN}✅ Nginx обновлен и перезапущен${NC}"
else
    echo -e "${RED}❌ Ошибка в конфигурации Nginx${NC}"
    nginx -t
    exit 1
fi
echo ""

# 7. Пересборка и запуск
echo -e "${YELLOW}[7/7] Пересборка и запуск Next.js...${NC}"
cd /opt/eco-project/frontend

echo "Пересборка frontend..."
npm run build

echo -e "${GREEN}✅ Frontend пересобран${NC}"
echo ""

echo "Запуск Next.js на порту $NEXTJS_PORT..."
systemctl start nextjs
sleep 8

if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен${NC}"
else
    echo -e "${RED}❌ Next.js не запустился${NC}"
    journalctl -u nextjs -n 30 --no-pager
    exit 1
fi

# Проверка порта
echo ""
echo "Проверка порта:"
if ss -tuln | grep -q ":$NEXTJS_PORT "; then
    echo -e "${GREEN}✅ Next.js слушает на порту $NEXTJS_PORT${NC}"
else
    echo -e "${RED}❌ Next.js НЕ слушает на порту $NEXTJS_PORT${NC}"
    echo "Активные порты 300x:"
    ss -tuln | grep ":300" || echo "  Нет портов 300x"
fi
echo ""

# Тест
echo "Тест Next.js:"
sleep 3
if curl -s http://127.0.0.1:$NEXTJS_PORT | head -1 | grep -q "html"; then
    echo -e "${GREEN}✅ Next.js отвечает на порту $NEXTJS_PORT${NC}"
else
    echo -e "${YELLOW}⚠️ Next.js может еще запускаться, подождите 10 секунд${NC}"
    sleep 10
    if curl -s http://127.0.0.1:$NEXTJS_PORT | head -1 | grep -q "html"; then
        echo -e "${GREEN}✅ Next.js теперь отвечает${NC}"
    else
        echo -e "${RED}❌ Next.js не отвечает${NC}"
        echo "Логи:"
        journalctl -u nextjs -n 20 --no-pager
    fi
fi
echo ""

echo -e "${GREEN}=========================================="
echo "✅ ПОРТ NEXT.JS ИСПРАВЛЕН!"
echo "==========================================${NC}"
echo ""
echo "Next.js теперь на порту: $NEXTJS_PORT (НЕ 3000!)"
echo "Nginx проксирует на: $NEXTJS_PORT"
echo ""
echo "Проверьте:"
echo "  http://85.113.129.96:3384/login"
echo ""


#!/bin/bash
# ==========================================
# УБИТЬ ВСЁ И НАСТРОИТЬ ЗАНОВО
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 УБИТЬ ВСЁ И НАСТРОИТЬ ЗАНОВО"
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

# 1. УБИВАЕМ ВСЕ ПРОЦЕССЫ NEXT.JS
echo -e "${YELLOW}[1/8] Убиваем все процессы Next.js...${NC}"
systemctl stop nextjs 2>/dev/null || true
pkill -9 -f "next start" 2>/dev/null || true
pkill -9 -f "node.*next" 2>/dev/null || true
pkill -9 -f "npm.*start" 2>/dev/null || true
sleep 3

# Проверяем что все убиты
if pgrep -f "next" > /dev/null; then
    echo -e "${RED}❌ Еще есть процессы Next.js, убиваю принудительно...${NC}"
    pkill -9 -f "next" 2>/dev/null || true
    sleep 2
fi

echo -e "${GREEN}✅ Все процессы Next.js убиты${NC}"
echo "Проверка:"
pgrep -f "next" && echo "  ⚠️ Еще есть процессы" || echo "  ✅ Процессов нет"
echo ""

# 2. Поиск свободного порта
echo -e "${YELLOW}[2/8] Поиск свободного порта...${NC}"
NEXTJS_PORT=$(find_free_port 3002)

if [ "$NEXTJS_PORT" = "ERROR" ]; then
    echo -e "${RED}❌ Не удалось найти свободный порт${NC}"
    exit 1
fi

echo "Найден свободный порт: $NEXTJS_PORT"
echo ""

# 3. Обновление package.json
echo -e "${YELLOW}[3/8] Обновление package.json...${NC}"
cd /opt/eco-project/frontend

# Удаляем ВСЕ start команды
sed -i '/"start":/d' package.json

# Добавляем правильную start команду
sed -i '/"scripts": {/a\    "start": "next start -p '"$NEXTJS_PORT"'",' package.json

echo -e "${GREEN}✅ package.json обновлен${NC}"
echo "Проверка:"
grep -A 2 '"start":' package.json
echo ""

# 4. Обновление .env.local
echo -e "${YELLOW}[4/8] Обновление .env.local...${NC}"
cat > .env.local << EOF
NEXT_PUBLIC_API_URL=/api
NEXT_PUBLIC_ENV=production
PORT=$NEXTJS_PORT
EOF

echo -e "${GREEN}✅ .env.local обновлен${NC}"
cat .env.local
echo ""

# 5. Обновление systemd service
echo -e "${YELLOW}[5/8] Обновление systemd service...${NC}"
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

# 6. Обновление Nginx
echo -e "${YELLOW}[6/8] Обновление Nginx...${NC}"
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
    echo -e "${GREEN}✅ Nginx обновлен${NC}"
else
    echo -e "${RED}❌ Ошибка в Nginx${NC}"
    nginx -t
    exit 1
fi
echo ""

# 7. Пересборка и запуск
echo -e "${YELLOW}[7/8] Пересборка и запуск...${NC}"
cd /opt/eco-project/frontend

echo "Пересборка..."
npm run build

echo -e "${GREEN}✅ Frontend пересобран${NC}"
echo ""

echo "Запуск Next.js на порту $NEXTJS_PORT..."
systemctl start nextjs
sleep 10

if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен${NC}"
else
    echo -e "${RED}❌ Next.js не запустился${NC}"
    journalctl -u nextjs -n 30 --no-pager
    exit 1
fi
echo ""

# 8. Финальная проверка
echo -e "${YELLOW}[8/8] Финальная проверка...${NC}"
echo ""

echo "Активные порты 300x:"
ss -tuln | grep ":300" || echo "  Нет портов 300x"
echo ""

echo "Проверка Next.js на порту $NEXTJS_PORT:"
if ss -tuln | grep -q ":$NEXTJS_PORT "; then
    echo -e "${GREEN}   ✅ Слушает на $NEXTJS_PORT${NC}"
else
    echo -e "${RED}   ❌ НЕ слушает на $NEXTJS_PORT${NC}"
    echo "   Активные порты:"
    ss -tuln | grep ":300" || echo "     Нет"
fi

echo ""
echo "Тест Next.js:"
sleep 5
if curl -s http://127.0.0.1:$NEXTJS_PORT | head -1 | grep -q "html"; then
    echo -e "${GREEN}   ✅ Отвечает${NC}"
else
    echo -e "${YELLOW}   ⚠️ Может еще запускаться${NC}"
    sleep 10
    if curl -s http://127.0.0.1:$NEXTJS_PORT | head -1 | grep -q "html"; then
        echo -e "${GREEN}   ✅ Теперь отвечает${NC}"
    else
        echo -e "${RED}   ❌ Не отвечает${NC}"
        echo "   Логи:"
        journalctl -u nextjs -n 20 --no-pager
    fi
fi

echo ""
echo "Тест Frontend через Nginx:"
if curl -s http://127.0.0.1:3384 | head -1 | grep -q "html"; then
    echo -e "${GREEN}   ✅ Работает${NC}"
else
    echo -e "${RED}   ❌ Не работает${NC}"
    echo "   Проверьте конфигурацию Nginx"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ВСЁ ИСПРАВЛЕНО!"
echo "==========================================${NC}"
echo ""
echo "Next.js должен быть на порту: $NEXTJS_PORT (НЕ 3000!)"
echo ""
echo "Если все еще на 3000, проверьте:"
echo "  1. cat /opt/eco-project/frontend/package.json | grep start"
echo "  2. systemctl status nextjs"
echo "  3. journalctl -u nextjs -f"
echo ""


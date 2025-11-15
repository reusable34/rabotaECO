#!/bin/bash
# ==========================================
# ИЗМЕНЕНИЕ ПОРТА FRONTEND НА 3384
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NEW_PORT=3384

echo -e "${BLUE}=========================================="
echo "🔧 ИЗМЕНЕНИЕ ПОРТА FRONTEND НА $NEW_PORT"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project/frontend

# 1. Остановка Next.js
echo -e "${YELLOW}[1/4] Остановка Next.js...${NC}"
systemctl stop nextjs 2>/dev/null || true
pkill -f "next start" 2>/dev/null || true
lsof -ti:3001 | xargs kill -9 2>/dev/null || true
lsof -ti:$NEW_PORT | xargs kill -9 2>/dev/null || true
sleep 2
echo -e "${GREEN}✅ Процессы остановлены${NC}"
echo ""

# 2. Обновление package.json
echo -e "${YELLOW}[2/4] Обновление package.json...${NC}"
if [ ! -f "package.json.backup" ]; then
    cp package.json package.json.backup
fi

# Заменяем порт в start скрипте
sed -i "s/\"start\": \"next start -p [0-9]*\"/\"start\": \"next start -p $NEW_PORT\"/g" package.json || \
sed -i "s/\"start\": \"next start\"/\"start\": \"next start -p $NEW_PORT\"/g" package.json

echo "Текущий start скрипт:"
grep '"start"' package.json
echo -e "${GREEN}✅ package.json обновлен${NC}"
echo ""

# 3. Обновление systemd сервиса
echo -e "${YELLOW}[3/4] Обновление systemd сервиса...${NC}"
cat > /etc/systemd/system/nextjs.service << SERVICE_EOF
[Unit]
Description=Next.js Frontend Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/eco-project/frontend
Environment=NODE_ENV=production
Environment=PORT=$NEW_PORT
Environment=NEXT_PUBLIC_API_URL=http://localhost:8080
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
echo -e "${GREEN}✅ Сервис обновлен${NC}"
echo ""

# 4. Запуск
echo -e "${YELLOW}[4/4] Запуск Next.js на порту $NEW_PORT...${NC}"
systemctl enable nextjs
systemctl start nextjs

sleep 5

# Проверка
if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен${NC}"
    sleep 2
    
    if curl -s http://127.0.0.1:$NEW_PORT > /dev/null; then
        echo -e "${GREEN}✅ Frontend отвечает на порту $NEW_PORT${NC}"
    else
        echo -e "${YELLOW}⚠️ Frontend запущен, но не отвечает. Проверьте логи:${NC}"
        echo "  journalctl -u nextjs -n 20"
    fi
else
    echo -e "${RED}❌ Next.js не запустился${NC}"
    echo "Логи:"
    journalctl -u nextjs -n 20 --no-pager
    exit 1
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}ИСПОЛЬЗУЕМЫЕ ПОРТЫ:${NC}"
echo "  Backend:  8080"
echo "  Frontend: $NEW_PORT"
echo ""
echo "Проверьте:"
echo "  curl http://127.0.0.1:8080/health"
echo "  curl http://127.0.0.1:$NEW_PORT"
echo ""
echo -e "${GREEN}После этого сайт должен работать:${NC}"
echo "  Локально: http://192.168.0.32:$NEW_PORT"
echo "  Интернет: http://85.113.129.96:$NEW_PORT"
echo ""


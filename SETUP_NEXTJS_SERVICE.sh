#!/bin/bash
# ==========================================
# НАСТРОЙКА SYSTEMD СЕРВИСА ДЛЯ NEXT.JS
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 НАСТРОЙКА SYSTEMD СЕРВИСА ДЛЯ NEXT.JS"
echo "==========================================${NC}"
echo ""

# 1. Создание systemd сервиса
echo -e "${YELLOW}[1/3] Создание systemd сервиса...${NC}"

cat > /etc/systemd/system/nextjs.service << 'SERVICE_EOF'
[Unit]
Description=Next.js Frontend Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/eco-project/frontend
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=NEXT_PUBLIC_API_URL=http://localhost:8080
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

echo -e "${GREEN}✅ Сервис создан${NC}"
echo ""

# 2. Перезагрузка systemd и запуск сервиса
echo -e "${YELLOW}[2/3] Запуск сервиса...${NC}"
systemctl daemon-reload
systemctl enable nextjs
systemctl start nextjs

sleep 3

# Проверка статуса
if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js сервер запущен${NC}"
else
    echo -e "${RED}❌ Next.js сервер не запустился${NC}"
    echo "Логи:"
    journalctl -u nextjs -n 20 --no-pager
    exit 1
fi
echo ""

# 3. Проверка
echo -e "${YELLOW}[3/3] Проверка работы...${NC}"
sleep 2
if curl -s http://127.0.0.1:3000 > /dev/null; then
    echo -e "${GREEN}✅ Next.js отвечает на порту 3000${NC}"
else
    echo -e "${YELLOW}⚠️ Next.js не отвечает, проверьте логи: journalctl -u nextjs -f${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Проверьте:"
echo "  systemctl status nextjs"
echo "  curl http://127.0.0.1:3000"
echo "  curl http://127.0.0.1:3001"
echo ""
echo "Логи:"
echo "  journalctl -u nextjs -f"
echo ""


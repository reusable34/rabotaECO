#!/bin/bash
# ==========================================
# ЗАПУСК NEXT.JS НАПРЯМУЮ НА ПОРТУ 3001
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🚀 ЗАПУСК NEXT.JS НАПРЯМУЮ"
echo "==========================================${NC}"
echo ""

# 1. Остановка всех процессов на портах 3000 и 3001
echo -e "${YELLOW}[1/4] Остановка процессов на портах 3000 и 3001...${NC}"
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
lsof -ti:3001 | xargs kill -9 2>/dev/null || true
systemctl stop nextjs 2>/dev/null || true
echo -e "${GREEN}✅ Порты освобождены${NC}"
echo ""

# 2. Удаление Nginx конфигурации для frontend (не нужна)
echo -e "${YELLOW}[2/4] Удаление Nginx конфигурации для frontend...${NC}"
rm -f /etc/nginx/sites-enabled/eco-frontend
rm -f /etc/nginx/sites-available/eco-frontend
systemctl reload nginx
echo -e "${GREEN}✅ Nginx конфигурация удалена${NC}"
echo ""

# 3. Создание systemd сервиса на порту 3001
echo -e "${YELLOW}[3/4] Создание systemd сервиса на порту 3001...${NC}"

cat > /etc/systemd/system/nextjs.service << 'SERVICE_EOF'
[Unit]
Description=Next.js Frontend Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/eco-project/frontend
Environment=NODE_ENV=production
Environment=PORT=3001
Environment=NEXT_PUBLIC_API_URL=http://localhost:8080
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Обновляем package.json чтобы использовать порт 3001
cd /opt/eco-project/frontend
if ! grep -q '"start": "next start -p 3001"' package.json 2>/dev/null; then
    # Создаем backup
    cp package.json package.json.backup
    
    # Обновляем start скрипт
    sed -i 's/"start": "next start"/"start": "next start -p 3001"/g' package.json || {
        # Если не нашли, добавляем вручную
        if ! grep -q '"start"' package.json; then
            # Добавляем в scripts
            sed -i '/"scripts": {/a\    "start": "next start -p 3001",' package.json
        fi
    }
fi

echo -e "${GREEN}✅ Сервис создан${NC}"
echo ""

# 4. Запуск сервиса
echo -e "${YELLOW}[4/4] Запуск сервиса...${NC}"
systemctl daemon-reload
systemctl enable nextjs
systemctl start nextjs

sleep 5

# Проверка статуса
if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js сервер запущен на порту 3001${NC}"
else
    echo -e "${RED}❌ Next.js сервер не запустился${NC}"
    echo "Логи:"
    journalctl -u nextjs -n 20 --no-pager
    exit 1
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Проверьте:"
echo "  systemctl status nextjs"
echo "  curl http://127.0.0.1:3001"
echo ""
echo "Next.js работает напрямую на порту 3001, Nginx не нужен для frontend"
echo "Настройте Nginx Proxy Manager:"
echo "  Forward Hostname/IP: 192.168.0.32"
echo "  Forward Port: 3001"
echo ""


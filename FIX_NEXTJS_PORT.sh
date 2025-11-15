#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ ПОРТА ДЛЯ NEXT.JS
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ ПОРТА ДЛЯ NEXT.JS"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project/frontend

# 1. Остановка всех процессов
echo -e "${YELLOW}[1/5] Остановка всех процессов...${NC}"
systemctl stop nextjs 2>/dev/null || true
pkill -f "next start" 2>/dev/null || true
pkill -f "node.*next" 2>/dev/null || true
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
lsof -ti:3001 | xargs kill -9 2>/dev/null || true
sleep 2
echo -e "${GREEN}✅ Процессы остановлены${NC}"
echo ""

# 2. Проверка что порты свободны
echo -e "${YELLOW}[2/5] Проверка портов...${NC}"
if lsof -ti:3000 > /dev/null 2>&1; then
    echo -e "${RED}❌ Порт 3000 все еще занят!${NC}"
    lsof -ti:3000 | xargs kill -9
    sleep 1
fi
if lsof -ti:3001 > /dev/null 2>&1; then
    echo -e "${RED}❌ Порт 3001 все еще занят!${NC}"
    lsof -ti:3001 | xargs kill -9
    sleep 1
fi
echo -e "${GREEN}✅ Порты свободны${NC}"
echo ""

# 3. Исправление package.json
echo -e "${YELLOW}[3/5] Исправление package.json...${NC}"
if [ ! -f "package.json.backup" ]; then
    cp package.json package.json.backup
fi

# Проверяем текущий start скрипт
if grep -q '"start": "next start -p 3001"' package.json; then
    echo -e "${GREEN}✅ package.json уже настроен на порт 3001${NC}"
else
    # Заменяем start скрипт
    sed -i 's/"start": "next start"/"start": "next start -p 3001"/g' package.json
    sed -i 's/"start": "next start -p 3000"/"start": "next start -p 3001"/g' package.json
    
    # Если не нашли, добавляем вручную
    if ! grep -q '"start": "next start -p 3001"' package.json; then
        # Ищем секцию scripts
        if grep -q '"scripts"' package.json; then
            # Добавляем или заменяем start
            sed -i '/"scripts": {/,/}/ s/"start": "[^"]*"/"start": "next start -p 3001"/' package.json || \
            sed -i '/"scripts": {/a\    "start": "next start -p 3001",' package.json
        fi
    fi
    
    echo -e "${GREEN}✅ package.json обновлен${NC}"
fi

# Проверяем результат
echo "Текущий start скрипт:"
grep '"start"' package.json
echo ""

# 4. Обновление systemd сервиса
echo -e "${YELLOW}[4/5] Обновление systemd сервиса...${NC}"
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

systemctl daemon-reload
echo -e "${GREEN}✅ Сервис обновлен${NC}"
echo ""

# 5. Запуск
echo -e "${YELLOW}[5/5] Запуск Next.js...${NC}"
systemctl enable nextjs
systemctl start nextjs

sleep 5

# Проверка
if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен${NC}"
    sleep 2
    if curl -s http://127.0.0.1:3001 > /dev/null; then
        echo -e "${GREEN}✅ Next.js отвечает на порту 3001${NC}"
    else
        echo -e "${YELLOW}⚠️ Next.js запущен, но не отвечает. Проверьте логи:${NC}"
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
echo "Проверьте:"
echo "  systemctl status nextjs"
echo "  curl http://127.0.0.1:3001"
echo ""


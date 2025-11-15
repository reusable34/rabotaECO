#!/bin/bash
# ==========================================
# ПОИСК СВОБОДНЫХ ПОРТОВ И НАСТРОЙКА
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔍 ПОИСК СВОБОДНЫХ ПОРТОВ И НАСТРОЙКА"
echo "==========================================${NC}"
echo ""

# Функция для поиска свободного порта
find_free_port() {
    local start_port=$1
    local port=$start_port
    while lsof -ti:$port > /dev/null 2>&1; do
        port=$((port + 1))
        if [ $port -gt 65535 ]; then
            echo "ERROR"
            return 1
        fi
    done
    echo $port
}

# 1. Поиск свободных портов
echo -e "${YELLOW}[1/6] Поиск свободных портов...${NC}"

# Проверяем текущие порты
echo "Проверка порта 8080 (Backend)..."
if lsof -ti:8080 > /dev/null 2>&1; then
    BACKEND_PORT=$(find_free_port 8080)
    echo -e "${YELLOW}⚠️ Порт 8080 занят, используем $BACKEND_PORT${NC}"
else
    BACKEND_PORT=8080
    echo -e "${GREEN}✅ Порт 8080 свободен${NC}"
fi

echo "Проверка порта 3001 (Frontend)..."
if lsof -ti:3001 > /dev/null 2>&1; then
    FRONTEND_PORT=$(find_free_port 3001)
    echo -e "${YELLOW}⚠️ Порт 3001 занят, используем $FRONTEND_PORT${NC}"
else
    FRONTEND_PORT=3001
    echo -e "${GREEN}✅ Порт 3001 свободен${NC}"
fi

echo ""
echo -e "${GREEN}Найденные порты:${NC}"
echo "  Backend:  $BACKEND_PORT"
echo "  Frontend: $FRONTEND_PORT"
echo ""

# 2. Остановка старых процессов
echo -e "${YELLOW}[2/6] Остановка старых процессов...${NC}"
systemctl stop nextjs 2>/dev/null || true
pkill -f "next start" 2>/dev/null || true
pkill -f "node.*next" 2>/dev/null || true
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
lsof -ti:3001 | xargs kill -9 2>/dev/null || true
lsof -ti:8080 | xargs kill -9 2>/dev/null || true
sleep 2
echo -e "${GREEN}✅ Процессы остановлены${NC}"
echo ""

# 3. Настройка Backend (если порт изменился)
if [ "$BACKEND_PORT" != "8080" ]; then
    echo -e "${YELLOW}[3/6] Настройка Backend на порт $BACKEND_PORT...${NC}"
    # Обновляем Nginx конфигурацию для backend
    if [ -f "/etc/nginx/sites-available/eco-backend" ]; then
        sed -i "s/listen 8080/listen $BACKEND_PORT/g" /etc/nginx/sites-available/eco-backend
        systemctl reload nginx
    fi
    echo -e "${GREEN}✅ Backend настроен на порт $BACKEND_PORT${NC}"
else
    echo -e "${YELLOW}[3/6] Backend уже на порту 8080${NC}"
fi
echo ""

# 4. Настройка Frontend
echo -e "${YELLOW}[4/6] Настройка Frontend на порт $FRONTEND_PORT...${NC}"
cd /opt/eco-project/frontend

# Обновляем package.json
if [ ! -f "package.json.backup" ]; then
    cp package.json package.json.backup
fi

# Заменяем start скрипт
sed -i "s/\"start\": \"next start[^\"]*\"/\"start\": \"next start -p $FRONTEND_PORT\"/g" package.json || {
    # Если не нашли, добавляем вручную
    if ! grep -q '"start"' package.json; then
        sed -i '/"scripts": {/a\    "start": "next start -p '"$FRONTEND_PORT"'",' package.json
    fi
}

echo "Текущий start скрипт:"
grep '"start"' package.json
echo -e "${GREEN}✅ Frontend настроен на порт $FRONTEND_PORT${NC}"
echo ""

# 5. Обновление systemd сервиса
echo -e "${YELLOW}[5/6] Обновление systemd сервиса...${NC}"
cat > /etc/systemd/system/nextjs.service << SERVICE_EOF
[Unit]
Description=Next.js Frontend Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/eco-project/frontend
Environment=NODE_ENV=production
Environment=PORT=$FRONTEND_PORT
Environment=NEXT_PUBLIC_API_URL=http://localhost:$BACKEND_PORT
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

# 6. Запуск
echo -e "${YELLOW}[6/6] Запуск сервисов...${NC}"
systemctl enable nextjs
systemctl start nextjs

sleep 5

# Проверка
if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен${NC}"
    sleep 2
    
    # Проверка доступности
    if curl -s http://127.0.0.1:$FRONTEND_PORT > /dev/null; then
        echo -e "${GREEN}✅ Frontend отвечает на порту $FRONTEND_PORT${NC}"
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

# Проверка Backend
if curl -s http://127.0.0.1:$BACKEND_PORT/health > /dev/null; then
    echo -e "${GREEN}✅ Backend отвечает на порту $BACKEND_PORT${NC}"
else
    echo -e "${YELLOW}⚠️ Backend не отвечает на порту $BACKEND_PORT${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}ИСПОЛЬЗУЕМЫЕ ПОРТЫ:${NC}"
echo "  Backend:  $BACKEND_PORT"
echo "  Frontend: $FRONTEND_PORT"
echo ""
echo "Проверьте:"
echo "  curl http://127.0.0.1:$BACKEND_PORT/health"
echo "  curl http://127.0.0.1:$FRONTEND_PORT"
echo ""
echo -e "${YELLOW}Для настройки Nginx Proxy Manager используйте:${NC}"
echo "  Backend:  Forward Port: $BACKEND_PORT"
echo "  Frontend: Forward Port: $FRONTEND_PORT"
echo ""


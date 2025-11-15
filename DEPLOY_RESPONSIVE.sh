#!/bin/bash
# ==========================================
# ДЕПЛОЙ АДАПТИВНЫХ ИЗМЕНЕНИЙ (БЕЗ DOCKER)
# Выполните на сервере для применения изменений
# ==========================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/opt/eco-project"
IP=$(hostname -I | awk '{print $1}')

echo -e "${BLUE}=========================================="
echo "🚀 ДЕПЛОЙ АДАПТИВНЫХ ИЗМЕНЕНИЙ"
echo "==========================================${NC}"
echo ""

cd "$PROJECT_DIR" || { echo -e "${RED}❌ Директория $PROJECT_DIR не найдена!${NC}"; exit 1; }

# 1. Обновление из Git
echo -e "${YELLOW}[1/5] Обновление из Git...${NC}"
if [ -d ".git" ]; then
    git pull origin main || git pull
    echo -e "${GREEN}✓ Код обновлен${NC}"
else
    echo -e "${RED}❌ Git репозиторий не найден!${NC}"
    exit 1
fi
echo ""

# 2. Установка зависимостей фронтенда
echo -e "${YELLOW}[2/5] Установка зависимостей фронтенда...${NC}"
cd frontend || { echo -e "${RED}❌ Директория frontend не найдена!${NC}"; exit 1; }

if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ package.json не найден!${NC}"
    exit 1
fi

npm install --production=false
echo -e "${GREEN}✓ Зависимости установлены${NC}"
echo ""

# 3. Сборка фронтенда
echo -e "${YELLOW}[3/5] Сборка фронтенда...${NC}"
npm run build
echo -e "${GREEN}✓ Frontend собран${NC}"
echo ""

# 4. Перезапуск Next.js через systemd
echo -e "${YELLOW}[4/5] Перезапуск Next.js...${NC}"
cd "$PROJECT_DIR"

# Ищем сервис Next.js
SERVICE_NAME=""
if systemctl list-units --type=service --all | grep -q "nextjs.service"; then
    SERVICE_NAME="nextjs"
elif systemctl list-units --type=service --all | grep -q "eco-frontend.service"; then
    SERVICE_NAME="eco-frontend"
fi

if [ -n "$SERVICE_NAME" ]; then
    echo "Найден сервис: $SERVICE_NAME"
    systemctl restart "$SERVICE_NAME"
    sleep 3
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ Сервис $SERVICE_NAME перезапущен и работает${NC}"
    else
        echo -e "${YELLOW}⚠ Сервис перезапущен, но статус неясен${NC}"
        echo "Проверьте: systemctl status $SERVICE_NAME"
    fi
else
    # Если нет systemd сервиса, пробуем остановить процессы вручную
    echo "Сервис systemd не найден, останавливаем процессы вручную..."
    pkill -f "next start" 2>/dev/null || true
    pkill -f "node.*next" 2>/dev/null || true
    sleep 2
    
    # Пробуем запустить через npm start в фоне
    cd frontend
    export NODE_ENV=production
    nohup npm start > /var/log/nextjs.log 2>&1 &
    echo -e "${YELLOW}⚠ Next.js запущен вручную${NC}"
    echo "Проверьте логи: tail -f /var/log/nextjs.log"
fi
echo ""

# 5. Проверка статуса
echo -e "${YELLOW}[5/5] Проверка статуса...${NC}"
sleep 5

# Проверяем порты
if ss -tuln | grep -q ":3001 "; then
    echo -e "${GREEN}✓ Next.js слушает порт 3001${NC}"
elif ss -tuln | grep -q ":3000 "; then
    echo -e "${GREEN}✓ Next.js слушает порт 3000${NC}"
else
    echo -e "${YELLOW}⚠ Next.js может быть еще запускается...${NC}"
    echo "Проверьте порты: ss -tuln | grep ':300'"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "🎉 ДЕПЛОЙ ЗАВЕРШЕН!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}🌐 Проверьте:${NC}"
echo "  Frontend:  http://${IP}:3001"
echo "  или:       http://${IP}:3384"
echo ""
echo -e "${YELLOW}💡 Откройте сайт на мобильном устройстве${NC}"
echo -e "${YELLOW}   или в DevTools (F12) -> Responsive Design Mode${NC}"
echo ""
echo -e "${BLUE}📋 Полезные команды:${NC}"
echo "  systemctl status nextjs"
echo "  journalctl -u nextjs -f"
echo "  ss -tuln | grep ':300'"
echo ""


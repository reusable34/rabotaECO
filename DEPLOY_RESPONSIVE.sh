#!/bin/bash
# ==========================================
# ДЕПЛОЙ АДАПТИВНЫХ ИЗМЕНЕНИЙ
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
echo -e "${YELLOW}[1/4] Обновление из Git...${NC}"
if [ -d ".git" ]; then
    git pull origin main || git pull
    echo -e "${GREEN}✓ Код обновлен${NC}"
else
    echo -e "${RED}❌ Git репозиторий не найден!${NC}"
    exit 1
fi
echo ""

# 2. Проверка наличия Docker
if command -v docker &> /dev/null && [ -f "docker-compose.yml" ] || [ -f "docker-compose.production.yml" ]; then
    echo -e "${YELLOW}[2/4] Пересборка фронтенда в Docker...${NC}"
    
    COMPOSE_FILE="docker-compose.yml"
    if [ -f "docker-compose.production.yml" ]; then
        COMPOSE_FILE="docker-compose.production.yml"
    fi
    
    # Пересборка только фронтенда
    docker-compose -f "$COMPOSE_FILE" build frontend
    docker-compose -f "$COMPOSE_FILE" up -d frontend
    
    echo -e "${GREEN}✓ Frontend пересобран${NC}"
    echo ""
    
    # 3. Ожидание запуска
    echo -e "${YELLOW}[3/4] Ожидание запуска (30 сек)...${NC}"
    sleep 30
    echo ""
    
    # 4. Проверка
    echo -e "${YELLOW}[4/4] Проверка статуса...${NC}"
    if docker-compose -f "$COMPOSE_FILE" ps | grep -q "frontend.*Up"; then
        echo -e "${GREEN}✓ Frontend запущен${NC}"
    else
        echo -e "${YELLOW}⚠ Frontend может быть еще запускается...${NC}"
    fi
    
else
    # Без Docker - прямая сборка
    echo -e "${YELLOW}[2/4] Установка зависимостей фронтенда...${NC}"
    cd frontend || { echo -e "${RED}❌ Директория frontend не найдена!${NC}"; exit 1; }
    
    if [ -f "package.json" ]; then
        npm install --production=false
        echo -e "${GREEN}✓ Зависимости установлены${NC}"
        echo ""
        
        echo -e "${YELLOW}[3/4] Сборка фронтенда...${NC}"
        npm run build
        echo -e "${GREEN}✓ Frontend собран${NC}"
        echo ""
        
        echo -e "${YELLOW}[4/4] Перезапуск Next.js...${NC}"
        # Проверяем systemd сервис
        if systemctl list-units --type=service | grep -q "nextjs\|eco-frontend"; then
            SERVICE_NAME=$(systemctl list-units --type=service | grep -E "nextjs|eco-frontend" | awk '{print $1}' | head -1)
            systemctl restart "$SERVICE_NAME" 2>/dev/null || true
            echo -e "${GREEN}✓ Сервис перезапущен${NC}"
        else
            # Если нет systemd, пробуем через pm2 или напрямую
            pkill -f "next-server" 2>/dev/null || true
            sleep 2
            echo -e "${YELLOW}⚠ Запустите Next.js вручную: npm start${NC}"
        fi
    else
        echo -e "${RED}❌ package.json не найден!${NC}"
        exit 1
    fi
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


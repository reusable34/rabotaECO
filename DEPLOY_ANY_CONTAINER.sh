я#!/bin/bash
# ==========================================
# ДЕПЛОЙ В ЛЮБОЙ КОНТЕЙНЕР - ВЫПОЛНИТЬ НА СЕРВЕРЕ
# ==========================================
# Скопируйте и выполните эту команду в контейнере:
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
echo "АВТОМАТИЧЕСКИЙ ДЕПЛОЙ ПРОЕКТА ECO"
echo "==========================================${NC}"
echo ""

# Проверка что мы root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Ошибка: Запустите от root${NC}"
    exit 1
fi

# 1. Установка Docker
echo -e "${YELLOW}[1/7] Установка Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
    echo -e "${GREEN}✓ Docker установлен${NC}"
else
    echo -e "${GREEN}✓ Docker: $(docker --version)${NC}"
fi

# 2. Установка Docker Compose
echo -e "${YELLOW}[2/7] Установка Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    apt-get update -qq
    apt-get install -y docker-compose-plugin 2>/dev/null || apt-get install -y docker-compose
    echo -e "${GREEN}✓ Docker Compose установлен${NC}"
else
    echo -e "${GREEN}✓ Docker Compose установлен${NC}"
fi

# 3. Создание директории проекта
echo -e "${YELLOW}[3/7] Подготовка проекта...${NC}"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Проверка наличия проекта
if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.production.yml" ]; then
    echo -e "${RED}Проект не найден!${NC}"
    echo ""
    echo "Загрузите проект в $PROJECT_DIR"
    echo "Или выполните на вашем Mac:"
    echo "  scp -r /Users/komp/Documents/PROGRAMIROVANIE/rabotaECO root@<IP>:${PROJECT_DIR}"
    echo ""
    exit 1
fi

# 4. Настройка переменных
echo -e "${YELLOW}[4/7] Настройка переменных...${NC}"
mkdir -p frontend
cat > frontend/.env.local << EOF
NEXT_PUBLIC_API_URL=http://${IP}:8080
NEXT_PUBLIC_ENV=production
EOF

# 5. Выбор конфигурации
COMPOSE_FILE="docker-compose.yml"
if [ -f "docker-compose.production.yml" ]; then
    COMPOSE_FILE="docker-compose.production.yml"
fi

# 6. Запуск
echo -e "${YELLOW}[5/7] Запуск контейнеров...${NC}"
docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
docker-compose -f "$COMPOSE_FILE" up -d --build

# 7. Ожидание
echo -e "${YELLOW}[6/7] Ожидание запуска (60 сек)...${NC}"
sleep 60

# 8. Миграции
echo -e "${YELLOW}[7/7] Миграции и данные...${NC}"
for i in {1..30}; do
    docker-compose -f "$COMPOSE_FILE" exec -T db pg_isready -U eco_admin &>/dev/null && break || sleep 2
done

docker-compose -f "$COMPOSE_FILE" exec -T backend php yii migrate --interactive=0 2>/dev/null || true
docker-compose -f "$COMPOSE_FILE" exec -T backend php yii seed 2>/dev/null || true

# Итог
echo ""
echo -e "${GREEN}=========================================="
echo "🎉 ДЕПЛОЙ ЗАВЕРШЕН!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}🌐 Доступ:${NC}"
echo "  Frontend:  http://${IP}:3001"
echo "  Backend:   http://${IP}:8080"
echo "  Adminer:   http://${IP}:8082"
echo ""


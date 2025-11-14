#!/bin/bash
set -e

echo "=========================================="
echo "ДЕПЛОЙ ПРОЕКТА ECO"
echo "=========================================="

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка, что мы root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Ошибка: Запустите скрипт от root${NC}"
    exit 1
fi

PROJECT_DIR="/opt/eco-project"
IP=$(hostname -I | awk '{print $1}')

echo ""
echo "1. ПРОВЕРКА СИСТЕМЫ..."
echo "----------------------------------------"

# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker не установлен. Устанавливаю...${NC}"
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
    echo -e "${GREEN}Docker установлен${NC}"
else
    echo -e "${GREEN}Docker уже установлен: $(docker --version)${NC}"
fi

# Проверка Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Docker Compose не установлен. Устанавливаю...${NC}"
    apt-get update
    apt-get install -y docker-compose-plugin || apt-get install -y docker-compose
    echo -e "${GREEN}Docker Compose установлен${NC}"
else
    echo -e "${GREEN}Docker Compose уже установлен${NC}"
fi

echo ""
echo "2. ПРОВЕРКА ПРОЕКТА..."
echo "----------------------------------------"

if [ ! -f "$PROJECT_DIR/docker-compose.yml" ] && [ ! -f "$PROJECT_DIR/docker-compose.production.yml" ]; then
    echo -e "${RED}Проект не найден в $PROJECT_DIR${NC}"
    echo "Создаю директорию..."
    mkdir -p "$PROJECT_DIR"
    echo -e "${YELLOW}Загрузите проект в $PROJECT_DIR${NC}"
    echo "Или выполните: git clone <repo> $PROJECT_DIR"
    exit 1
fi

cd "$PROJECT_DIR"

# Используем production конфиг если есть
if [ -f "docker-compose.production.yml" ]; then
    COMPOSE_FILE="docker-compose.production.yml"
    echo -e "${GREEN}Используется production конфигурация${NC}"
else
    COMPOSE_FILE="docker-compose.yml"
    echo -e "${YELLOW}Используется стандартная конфигурация${NC}"
fi

echo ""
echo "3. НАСТРОЙКА ПЕРЕМЕННЫХ ОКРУЖЕНИЯ..."
echo "----------------------------------------"

# Создаем frontend/.env.local
mkdir -p frontend
cat > frontend/.env.local << EOF
NEXT_PUBLIC_API_URL=http://${IP}:8080
NEXT_PUBLIC_ENV=production
EOF
echo -e "${GREEN}Создан frontend/.env.local${NC}"

echo ""
echo "4. ЗАПУСК КОНТЕЙНЕРОВ..."
echo "----------------------------------------"

# Останавливаем старые контейнеры если есть
docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true

# Запускаем
echo "Запускаю контейнеры..."
docker-compose -f "$COMPOSE_FILE" up -d

echo "Ожидание запуска сервисов (30 секунд)..."
sleep 30

echo ""
echo "5. ВЫПОЛНЕНИЕ МИГРАЦИЙ..."
echo "----------------------------------------"

# Ждем пока БД будет готова
echo "Ожидание готовности БД..."
for i in {1..30}; do
    if docker-compose -f "$COMPOSE_FILE" exec -T db pg_isready -U eco_admin &>/dev/null; then
        echo -e "${GREEN}БД готова${NC}"
        break
    fi
    echo "Попытка $i/30..."
    sleep 2
done

# Выполняем миграции
echo "Выполняю миграции..."
docker-compose -f "$COMPOSE_FILE" exec -T backend php yii migrate --interactive=0 || {
    echo -e "${YELLOW}Миграции уже выполнены или ошибка${NC}"
}

echo ""
echo "6. ЗАГРУЗКА ТЕСТОВЫХ ДАННЫХ..."
echo "----------------------------------------"

docker-compose -f "$COMPOSE_FILE" exec -T backend php yii seed || {
    echo -e "${YELLOW}Сиды уже выполнены или ошибка${NC}"
}

echo ""
echo "=========================================="
echo -e "${GREEN}ДЕПЛОЙ ЗАВЕРШЕН!${NC}"
echo "=========================================="
echo ""
echo "Доступ к сервисам:"
echo "  Frontend:  http://${IP}:3001"
echo "  Backend:   http://${IP}:8080"
echo "  Adminer:   http://${IP}:8082"
echo ""
echo "Проверка статуса:"
echo "  docker-compose -f $COMPOSE_FILE ps"
echo ""
echo "Логи:"
echo "  docker-compose -f $COMPOSE_FILE logs -f"
echo ""


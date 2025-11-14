#!/bin/bash
# Автоматический деплой проекта - выполнить одной командой на сервере
# curl -sSL https://raw.githubusercontent.com/your-repo/rabotaECO/main/deploy.sh | bash
# ИЛИ загрузить файл и выполнить: bash deploy.sh

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

# 1. Установка Docker
echo -e "${YELLOW}[1/7] Проверка Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo "Установка Docker..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
    echo -e "${GREEN}✓ Docker установлен${NC}"
else
    echo -e "${GREEN}✓ Docker уже установлен${NC}"
fi

# 2. Установка Docker Compose
echo -e "${YELLOW}[2/7] Проверка Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "Установка Docker Compose..."
    apt-get update -qq
    apt-get install -y docker-compose-plugin 2>/dev/null || apt-get install -y docker-compose
    echo -e "${GREEN}✓ Docker Compose установлен${NC}"
else
    echo -e "${GREEN}✓ Docker Compose уже установлен${NC}"
fi

# 3. Создание директории проекта
echo -e "${YELLOW}[3/7] Подготовка директории проекта...${NC}"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 4. Проверка наличия проекта
if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.production.yml" ]; then
    echo -e "${RED}Ошибка: Проект не найден в $PROJECT_DIR${NC}"
    echo ""
    echo "Загрузите проект одним из способов:"
    echo "  1. Через SCP с вашего компьютера:"
    echo "     scp -r /path/to/rabotaECO root@${IP}:${PROJECT_DIR}"
    echo ""
    echo "  2. Через Git (если есть репозиторий):"
    echo "     git clone <your-repo> $PROJECT_DIR"
    echo ""
    echo "  3. Через веб-интерфейс Proxmox (загрузка файлов)"
    echo ""
    exit 1
fi

# 5. Настройка переменных окружения
echo -e "${YELLOW}[4/7] Настройка переменных окружения...${NC}"
mkdir -p frontend
cat > frontend/.env.local << EOF
NEXT_PUBLIC_API_URL=http://${IP}:8080
NEXT_PUBLIC_ENV=production
EOF
echo -e "${GREEN}✓ Настроено${NC}"

# 6. Выбор конфигурации
COMPOSE_FILE="docker-compose.yml"
if [ -f "docker-compose.production.yml" ]; then
    COMPOSE_FILE="docker-compose.production.yml"
    echo -e "${GREEN}✓ Используется production конфигурация${NC}"
fi

# 7. Остановка старых контейнеров
echo -e "${YELLOW}[5/7] Остановка старых контейнеров...${NC}"
docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true

# 8. Запуск контейнеров
echo -e "${YELLOW}[6/7] Запуск контейнеров...${NC}"
docker-compose -f "$COMPOSE_FILE" up -d --build

# 9. Ожидание запуска
echo "Ожидание запуска сервисов (60 секунд)..."
sleep 60

# 10. Выполнение миграций
echo -e "${YELLOW}[7/7] Выполнение миграций и загрузка данных...${NC}"

# Ждем готовности БД
echo "Ожидание готовности БД..."
for i in {1..30}; do
    if docker-compose -f "$COMPOSE_FILE" exec -T db pg_isready -U eco_admin &>/dev/null 2>&1; then
        echo -e "${GREEN}✓ БД готова${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${YELLOW}⚠ БД не отвечает, продолжаю...${NC}"
    fi
    sleep 2
done

# Миграции
echo "Выполнение миграций..."
docker-compose -f "$COMPOSE_FILE" exec -T backend php yii migrate --interactive=0 2>/dev/null || {
    echo -e "${YELLOW}⚠ Миграции уже выполнены или ошибка${NC}"
}

# Тестовые данные
echo "Загрузка тестовых данных..."
docker-compose -f "$COMPOSE_FILE" exec -T backend php yii seed 2>/dev/null || {
    echo -e "${YELLOW}⚠ Данные уже загружены или ошибка${NC}"
}

# Итог
echo ""
echo -e "${GREEN}=========================================="
echo "ДЕПЛОЙ ЗАВЕРШЕН УСПЕШНО!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}Доступ к сервисам:${NC}"
echo "  🌐 Frontend:  http://${IP}:3001"
echo "  🔧 Backend:   http://${IP}:8080"
echo "  💾 Adminer:   http://${IP}:8082"
echo ""
echo -e "${YELLOW}Полезные команды:${NC}"
echo "  Статус:      docker-compose -f $COMPOSE_FILE ps"
echo "  Логи:        docker-compose -f $COMPOSE_FILE logs -f"
echo "  Перезапуск:  docker-compose -f $COMPOSE_FILE restart"
echo "  Остановка:   docker-compose -f $COMPOSE_FILE down"
echo ""
echo -e "${GREEN}Готово!${NC}"


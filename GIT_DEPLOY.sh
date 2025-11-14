#!/bin/bash
# ==========================================
# ДЕПЛОЙ ЧЕРЕЗ GIT - ВЫПОЛНИТЬ НА СЕРВЕРЕ
# ==========================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/opt/eco-project"
GIT_REPO="${1:-}"  # URL репозитория как аргумент
IP=$(hostname -I | awk '{print $1}')

echo -e "${BLUE}=========================================="
echo "🚀 ДЕПЛОЙ ЧЕРЕЗ GIT"
echo "==========================================${NC}"
echo ""

# 1. Установка Git если нет
echo -e "${YELLOW}[0/6] Установка Git...${NC}"
if ! command -v git &> /dev/null; then
    apt-get update -qq
    apt-get install -y git
    echo -e "${GREEN}✓ Git установлен${NC}"
else
    echo -e "${GREEN}✓ Git: $(git --version)${NC}"
fi

# 2. Установка curl если нет
if ! command -v curl &> /dev/null; then
    echo -e "${YELLOW}Установка curl...${NC}"
    apt-get update -qq
    apt-get install -y curl
fi

# 3. Установка Docker
echo -e "${YELLOW}[1/6] Установка Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
    echo -e "${GREEN}✓ Docker установлен${NC}"
else
    echo -e "${GREEN}✓ Docker: $(docker --version)${NC}"
fi

# 4. Установка Docker Compose
echo -e "${YELLOW}[2/6] Установка Docker Compose...${NC}"
if ! docker compose version &>/dev/null && ! command -v docker-compose &>/dev/null; then
    apt-get update -qq
    apt-get install -y docker-compose-plugin 2>/dev/null || apt-get install -y docker-compose
    echo -e "${GREEN}✓ Docker Compose установлен${NC}"
else
    if docker compose version &>/dev/null; then
        echo -e "${GREEN}✓ Docker Compose (плагин): $(docker compose version)${NC}"
    else
        echo -e "${GREEN}✓ Docker Compose: $(docker-compose --version)${NC}"
    fi
fi

# 5. Клонирование/обновление проекта
echo -e "${YELLOW}[3/6] Получение проекта из Git...${NC}"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

if [ -d ".git" ]; then
    echo "Обновление существующего репозитория..."
    git pull
    echo -e "${GREEN}✓ Проект обновлен${NC}"
elif [ -n "$GIT_REPO" ]; then
    echo "Клонирование из $GIT_REPO..."
    git clone "$GIT_REPO" .
    echo -e "${GREEN}✓ Проект клонирован${NC}"
else
    echo -e "${RED}Ошибка: Git репозиторий не найден и URL не указан${NC}"
    echo ""
    echo "Использование:"
    echo "  bash GIT_DEPLOY.sh <git-repo-url>"
    echo ""
    echo "Или если репозиторий уже в $PROJECT_DIR:"
    echo "  cd $PROJECT_DIR && bash GIT_DEPLOY.sh"
    exit 1
fi

# 6. Настройка переменных
echo -e "${YELLOW}[4/6] Настройка переменных...${NC}"
mkdir -p frontend
cat > frontend/.env.local << EOF
NEXT_PUBLIC_API_URL=http://${IP}:8080
NEXT_PUBLIC_ENV=production
EOF

# 7. Определение команды docker compose
if docker compose version &>/dev/null; then
    DOCKER_COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE="docker-compose"
else
    echo -e "${RED}Ошибка: Docker Compose не найден${NC}"
    exit 1
fi

# 8. Выбор конфигурации
COMPOSE_FILE="docker-compose.yml"
if [ -f "docker-compose.production.yml" ]; then
    COMPOSE_FILE="docker-compose.production.yml"
fi

# 9. Настройка для LXC контейнера
echo -e "${YELLOW}Проверка окружения...${NC}"
# Если в LXC контейнере, настраиваем Docker
if [ -f /.dockerenv ] || grep -q "container=lxc" /proc/1/environ 2>/dev/null || [ -d /sys/fs/cgroup/systemd ]; then
    echo "Обнаружен LXC контейнер, настраиваю Docker..."
    # Настраиваем Docker для работы в LXC
    mkdir -p /etc/docker
    if [ ! -f /etc/docker/daemon.json ]; then
        cat > /etc/docker/daemon.json << 'DOCKER_EOF'
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
DOCKER_EOF
        systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true
        sleep 3
    fi
    # Настраиваем sysctl на уровне хоста (если возможно)
    echo 0 > /proc/sys/net/ipv4/ip_unprivileged_port_start 2>/dev/null || true
fi

# 10. Запуск
echo -e "${YELLOW}[5/6] Запуск контейнеров...${NC}"
$DOCKER_COMPOSE -f "$COMPOSE_FILE" down 2>/dev/null || true
$DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d --build

# 11. Ожидание
echo -e "${YELLOW}[6/6] Ожидание запуска (60 сек)...${NC}"
sleep 60

# 12. Миграции
echo "Выполнение миграций..."
for i in {1..30}; do
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T db pg_isready -U eco_admin &>/dev/null 2>&1 && break || sleep 2
done

$DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T backend php yii migrate --interactive=0 2>/dev/null || true
$DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T backend php yii seed 2>/dev/null || true

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


#!/bin/bash
# ==========================================
# ПРОВЕРКА И ИСПРАВЛЕНИЕ DOCKER В КОНТЕЙНЕРЕ 102
# ==========================================
# Выполните ВНУТРИ контейнера 102 (kolas)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔍 ПРОВЕРКА DOCKER В КОНТЕЙНЕРЕ 102"
echo "==========================================${NC}"
echo ""

# 1. Проверка Docker
echo -e "${YELLOW}[1/5] Проверка Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker не установлен!${NC}"
    echo "Установите Docker: bash GIT_DEPLOY.sh"
    exit 1
fi

if ! systemctl is-active --quiet docker 2>/dev/null && ! service docker status &>/dev/null; then
    echo -e "${YELLOW}⚠️ Docker не запущен, запускаю...${NC}"
    systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
    sleep 3
fi

docker --version
echo -e "${GREEN}✅ Docker работает${NC}"
echo ""

# 2. Проверка проекта
echo -e "${YELLOW}[2/5] Проверка проекта...${NC}"
if [ ! -d "/opt/eco-project" ]; then
    echo -e "${RED}❌ Проект не найден!${NC}"
    echo "Клонируйте проект: git clone https://github.com/reusable34/rabotaECO.git /opt/eco-project"
    exit 1
fi

cd /opt/eco-project
echo -e "${GREEN}✅ Проект найден${NC}"
echo ""

# 3. Обновление проекта
echo -e "${YELLOW}[3/5] Обновление проекта...${NC}"
git pull || echo -e "${YELLOW}⚠️ Не удалось обновить (возможно, нет интернета)${NC}"
echo ""

# 4. Проверка конфигурации Docker
echo -e "${YELLOW}[4/5] Проверка Docker daemon...${NC}"
if [ ! -f "/etc/docker/daemon.json" ]; then
    echo -e "${YELLOW}⚠️ Docker daemon.json не найден, создаю...${NC}"
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "iptables": false,
  "ip-forward": false,
  "userland-proxy": false
}
EOF
    systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true
    sleep 3
    echo -e "${GREEN}✅ Docker daemon настроен${NC}"
else
    echo -e "${GREEN}✅ Docker daemon настроен${NC}"
fi
echo ""

# 5. Запуск контейнеров
echo -e "${YELLOW}[5/5] Запуск Docker контейнеров...${NC}"

# Проверяем, какой docker-compose доступен
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo -e "${RED}❌ docker-compose не найден!${NC}"
    exit 1
fi

echo "Используется: $COMPOSE_CMD"

# Останавливаем старые контейнеры
$COMPOSE_CMD -f docker-compose.production.yml down 2>/dev/null || true

# Запускаем новые
echo "Запуск контейнеров..."
$COMPOSE_CMD -f docker-compose.production.yml up -d

# Ждем немного
sleep 5

# Проверка статуса
echo ""
echo -e "${YELLOW}Статус контейнеров:${NC}"
$COMPOSE_CMD -f docker-compose.production.yml ps

echo ""
echo -e "${YELLOW}Логи последних 20 строк:${NC}"
$COMPOSE_CMD -f docker-compose.production.yml logs --tail=20

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ПРОВЕРКА ЗАВЕРШЕНА"
echo "==========================================${NC}"
echo ""
echo "Проверьте доступность:"
echo "  Backend:  curl http://127.0.0.1:8080/health"
echo "  Frontend: curl http://127.0.0.1:3001"
echo ""
echo "IP контейнера 102: 192.168.0.32"
echo "Настройте Nginx Proxy Manager:"
echo "  http://85.113.129.96:81/nginx/proxy"
echo ""


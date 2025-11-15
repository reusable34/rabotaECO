#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ GIT И ДЕПЛОЙ
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ GIT И ДЕПЛОЙ"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project

# 1. Сохраняем локальные изменения
echo -e "${YELLOW}[1/4] Сохранение локальных изменений...${NC}"
git stash || echo -e "${YELLOW}⚠️ Нет изменений для сохранения${NC}"
echo ""

# 2. Обновляем проект
echo -e "${YELLOW}[2/4] Обновление проекта из Git...${NC}"
git pull
echo -e "${GREEN}✅ Проект обновлен${NC}"
echo ""

# 3. Проверка Docker
echo -e "${YELLOW}[3/4] Проверка Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker не установлен!${NC}"
    echo "Запустите: bash GIT_DEPLOY.sh"
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

# 4. Настройка Docker daemon (если нужно)
if [ ! -f "/etc/docker/daemon.json" ]; then
    echo -e "${YELLOW}Настройка Docker daemon...${NC}"
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
fi

# 5. Запуск контейнеров
echo -e "${YELLOW}[4/4] Запуск Docker контейнеров...${NC}"

# Определяем команду docker-compose
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
echo "Остановка старых контейнеров..."
$COMPOSE_CMD -f docker-compose.production.yml down 2>/dev/null || true

# Запускаем новые
echo "Запуск контейнеров..."
$COMPOSE_CMD -f docker-compose.production.yml up -d

# Ждем
sleep 5

# Проверка статуса
echo ""
echo -e "${YELLOW}Статус контейнеров:${NC}"
$COMPOSE_CMD -f docker-compose.production.yml ps

echo ""
echo -e "${YELLOW}Последние логи:${NC}"
$COMPOSE_CMD -f docker-compose.production.yml logs --tail=10

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Проверьте:"
echo "  Backend:  curl http://127.0.0.1:8080/health"
echo "  Frontend: curl http://127.0.0.1:3001"
echo ""
echo "IP контейнера: 192.168.0.32"
echo "Настройте Nginx Proxy Manager:"
echo "  http://85.113.129.96:81/nginx/proxy"
echo ""


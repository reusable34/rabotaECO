#!/bin/bash
# ==========================================
# ПОЛНАЯ ОЧИСТКА И ПЕРЕЗАПУСК DOCKER
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🧹 ПОЛНАЯ ОЧИСТКА И ПЕРЕЗАПУСК DOCKER"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project

# 1. Остановка всех контейнеров
echo -e "${YELLOW}[1/6] Остановка всех контейнеров...${NC}"
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo -e "${RED}❌ docker-compose не найден!${NC}"
    exit 1
fi

$COMPOSE_CMD -f docker-compose.production.yml down 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
echo -e "${GREEN}✅ Контейнеры остановлены${NC}"
echo ""

# 2. Очистка системы
echo -e "${YELLOW}[2/6] Очистка Docker системы...${NC}"
docker system prune -f
echo -e "${GREEN}✅ Система очищена${NC}"
echo ""

# 3. Проверка и настройка Docker daemon
echo -e "${YELLOW}[3/6] Настройка Docker daemon...${NC}"
mkdir -p /etc/docker

# Создаем daemon.json БЕЗ sysctl
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
  "userland-proxy": false,
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ]
}
EOF

echo -e "${GREEN}✅ Docker daemon настроен${NC}"
echo ""

# 4. Перезапуск Docker
echo -e "${YELLOW}[4/6] Перезапуск Docker...${NC}"
systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true
sleep 5

# Проверка Docker
if ! docker info &>/dev/null; then
    echo -e "${RED}❌ Docker не запустился!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker перезапущен${NC}"
echo ""

# 5. Проверка docker-compose файла
echo -e "${YELLOW}[5/6] Проверка docker-compose.production.yml...${NC}"
if grep -q "sysctl" docker-compose.production.yml 2>/dev/null; then
    echo -e "${YELLOW}⚠️ Найдены sysctl в docker-compose.production.yml, удаляю...${NC}"
    cp docker-compose.production.yml docker-compose.production.yml.backup
    sed -i '/sysctls:/d' docker-compose.production.yml
    sed -i '/net.ipv4.ip_unprivileged_port_start/d' docker-compose.production.yml
    echo -e "${GREEN}✅ sysctl удалены${NC}"
else
    echo -e "${GREEN}✅ sysctl не найдены в файле${NC}"
fi
echo ""

# 6. Запуск контейнеров
echo -e "${YELLOW}[6/6] Запуск контейнеров...${NC}"
$COMPOSE_CMD -f docker-compose.production.yml up -d

# Ждем
sleep 10

# Проверка статуса
echo ""
echo -e "${YELLOW}Статус контейнеров:${NC}"
$COMPOSE_CMD -f docker-compose.production.yml ps

echo ""
echo -e "${YELLOW}Последние логи (первые ошибки, если есть):${NC}"
$COMPOSE_CMD -f docker-compose.production.yml logs --tail=30 2>&1 | grep -i error || echo "Ошибок не найдено"

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Проверьте:"
echo "  docker ps"
echo "  curl http://127.0.0.1:8080/health"
echo "  curl http://127.0.0.1:3001"
echo ""


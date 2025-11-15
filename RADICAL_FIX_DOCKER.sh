#!/bin/bash
# ==========================================
# РАДИКАЛЬНОЕ ИСПРАВЛЕНИЕ DOCKER В LXC
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 РАДИКАЛЬНОЕ ИСПРАВЛЕНИЕ DOCKER В LXC"
echo "==========================================${NC}"
echo ""

# 1. Остановка всех Docker процессов
echo -e "${YELLOW}[1/7] Остановка всех Docker процессов...${NC}"
cd /opt/eco-project

# Определяем команду docker-compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker compose"
fi

# Останавливаем контейнеры
$COMPOSE_CMD -f docker-compose.production.yml down 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# Убиваем процессы
pkill -f docker || true
sleep 2
echo -e "${GREEN}✅ Процессы остановлены${NC}"
echo ""

# 2. Остановка Docker сервиса
echo -e "${YELLOW}[2/7] Остановка Docker сервиса...${NC}"
systemctl stop docker 2>/dev/null || service docker stop 2>/dev/null || true
sleep 2
echo -e "${GREEN}✅ Docker остановлен${NC}"
echo ""

# 3. Очистка Docker данных (осторожно!)
echo -e "${YELLOW}[3/7] Очистка Docker данных...${NC}"
# Удаляем только контейнеры и сети, НЕ volumes (чтобы не потерять данные БД)
rm -rf /var/lib/docker/containers/* 2>/dev/null || true
rm -rf /var/lib/docker/network/* 2>/dev/null || true
# Очищаем overlay2 только если он есть проблемы
if [ -d "/var/lib/docker/overlay2" ]; then
    echo "Очистка overlay2 (это может занять время)..."
    find /var/lib/docker/overlay2 -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
fi
echo -e "${GREEN}✅ Данные очищены${NC}"
echo ""

# 4. Создание простой конфигурации Docker с VFS
echo -e "${YELLOW}[4/7] Создание простой конфигурации Docker (VFS storage)...${NC}"
mkdir -p /etc/docker

cat > /etc/docker/daemon.json << 'DOCKEREOF'
{
  "storage-driver": "vfs",
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
DOCKEREOF

echo -e "${GREEN}✅ Конфигурация создана (VFS storage driver)${NC}"
echo ""

# 5. Запуск Docker
echo -e "${YELLOW}[5/7] Запуск Docker...${NC}"
systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
sleep 5

# Проверка
if docker info &>/dev/null; then
    echo -e "${GREEN}✅ Docker запущен${NC}"
    docker info | head -5
else
    echo -e "${RED}❌ Docker не запускается${NC}"
    echo ""
    echo -e "${YELLOW}Попробуйте настроить контейнер на хосте Proxmox:${NC}"
    echo "  pct set 102 -features nesting=1,keyctl=1,fuse=1"
    echo "  pct reboot 102"
    exit 1
fi
echo ""

# 6. Очистка docker-compose файла от sysctl
echo -e "${YELLOW}[6/7] Очистка docker-compose.production.yml от sysctl...${NC}"
if [ -f "docker-compose.production.yml" ]; then
    cp docker-compose.production.yml docker-compose.production.yml.backup
    grep -v "sysctls:\|net.ipv4.ip_unprivileged_port_start\|ip_unprivileged_port_start" docker-compose.production.yml > docker-compose.production.yml.fixed
    mv docker-compose.production.yml.fixed docker-compose.production.yml
    echo -e "${GREEN}✅ Файл очищен${NC}"
else
    echo -e "${YELLOW}⚠️ docker-compose.production.yml не найден${NC}"
fi
echo ""

# 7. Попытка запуска контейнеров
echo -e "${YELLOW}[7/7] Попытка запуска контейнеров...${NC}"
$COMPOSE_CMD -f docker-compose.production.yml up -d

# Ждем
sleep 10

# Проверка статуса
echo ""
echo -e "${YELLOW}Статус контейнеров:${NC}"
$COMPOSE_CMD -f docker-compose.production.yml ps

echo ""
echo -e "${YELLOW}Последние логи (первые 20 строк):${NC}"
$COMPOSE_CMD -f docker-compose.production.yml logs --tail=20 2>&1 | head -20

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
echo -e "${YELLOW}Примечание: VFS storage driver медленнее overlay2,${NC}"
echo -e "${YELLOW}но работает в LXC без дополнительных настроек.${NC}"
echo ""


#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ STORAGE DRIVER ДЛЯ LXC
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ STORAGE DRIVER"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project

# 1. Остановка Docker
echo -e "${YELLOW}[1/5] Остановка Docker...${NC}"
systemctl stop docker 2>/dev/null || service docker stop 2>/dev/null || true
sleep 2

# 2. Попытка установить fuse-overlayfs
echo -e "${YELLOW}[2/5] Попытка установить fuse-overlayfs...${NC}"
if command -v apt-get &> /dev/null; then
    apt-get update -qq 2>/dev/null || true
    apt-get install -y fuse-overlayfs 2>/dev/null || {
        echo -e "${YELLOW}⚠️ fuse-overlayfs не установлен, используем overlay2${NC}"
    }
else
    echo -e "${YELLOW}⚠️ apt-get не найден, используем overlay2${NC}"
fi
echo ""

# 3. Настройка Docker daemon
echo -e "${YELLOW}[3/5] Настройка Docker daemon...${NC}"
mkdir -p /etc/docker

# Пробуем fuse-overlayfs, если установлен, иначе overlay2
if command -v fuse-overlayfs &> /dev/null; then
    STORAGE_DRIVER="fuse-overlayfs"
    echo "Используем fuse-overlayfs (работает в LXC)"
else
    STORAGE_DRIVER="overlay2"
    echo "Используем overlay2 (может потребовать настройки хоста)"
fi

cat > /etc/docker/daemon.json << EOF
{
  "storage-driver": "${STORAGE_DRIVER}",
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

echo -e "${GREEN}✅ Конфигурация создана (${STORAGE_DRIVER})${NC}"
echo ""

# 4. Очистка старых данных (только если нужно)
echo -e "${YELLOW}[4/5] Очистка старых данных...${NC}"
if [ -d "/var/lib/docker" ]; then
    # Удаляем только проблемные директории, НЕ volumes
    rm -rf /var/lib/docker/vfs 2>/dev/null || true
    rm -rf /var/lib/docker/containers/* 2>/dev/null || true
    rm -rf /var/lib/docker/network/* 2>/dev/null || true
    echo -e "${GREEN}✅ Данные очищены${NC}"
else
    echo -e "${GREEN}✅ Данных для очистки нет${NC}"
fi
echo ""

# 5. Запуск Docker
echo -e "${YELLOW}[5/5] Запуск Docker...${NC}"
systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
sleep 5

# Проверка
if docker info &>/dev/null; then
    echo -e "${GREEN}✅ Docker запущен${NC}"
    echo ""
    echo "Storage Driver:"
    docker info | grep "Storage Driver" || echo "Не удалось определить"
else
    echo -e "${RED}❌ Docker не запускается${NC}"
    echo ""
    echo -e "${YELLOW}Попробуйте настроить контейнер на хосте Proxmox:${NC}"
    echo "  pct set 102 -features nesting=1,keyctl=1,fuse=1"
    echo "  pct reboot 102"
    exit 1
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Теперь попробуйте запустить контейнеры:"
echo "  cd /opt/eco-project"
echo "  docker compose -f docker-compose.production.yml up -d"
echo ""


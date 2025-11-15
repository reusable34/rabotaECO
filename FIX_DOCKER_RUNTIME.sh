#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ DOCKER RUNTIME ДЛЯ LXC
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ DOCKER RUNTIME"
echo "==========================================${NC}"
echo ""

# 1. Остановка Docker
echo -e "${YELLOW}[1/5] Остановка Docker...${NC}"
systemctl stop docker 2>/dev/null || service docker stop 2>/dev/null || true
sleep 2
echo ""

# 2. Настройка Docker daemon БЕЗ sysctl
echo -e "${YELLOW}[2/5] Настройка Docker daemon...${NC}"
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
  "userland-proxy": false,
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOF

echo -e "${GREEN}✅ Docker daemon настроен${NC}"
echo ""

# 3. Попытка установить crun (альтернативный runtime)
echo -e "${YELLOW}[3/5] Попытка установить crun...${NC}"
if command -v apt-get &> /dev/null; then
    apt-get update -qq 2>/dev/null || true
    apt-get install -y crun 2>/dev/null || echo -e "${YELLOW}⚠️ crun не установлен (не критично)${NC}"
else
    echo -e "${YELLOW}⚠️ apt-get не найден, пропускаю установку crun${NC}"
fi
echo ""

# 4. Перезапуск Docker
echo -e "${YELLOW}[4/5] Перезапуск Docker...${NC}"
systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
sleep 5

if ! docker info &>/dev/null; then
    echo -e "${RED}❌ Docker не запустился!${NC}"
    echo ""
    echo -e "${YELLOW}Попробуйте настроить контейнер на хосте Proxmox:${NC}"
    echo "  pct set 102 -features nesting=1,keyctl=1,fuse=1"
    echo "  pct reboot 102"
    exit 1
fi

echo -e "${GREEN}✅ Docker запущен${NC}"
echo ""

# 5. Проверка
echo -e "${YELLOW}[5/5] Проверка Docker...${NC}"
docker info | head -10

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  ВАЖНО: Если проблема сохраняется,${NC}"
echo -e "${YELLOW}   настройте контейнер на ХОСТЕ Proxmox:${NC}"
echo ""
echo "1. В веб-интерфейсе Proxmox выберите узел 'citadel'"
echo "2. Нажмите '>_ Shell'"
echo "3. Выполните:"
echo "   pct set 102 -features nesting=1,keyctl=1,fuse=1"
echo "   echo 'net.ipv4.ip_unprivileged_port_start=0' >> /etc/sysctl.conf"
echo "   sysctl -p"
echo "   pct reboot 102"
echo ""
echo "После перезапуска выполните:"
echo "   cd /opt/eco-project && bash QUICK_FIX.sh"
echo ""


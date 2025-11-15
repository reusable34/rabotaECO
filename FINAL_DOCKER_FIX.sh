#!/bin/bash
# ==========================================
# ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ DOCKER ДЛЯ LXC
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ DOCKER"
echo "==========================================${NC}"
echo ""

# 1. Остановка Docker
echo -e "${YELLOW}[1/4] Остановка Docker...${NC}"
systemctl stop docker 2>/dev/null || service docker stop 2>/dev/null || true

# 2. Настройка Docker daemon БЕЗ sysctl
echo -e "${YELLOW}[2/4] Настройка Docker daemon...${NC}"
mkdir -p /etc/docker

cat > /etc/docker/daemon.json << 'DOCKER_EOF'
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
  "runtimes": {
    "runc": {
      "path": "runc",
      "runtimeArgs": []
    },
    "crun": {
      "path": "/usr/bin/crun",
      "runtimeArgs": []
    }
  },
  "default-runtime": "runc"
}
DOCKER_EOF

# 3. Перезапуск Docker
echo -e "${YELLOW}[3/4] Перезапуск Docker...${NC}"
systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
sleep 5

# 4. Проверка
echo -e "${YELLOW}[4/4] Проверка Docker...${NC}"
docker info | head -10

echo ""
echo -e "${GREEN}✅ Docker настроен!${NC}"
echo ""
echo "Теперь запустите:"
echo "  cd /opt/eco-project && bash GIT_DEPLOY.sh"
echo ""


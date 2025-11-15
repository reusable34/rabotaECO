#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ DOCKER ДЛЯ LXC
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ DOCKER ДЛЯ LXC"
echo "==========================================${NC}"
echo ""

# 1. Настройка Docker daemon
echo -e "${YELLOW}[1/3] Настройка Docker daemon...${NC}"
mkdir -p /etc/docker

cat > /etc/docker/daemon.json << 'DOCKER_EOF'
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "iptables": false,
  "ip-forward": false,
  "userland-proxy": false
}
DOCKER_EOF

# 2. Перезапуск Docker
echo -e "${YELLOW}[2/3] Перезапуск Docker...${NC}"
systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true
sleep 5

# 3. Проверка
echo -e "${YELLOW}[3/3] Проверка Docker...${NC}"
docker info | head -5

echo ""
echo -e "${GREEN}✅ Docker настроен!${NC}"
echo ""
echo "Теперь запустите:"
echo "  cd /opt/eco-project && bash GIT_DEPLOY.sh"
echo ""


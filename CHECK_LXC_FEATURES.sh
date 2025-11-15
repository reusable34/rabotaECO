#!/bin/bash
# ==========================================
# ПРОВЕРКА НАСТРОЕК LXC ДЛЯ DOCKER
# ==========================================
# Выполните ВНУТРИ контейнера 102

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔍 ПРОВЕРКА НАСТРОЕК LXC"
echo "==========================================${NC}"
echo ""

# Проверка features
echo -e "${YELLOW}Проверка features контейнера...${NC}"
if [ -f "/proc/self/status" ]; then
    echo "Статус контейнера:"
    cat /proc/self/status | grep -E "CapEff|Seccomp" || echo "Не удалось прочитать статус"
else
    echo -e "${RED}❌ Не удалось проверить features${NC}"
fi

echo ""
echo -e "${YELLOW}Проверка sysctl...${NC}"
if [ -f "/proc/sys/net/ipv4/ip_unprivileged_port_start" ]; then
    CURRENT_VALUE=$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start 2>/dev/null || echo "недоступно")
    echo "Текущее значение: $CURRENT_VALUE"
    if [ "$CURRENT_VALUE" = "0" ]; then
        echo -e "${GREEN}✅ sysctl настроен правильно${NC}"
    else
        echo -e "${RED}❌ sysctl не настроен (должно быть 0)${NC}"
    fi
else
    echo -e "${RED}❌ Файл sysctl недоступен${NC}"
fi

echo ""
echo -e "${RED}=========================================="
echo "⚠️  ПРОБЛЕМА: Контейнер не настроен на хосте Proxmox"
echo "==========================================${NC}"
echo ""
echo -e "${YELLOW}ВЫПОЛНИТЕ НА ХОСТЕ PROXMOX (citadel), НЕ В КОНТЕЙНЕРЕ:${NC}"
echo ""
echo "1. В веб-интерфейсе Proxmox:"
echo "   - Выберите узел 'citadel' (НЕ контейнер 102!)"
echo "   - Нажмите '>_ Shell' вверху справа"
echo "   - Выполните команды:"
echo ""
echo -e "${GREEN}pct set 102 -features nesting=1,keyctl=1,fuse=1${NC}"
echo -e "${GREEN}echo 'net.ipv4.ip_unprivileged_port_start=0' >> /etc/sysctl.conf${NC}"
echo -e "${GREEN}sysctl -p${NC}"
echo -e "${GREEN}pct reboot 102${NC}"
echo ""
echo "2. ИЛИ через SSH на хост Proxmox:"
echo "   ssh root@85.113.129.96"
echo "   (выполните те же команды)"
echo ""
echo "3. После перезапуска контейнера 102 выполните:"
echo "   cd /opt/eco-project && bash FIX_GIT_AND_DEPLOY.sh"
echo ""


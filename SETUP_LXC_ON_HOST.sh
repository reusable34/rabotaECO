#!/bin/bash
# ==========================================
# НАСТРОЙКА LXC КОНТЕЙНЕРА НА ХОСТЕ PROXMOX
# ==========================================
# ⚠️ ВЫПОЛНИТЕ НА ХОСТЕ PROXMOX (citadel), НЕ В КОНТЕЙНЕРЕ 102!

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

CT_ID=102

echo -e "${BLUE}=========================================="
echo "🔧 НАСТРОЙКА LXC КОНТЕЙНЕРА $CT_ID"
echo "==========================================${NC}"
echo ""

# Проверка, что мы на хосте
if ! command -v pct &> /dev/null; then
    echo -e "${RED}❌ Команда 'pct' не найдена!${NC}"
    echo "Этот скрипт должен выполняться на ХОСТЕ Proxmox, не в контейнере!"
    exit 1
fi

# 1. Проверка текущих настроек
echo -e "${YELLOW}[1/4] Проверка текущих настроек контейнера $CT_ID...${NC}"
pct config $CT_ID | grep -E "features|unprivileged" || echo "Настройки не найдены"
echo ""

# 2. Включение features
echo -e "${YELLOW}[2/4] Включение features (nesting, keyctl, fuse)...${NC}"
pct set $CT_ID -features nesting=1,keyctl=1,fuse=1
echo -e "${GREEN}✅ Features включены${NC}"
echo ""

# 3. Настройка sysctl на хосте
echo -e "${YELLOW}[3/4] Настройка sysctl на хосте...${NC}"
if ! grep -q "net.ipv4.ip_unprivileged_port_start=0" /etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv4.ip_unprivileged_port_start=0" >> /etc/sysctl.conf
    sysctl -p
    echo -e "${GREEN}✅ sysctl настроен${NC}"
else
    echo -e "${GREEN}✅ sysctl уже настроен${NC}"
fi
echo ""

# 4. Перезапуск контейнера
echo -e "${YELLOW}[4/4] Перезапуск контейнера $CT_ID...${NC}"
pct reboot $CT_ID

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Контейнер $CT_ID перезапускается..."
echo "Подождите 30 секунд, затем войдите в контейнер и выполните:"
echo "  cd /opt/eco-project && bash CLEAN_AND_RESTART_DOCKER.sh"
echo ""


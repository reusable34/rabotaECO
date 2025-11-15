#!/bin/bash
# ==========================================
# ПРОВЕРКА И ИНСТРУКЦИИ ПО НАСТРОЙКЕ LXC
# ==========================================
# Выполните ВНУТРИ контейнера 102

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}=========================================="
echo "❌ ПРОБЛЕМА: Docker не может работать в LXC"
echo "==========================================${NC}"
echo ""
echo -e "${YELLOW}Проблема: Docker пытается использовать sysctl,${NC}"
echo -e "${YELLOW}который недоступен в LXC контейнере без настройки на хосте.${NC}"
echo ""
echo -e "${BLUE}=========================================="
echo "🔧 РЕШЕНИЕ: Настроить контейнер на ХОСТЕ Proxmox"
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
echo -e "${BLUE}=========================================="
echo "🔄 АЛЬТЕРНАТИВА: Использовать версию БЕЗ Docker"
echo "==========================================${NC}"
echo ""
echo "Если настройка хоста невозможна, используйте версию БЕЗ Docker:"
echo ""
echo -e "${GREEN}cd /opt/eco-project${NC}"
echo -e "${GREEN}bash FULL_DEPLOY_NO_DOCKER.sh${NC}"
echo ""
echo "Это установит всё напрямую на систему (уже работает на сервере)."
echo ""


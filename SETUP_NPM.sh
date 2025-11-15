#!/bin/bash
# ==========================================
# АВТОМАТИЧЕСКАЯ НАСТРОЙКА ЧЕРЕЗ NPM
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

IP=$(hostname -I | awk '{print $1}')
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "ВАШ_IP")

echo -e "${BLUE}=========================================="
echo "🌐 НАСТРОЙКА ЧЕРЕЗ NGINX PROXY MANAGER"
echo "==========================================${NC}"
echo ""

# Проверка NPM
if ! docker ps | grep -q nginx-proxy-manager; then
    echo -e "${YELLOW}Nginx Proxy Manager не найден в Docker${NC}"
    echo "Настройте вручную через веб-интерфейс:"
    echo "1. Откройте: http://${EXTERNAL_IP}:81"
    echo "2. Добавьте Proxy Host:"
    echo "   - Domain: ${EXTERNAL_IP}"
    echo "   - Forward: http://127.0.0.1:3001"
    exit 0
fi

echo -e "${YELLOW}Настройка через NPM API...${NC}"

# Получаем токен (если API доступен)
NPM_CONTAINER=$(docker ps | grep nginx-proxy-manager | awk '{print $1}')

if [ -z "$NPM_CONTAINER" ]; then
    echo -e "${YELLOW}Контейнер NPM не найден${NC}"
    echo ""
    echo -e "${GREEN}Настройте вручную:${NC}"
    echo "1. Откройте: http://${EXTERNAL_IP}:81"
    echo "2. Hosts -> Proxy Hosts -> Add Proxy Host"
    echo "3. Заполните:"
    echo "   Domain Names: ${EXTERNAL_IP}"
    echo "   Forward Hostname/IP: 127.0.0.1"
    echo "   Forward Port: 3001"
    echo "4. Save"
    exit 0
fi

echo ""
echo -e "${GREEN}✅ Инструкция:${NC}"
echo ""
echo "1. Откройте: http://${EXTERNAL_IP}:81"
echo "2. Войдите в админ-панель"
echo "3. Hosts -> Proxy Hosts -> Add Proxy Host"
echo "4. Заполните:"
echo "   - Domain Names: ${EXTERNAL_IP} (или ваш домен)"
echo "   - Scheme: http"
echo "   - Forward Hostname/IP: 127.0.0.1"
echo "   - Forward Port: 3001"
echo "   - Cache Assets: ✅"
echo "   - Block Common Exploits: ✅"
echo "5. Save"
echo ""
echo "После этого сайт будет доступен: http://${EXTERNAL_IP}"
echo ""


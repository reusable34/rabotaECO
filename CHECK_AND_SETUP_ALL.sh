#!/bin/bash
# ==========================================
# ПРОВЕРКА И НАСТРОЙКА ВСЕГО
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔍 ПРОВЕРКА И НАСТРОЙКА ВСЕГО"
echo "==========================================${NC}"
echo ""

# 1. Проверка PostgreSQL
echo -e "${YELLOW}[1/6] Проверка PostgreSQL...${NC}"
if systemctl is-active --quiet postgresql; then
    echo -e "${GREEN}✅ PostgreSQL работает${NC}"
    sudo -u postgres psql -c "SELECT 1;" eco_client > /dev/null 2>&1 && echo -e "${GREEN}✅ База данных доступна${NC}" || echo -e "${RED}❌ База данных недоступна${NC}"
else
    echo -e "${RED}❌ PostgreSQL не работает${NC}"
    systemctl start postgresql
    systemctl enable postgresql
    echo -e "${GREEN}✅ PostgreSQL запущен${NC}"
fi
echo ""

# 2. Проверка PHP-FPM
echo -e "${YELLOW}[2/6] Проверка PHP-FPM...${NC}"
if systemctl is-active --quiet php8.2-fpm; then
    echo -e "${GREEN}✅ PHP-FPM работает${NC}"
else
    echo -e "${RED}❌ PHP-FPM не работает${NC}"
    systemctl start php8.2-fpm
    systemctl enable php8.2-fpm
    echo -e "${GREEN}✅ PHP-FPM запущен${NC}"
fi
echo ""

# 3. Проверка Backend
echo -e "${YELLOW}[3/6] Проверка Backend...${NC}"
BACKEND_RESPONSE=$(curl -s http://127.0.0.1:8080/health 2>/dev/null || echo "ERROR")
if echo "$BACKEND_RESPONSE" | grep -q "connected"; then
    echo -e "${GREEN}✅ Backend работает, база данных подключена${NC}"
    echo "Ответ: $BACKEND_RESPONSE"
else
    echo -e "${RED}❌ Backend не работает или база данных не подключена${NC}"
    echo "Ответ: $BACKEND_RESPONSE"
    echo ""
    echo "Проверьте:"
    echo "  systemctl status nginx"
    echo "  systemctl status php8.2-fpm"
    echo "  cat /opt/eco-project/backend/.env"
fi
echo ""

# 4. Проверка Next.js
echo -e "${YELLOW}[4/6] Проверка Next.js...${NC}"
if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js сервис работает${NC}"
else
    echo -e "${YELLOW}⚠️ Next.js сервис не работает, запускаю...${NC}"
    cd /opt/eco-project
    git pull
    bash SETUP_NEXTJS_DIRECT.sh
fi

sleep 2
FRONTEND_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3001 2>/dev/null || echo "000")
if [ "$FRONTEND_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✅ Frontend работает (HTTP $FRONTEND_RESPONSE)${NC}"
else
    echo -e "${RED}❌ Frontend не работает (HTTP $FRONTEND_RESPONSE)${NC}"
    echo "Проверьте логи: journalctl -u nextjs -n 20"
fi
echo ""

# 5. Проверка портов
echo -e "${YELLOW}[5/6] Проверка портов...${NC}"
echo "Порт 8080 (Backend):"
ss -tulpn | grep ":8080" && echo -e "${GREEN}✅ Порт 8080 открыт${NC}" || echo -e "${RED}❌ Порт 8080 не открыт${NC}"
echo ""
echo "Порт 3001 (Frontend):"
ss -tulpn | grep ":3001" && echo -e "${GREEN}✅ Порт 3001 открыт${NC}" || echo -e "${RED}❌ Порт 3001 не открыт${NC}"
echo ""

# 6. Проверка IP адреса
echo -e "${YELLOW}[6/6] Проверка IP адреса...${NC}"
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "IP адрес контейнера: $IP_ADDR"
if [ "$IP_ADDR" = "192.168.0.32" ]; then
    echo -e "${GREEN}✅ IP адрес правильный (192.168.0.32)${NC}"
else
    echo -e "${YELLOW}⚠️ IP адрес: $IP_ADDR (ожидался 192.168.0.32)${NC}"
fi
echo ""

echo -e "${GREEN}=========================================="
echo "✅ ПРОВЕРКА ЗАВЕРШЕНА"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}СЛЕДУЮЩИЕ ШАГИ:${NC}"
echo ""
echo "1. Если всё работает локально (✅), настройте Nginx Proxy Manager:"
echo "   http://85.113.129.96:81/nginx/proxy"
echo "   Логин: akakkiy.lalkin@mail.ru"
echo "   Пароль: 37983798"
echo ""
echo "2. Создайте Proxy Host для Frontend:"
echo "   - Domain Names: eco.local (или пусто)"
echo "   - Forward Hostname/IP: 192.168.0.32"
echo "   - Forward Port: 3001"
echo "   - Включите: Block Common Exploits, Websockets Support"
echo ""
echo "3. Создайте Proxy Host для Backend:"
echo "   - Domain Names: api.eco.local (или пусто)"
echo "   - Forward Hostname/IP: 192.168.0.32"
echo "   - Forward Port: 8080"
echo "   - Включите: Block Common Exploits"
echo ""
echo "4. После настройки сайт будет доступен через интернет!"
echo ""


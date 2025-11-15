#!/bin/bash
# ==========================================
# ПРАВИЛЬНАЯ НАСТРОЙКА API URL
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ПРАВИЛЬНАЯ НАСТРОЙКА API URL"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project/frontend

# Используем относительный путь - API будет доступен через /api
# Это работает, если Nginx Proxy Manager настроен правильно
API_URL="/api"

# Если нужен полный URL (если NPM не настроен):
# API_URL="http://85.113.129.96:3384/api"

echo -e "${YELLOW}[1/4] Настройка API URL...${NC}"
echo "Используем: $API_URL"
echo ""

# Создаем .env.local
cat > .env.local << EOF
NEXT_PUBLIC_API_URL=$API_URL
NEXT_PUBLIC_ENV=production
EOF

echo -e "${GREEN}✅ .env.local создан${NC}"
cat .env.local
echo ""

# 2. Остановка Next.js
echo -e "${YELLOW}[2/4] Остановка Next.js...${NC}"
systemctl stop nextjs 2>/dev/null || true
sleep 2
echo -e "${GREEN}✅ Next.js остановлен${NC}"
echo ""

# 3. Пересборка
echo -e "${YELLOW}[3/4] Пересборка frontend...${NC}"
npm run build
echo -e "${GREEN}✅ Frontend пересобран${NC}"
echo ""

# 4. Запуск
echo -e "${YELLOW}[4/4] Запуск Next.js...${NC}"
systemctl start nextjs

sleep 5

if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен${NC}"
else
    echo -e "${RED}❌ Next.js не запустился${NC}"
    journalctl -u nextjs -n 20 --no-pager
    exit 1
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}НАСТРОЙКА NGINX PROXY MANAGER:${NC}"
echo ""
echo "1. Создайте Proxy Host для Frontend:"
echo "   - Domain Names: eco.local (или пусто)"
echo "   - Forward Hostname/IP: 192.168.0.32"
echo "   - Forward Port: 3384"
echo "   - Включите: Block Common Exploits, Websockets Support"
echo ""
echo "2. Создайте Proxy Host для Backend API:"
echo "   - Domain Names: eco.local (ТОТ ЖЕ ДОМЕН!)"
echo "   - Forward Hostname/IP: 192.168.0.32"
echo "   - Forward Port: 8080"
echo "   - Включите: Block Common Exploits"
echo "   - Advanced: location /api { proxy_pass http://192.168.0.32:8080; }"
echo ""
echo "ИЛИ используйте один Proxy Host с двумя location:"
echo "   - location / → 192.168.0.32:3384"
echo "   - location /api → 192.168.0.32:8080"
echo ""


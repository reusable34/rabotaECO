#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ API URL ДЛЯ FRONTEND
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ API URL"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project/frontend

# Определяем API URL
# Если доступен из интернета через 85.113.129.96, используем его
# Иначе используем локальный IP
API_URL="http://85.113.129.96:8080"

echo -e "${YELLOW}[1/4] Настройка API URL: $API_URL${NC}"

# Создаем .env.local
cat > .env.local << EOF
NEXT_PUBLIC_API_URL=$API_URL
NEXT_PUBLIC_ENV=production
EOF

echo -e "${GREEN}✅ .env.local создан${NC}"
echo "Содержимое:"
cat .env.local
echo ""

# 2. Остановка Next.js
echo -e "${YELLOW}[2/4] Остановка Next.js...${NC}"
systemctl stop nextjs 2>/dev/null || true
pkill -f "next start" 2>/dev/null || true
sleep 2
echo -e "${GREEN}✅ Next.js остановлен${NC}"
echo ""

# 3. Пересборка frontend с новым API URL
echo -e "${YELLOW}[3/4] Пересборка frontend...${NC}"
npm run build
echo -e "${GREEN}✅ Frontend пересобран${NC}"
echo ""

# 4. Запуск Next.js
echo -e "${YELLOW}[4/4] Запуск Next.js...${NC}"
systemctl start nextjs

sleep 5

# Проверка
if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен${NC}"
    
    # Проверяем доступность
    sleep 2
    if curl -s http://127.0.0.1:3384 > /dev/null; then
        echo -e "${GREEN}✅ Frontend отвечает${NC}"
    else
        echo -e "${YELLOW}⚠️ Frontend запущен, но не отвечает${NC}"
    fi
else
    echo -e "${RED}❌ Next.js не запустился${NC}"
    echo "Логи:"
    journalctl -u nextjs -n 20 --no-pager
    exit 1
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "API URL настроен: $API_URL"
echo ""
echo "Проверьте вход на сайте:"
echo "  http://85.113.129.96:3384/login"
echo ""


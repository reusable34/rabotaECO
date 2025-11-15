#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ GIT И НАСТРОЙКА API URL
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ GIT И НАСТРОЙКА API URL"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project

# 1. Сохранение локальных изменений
echo -e "${YELLOW}[1/5] Сохранение локальных изменений...${NC}"
git stash || echo -e "${YELLOW}⚠️ Нет изменений для сохранения${NC}"
echo ""

# 2. Обновление проекта
echo -e "${YELLOW}[2/5] Обновление проекта...${NC}"
git pull
echo -e "${GREEN}✅ Проект обновлен${NC}"
echo ""

# 3. Настройка API URL
echo -e "${YELLOW}[3/5] Настройка API URL...${NC}"
cd frontend

API_URL="http://85.113.129.96:8080"

cat > .env.local << EOF
NEXT_PUBLIC_API_URL=$API_URL
NEXT_PUBLIC_ENV=production
EOF

echo -e "${GREEN}✅ .env.local создан с API URL: $API_URL${NC}"
echo ""

# 4. Пересборка frontend
echo -e "${YELLOW}[4/5] Пересборка frontend...${NC}"
npm run build
echo -e "${GREEN}✅ Frontend пересобран${NC}"
echo ""

# 5. Перезапуск Next.js
echo -e "${YELLOW}[5/5] Перезапуск Next.js...${NC}"
systemctl stop nextjs 2>/dev/null || true
sleep 2
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
echo "API URL настроен: $API_URL"
echo ""
echo "Проверьте вход:"
echo "  http://85.113.129.96:3384/login"
echo ""
echo -e "${YELLOW}ВАЖНО: Убедитесь, что backend доступен из интернета на порту 8080${NC}"
echo "Если нет, пробросьте порт 8080 в роутере или настройте Nginx Proxy Manager"
echo ""


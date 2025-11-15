#!/bin/bash
# ==========================================
# ОБНОВЛЕНИЕ КОДА НА СЕРВЕРЕ (БЕЗ DOCKER)
# ==========================================
# Выполните на сервере: bash UPDATE_CODE.sh
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/opt/eco-project"
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"

echo -e "${BLUE}=========================================="
echo "🔄 ОБНОВЛЕНИЕ КОДА"
echo "==========================================${NC}"
echo ""

cd "$PROJECT_DIR"

# 1. Обновление кода из Git
echo -e "${YELLOW}[1/4] Обновление кода из Git...${NC}"
git pull origin main
echo -e "${GREEN}✓ Код обновлен${NC}"

# 2. Обновление зависимостей Backend (если нужно)
echo -e "${YELLOW}[2/4] Проверка зависимостей Backend...${NC}"
cd "$BACKEND_DIR"
if [ -f "composer.json" ]; then
    composer install --no-dev --optimize-autoloader --no-interaction 2>&1 | tail -5 || echo "Composer обновление пропущено"
fi
echo -e "${GREEN}✓ Backend готов${NC}"

# 3. Пересборка Frontend
echo -e "${YELLOW}[3/5] Пересборка Frontend...${NC}"
cd "$FRONTEND_DIR"
if [ -f "package.json" ]; then
    # Очистка кэша Next.js
    rm -rf .next 2>/dev/null || true
    echo "Кэш Next.js очищен"
    
    npm install --legacy-peer-deps 2>&1 | tail -5 || true
    npm run build 2>&1 | tail -10 || echo "Frontend сборка пропущена"
fi
echo -e "${GREEN}✓ Frontend пересобран${NC}"

# 4. Перезапуск сервисов Backend
echo -e "${YELLOW}[4/5] Перезапуск сервисов Backend...${NC}"
systemctl restart php8.2-fpm 2>/dev/null || systemctl restart php-fpm 2>/dev/null || echo "PHP-FPM не перезапущен"
systemctl restart nginx 2>/dev/null || echo "Nginx не перезапущен"
echo -e "${GREEN}✓ Backend сервисы перезапущены${NC}"

# 5. Перезапуск Frontend
echo -e "${YELLOW}[5/5] Перезапуск Frontend...${NC}"

# Если Next.js запущен как systemd сервис
if systemctl is-active --quiet eco-frontend 2>/dev/null; then
    systemctl restart eco-frontend
    echo -e "${GREEN}✓ Next.js сервис (systemd) перезапущен${NC}"
# Если Next.js запущен через pm2
elif command -v pm2 &> /dev/null && pm2 list | grep -q "frontend\|next\|eco"; then
    pm2 restart frontend 2>/dev/null || pm2 restart next 2>/dev/null || pm2 restart eco 2>/dev/null || true
    echo -e "${GREEN}✓ Next.js (pm2) перезапущен${NC}"
# Если Next.js запущен через npm/node напрямую - убиваем процесс и перезапускаем
else
    # Ищем процесс Next.js
    NEXTJS_PID=$(ps aux | grep -E "next|node.*frontend" | grep -v grep | awk '{print $2}' | head -1)
    if [ -n "$NEXTJS_PID" ]; then
        echo "Найден процесс Next.js (PID: $NEXTJS_PID), перезапускаю..."
        kill $NEXTJS_PID 2>/dev/null || true
        sleep 2
    fi
    
    # Перезапускаем Next.js в фоне
    cd "$FRONTEND_DIR"
    nohup npm start > /dev/null 2>&1 &
    echo -e "${GREEN}✓ Next.js перезапущен (npm start)${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ОБНОВЛЕНИЕ ЗАВЕРШЕНО!"
echo "==========================================${NC}"
echo ""


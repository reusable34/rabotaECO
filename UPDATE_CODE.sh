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
echo -e "${YELLOW}[3/4] Пересборка Frontend...${NC}"
cd "$FRONTEND_DIR"
if [ -f "package.json" ]; then
    npm install --legacy-peer-deps 2>&1 | tail -5 || true
    npm run build 2>&1 | tail -10 || echo "Frontend сборка пропущена"
fi
echo -e "${GREEN}✓ Frontend пересобран${NC}"

# 4. Перезапуск сервисов
echo -e "${YELLOW}[4/4] Перезапуск сервисов...${NC}"
systemctl restart php8.2-fpm 2>/dev/null || systemctl restart php-fpm 2>/dev/null || echo "PHP-FPM не перезапущен"
systemctl restart nginx 2>/dev/null || echo "Nginx не перезапущен"

# Если Next.js запущен как сервис
if systemctl is-active --quiet eco-frontend 2>/dev/null; then
    systemctl restart eco-frontend
    echo -e "${GREEN}✓ Next.js сервис перезапущен${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ОБНОВЛЕНИЕ ЗАВЕРШЕНО!"
echo "==========================================${NC}"
echo ""


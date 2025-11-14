#!/bin/bash
# ==========================================
# НАСТРОЙКА GIT РЕПОЗИТОРИЯ ДЛЯ ДЕПЛОЯ
# Выполните на вашем Mac
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 НАСТРОЙКА GIT РЕПОЗИТОРИЯ"
echo "==========================================${NC}"
echo ""

# Вариант 1: GitHub (рекомендуется)
echo -e "${YELLOW}ВАРИАНТ 1: GitHub (самый простой)${NC}"
echo ""
echo "1. Создайте репозиторий на GitHub:"
echo "   https://github.com/new"
echo ""
echo "2. Затем выполните:"
echo ""
echo "   git remote add origin https://github.com/YOUR_USERNAME/rabotaECO.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. На сервере выполните:"
echo ""
echo "   cd /opt && git clone https://github.com/YOUR_USERNAME/rabotaECO.git eco-project"
echo "   cd eco-project && bash GIT_DEPLOY.sh"
echo ""

# Вариант 2: Git Bundle (без интернета)
echo -e "${YELLOW}ВАРИАНТ 2: Git Bundle (без GitHub)${NC}"
echo ""
echo "Создаю bundle файл..."
cd "$(dirname "$0")"
git bundle create eco-project.bundle HEAD main
echo ""
echo -e "${GREEN}✓ Создан eco-project.bundle${NC}"
echo ""
echo "Загрузите eco-project.bundle на сервер, затем:"
echo ""
echo "   cd /opt"
echo "   git clone eco-project.bundle eco-project"
echo "   cd eco-project && bash GIT_DEPLOY.sh"
echo ""


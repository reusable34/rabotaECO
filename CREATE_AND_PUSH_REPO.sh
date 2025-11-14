#!/bin/bash
# ==========================================
# СОЗДАНИЕ И ПУШ В GITHUB РЕПОЗИТОРИЙ
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_NAME="rabotaECO"
GITHUB_USER="${1:-}"

echo -e "${BLUE}=========================================="
echo "🚀 СОЗДАНИЕ GITHUB РЕПОЗИТОРИЯ"
echo "==========================================${NC}"
echo ""

cd "$(dirname "$0")"

# Проверка что все закоммичено
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}Есть незакоммиченные изменения, коммичу...${NC}"
    git add -A
    git commit -m "Auto commit before push" || true
fi

# Вариант 1: GitHub CLI
if command -v gh &> /dev/null && gh auth status &>/dev/null; then
    echo -e "${YELLOW}Использую GitHub CLI...${NC}"
    
    if [ -z "$GITHUB_USER" ]; then
        GITHUB_USER=$(gh api user --jq .login)
        echo "Найден пользователь: $GITHUB_USER"
    fi
    
    # Создаем репозиторий
    echo "Создаю репозиторий $REPO_NAME..."
    gh repo create "$REPO_NAME" --public --source=. --remote=origin --push 2>&1 || {
        echo "Репо уже существует, обновляю..."
        git remote remove origin 2>/dev/null || true
        gh repo create "$REPO_NAME" --public --source=. --remote=origin --push 2>&1 || {
            git remote add origin "https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
            git branch -M main
            git push -u origin main
        }
    }
    
    echo ""
    echo -e "${GREEN}✅ Репозиторий создан и запушен!${NC}"
    echo ""
    echo "URL: https://github.com/${GITHUB_USER}/${REPO_NAME}"
    echo ""
    echo "На сервере выполните:"
    echo "  git clone https://github.com/${GITHUB_USER}/${REPO_NAME}.git /opt/eco-project"
    echo "  cd /opt/eco-project && bash GIT_DEPLOY.sh"
    exit 0
fi

# Вариант 2: Ручное создание
echo -e "${YELLOW}GitHub CLI не найден, используйте ручной способ:${NC}"
echo ""
echo "1. Создайте репозиторий на GitHub:"
echo "   https://github.com/new"
echo "   Название: $REPO_NAME"
echo "   Тип: Public"
echo ""
echo "2. Затем выполните эти команды:"
echo ""
echo "   git remote add origin https://github.com/YOUR_USERNAME/$REPO_NAME.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. На сервере:"
echo ""
echo "   git clone https://github.com/YOUR_USERNAME/$REPO_NAME.git /opt/eco-project"
echo "   cd /opt/eco-project && bash GIT_DEPLOY.sh"
echo ""


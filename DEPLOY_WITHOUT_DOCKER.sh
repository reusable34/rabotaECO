#!/bin/bash
# ==========================================
# ДЕПЛОЙ БЕЗ DOCKER (для LXC без Docker)
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/opt/eco-project"
IP=$(hostname -I | awk '{print $1}')

echo -e "${BLUE}=========================================="
echo "🚀 ДЕПЛОЙ БЕЗ DOCKER"
echo "==========================================${NC}"
echo ""

cd "$PROJECT_DIR"

# 1. Установка PostgreSQL
echo -e "${YELLOW}[1/5] Установка PostgreSQL...${NC}"
apt-get update -qq
apt-get install -y postgresql postgresql-contrib
systemctl start postgresql
systemctl enable postgresql

# 2. Создание БД
echo -e "${YELLOW}[2/5] Создание базы данных...${NC}"
sudo -u postgres psql << 'SQL'
CREATE DATABASE eco_client;
CREATE USER eco_admin WITH PASSWORD 'eco_pass';
GRANT ALL PRIVILEGES ON DATABASE eco_client TO eco_admin;
\q
SQL

# 3. Установка PHP и зависимостей
echo -e "${YELLOW}[3/5] Установка PHP...${NC}"
apt-get install -y php8.2-fpm php8.2-pgsql php8.2-mbstring php8.2-xml php8.2-curl nginx composer

# 4. Настройка backend
echo -e "${YELLOW}[4/5] Настройка backend...${NC}"
cd backend
composer install --no-interaction
cp .env.example .env 2>/dev/null || true
php yii migrate --interactive=0
php yii seed 2>/dev/null || true

# 5. Настройка frontend
echo -e "${YELLOW}[5/5] Настройка frontend...${NC}"
cd ../frontend
npm install
npm run build

echo ""
echo -e "${GREEN}✅ ДЕПЛОЙ ЗАВЕРШЕН!${NC}"
echo ""
echo "Backend: http://${IP}:8080"
echo "Frontend: http://${IP}:3001"
echo ""


#!/bin/bash
# ==========================================
# ОЧИСТКА СТАРЫХ СЕРВИСОВ И ЗАПУСК DOCKER
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🧹 ОЧИСТКА И ЗАПУСК DOCKER"
echo "==========================================${NC}"
echo ""

# 1. Остановка старых сервисов
echo -e "${YELLOW}[1/4] Остановка старых сервисов...${NC}"

# Остановка Next.js если запущен
pkill -f "npm start" 2>/dev/null || pkill -f "next start" 2>/dev/null || true
echo "Next.js остановлен"

# Остановка Nginx на портах 80/3000
systemctl stop nginx 2>/dev/null || true
echo "Nginx остановлен"

# Остановка PHP-FPM
systemctl stop php8.2-fpm 2>/dev/null || true
echo "PHP-FPM остановлен"

# Остановка PostgreSQL (если установлен локально)
systemctl stop postgresql 2>/dev/null || true
echo "PostgreSQL остановлен"

# 2. Остановка Docker контейнеров если есть
echo -e "${YELLOW}[2/4] Остановка старых Docker контейнеров...${NC}"
cd /opt/eco-project
docker compose -f docker-compose.lxc.yml down 2>/dev/null || true
docker compose -f docker-compose.production.yml down 2>/dev/null || true
docker compose down 2>/dev/null || true
echo "Старые контейнеры остановлены"

# 3. Проверка портов
echo -e "${YELLOW}[3/4] Проверка портов...${NC}"
netstat -tuln | grep -E ":(80|3000|3001|8080|5432|5433)" || echo "Порты свободны"

# 4. Запуск через Docker
echo -e "${YELLOW}[4/4] Запуск через Docker...${NC}"
bash GIT_DEPLOY.sh

echo ""
echo -e "${GREEN}✅ ГОТОВО!${NC}"
echo ""


#!/bin/bash
# ==========================================
# ЗАПУСК КОНТЕЙНЕРОВ ВРУЧНУЮ (БЕЗ DOCKER-COMPOSE)
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🚀 ЗАПУСК КОНТЕЙНЕРОВ ВРУЧНУЮ"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project

# 1. Останавливаем всё
echo -e "${YELLOW}[1/6] Остановка всех контейнеров...${NC}"
docker stop eco_db eco_backend eco_frontend eco_adminer 2>/dev/null || true
docker rm eco_db eco_backend eco_frontend eco_adminer 2>/dev/null || true

# Останавливаем docker-compose если есть
if command -v docker-compose &> /dev/null; then
    docker-compose -f docker-compose.production.yml down 2>/dev/null || true
elif docker compose version &> /dev/null; then
    docker compose -f docker-compose.production.yml down 2>/dev/null || true
fi

echo -e "${GREEN}✅ Остановлено${NC}"
echo ""

# 2. Создаем сеть
echo -e "${YELLOW}[2/6] Создание сети...${NC}"
docker network create eco_network 2>/dev/null || echo "Сеть уже существует"
echo -e "${GREEN}✅ Сеть создана${NC}"
echo ""

# 3. Запуск базы данных
echo -e "${YELLOW}[3/6] Запуск базы данных...${NC}"
docker run -d \
  --name eco_db \
  --network eco_network \
  --privileged \
  -e POSTGRES_DB=eco_client \
  -e POSTGRES_USER=eco_admin \
  -e POSTGRES_PASSWORD=eco_pass \
  -p 5433:5432 \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:15-alpine

echo "Ожидание готовности БД..."
sleep 10
echo -e "${GREEN}✅ База данных запущена${NC}"
echo ""

# 4. Запуск backend
echo -e "${YELLOW}[4/6] Запуск backend...${NC}"
docker run -d \
  --name eco_backend \
  --network eco_network \
  --privileged \
  -v $(pwd)/backend:/var/www/html \
  -v backend_storage:/var/www/html/storage \
  -e DB_HOST=eco_db \
  -e DB_NAME=eco_client \
  -e DB_USER=eco_admin \
  -e DB_PASSWORD=eco_pass \
  -e JWT_SECRET=supersecretkey \
  -e BACKEND_URL=http://localhost:8080 \
  -p 8080:80 \
  php:8.2-apache \
  bash -c "
  apt-get update -qq &&
  apt-get install -y -qq libpq-dev libzip-dev unzip git curl wget &&
  docker-php-ext-install pdo pdo_pgsql zip &&
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer &&
  cd /var/www/html &&
  composer install --no-dev --optimize-autoloader --no-interaction --quiet &&
  chmod -R 777 storage runtime &&
  a2enmod rewrite &&
  apache2-foreground
  "

echo -e "${GREEN}✅ Backend запущен${NC}"
echo ""

# 5. Запуск frontend
echo -e "${YELLOW}[5/6] Запуск frontend...${NC}"
docker run -d \
  --name eco_frontend \
  --network eco_network \
  --privileged \
  -v $(pwd)/frontend:/app \
  -v /app/node_modules \
  -v /app/.next \
  -e NEXT_PUBLIC_API_URL=http://localhost:8080 \
  -e NEXT_PUBLIC_ENV=production \
  -p 3001:3000 \
  -w /app \
  node:20-alpine \
  sh -c "
  npm install &&
  npm run build &&
  npm start
  "

echo -e "${GREEN}✅ Frontend запущен${NC}"
echo ""

# 6. Запуск adminer
echo -e "${YELLOW}[6/6] Запуск adminer...${NC}"
docker run -d \
  --name eco_adminer \
  --network eco_network \
  --privileged \
  -p 8082:8080 \
  adminer:latest

echo -e "${GREEN}✅ Adminer запущен${NC}"
echo ""

# Проверка
echo -e "${YELLOW}Статус контейнеров:${NC}"
docker ps --filter "name=eco_"

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ВСЕ КОНТЕЙНЕРЫ ЗАПУЩЕНЫ!"
echo "==========================================${NC}"
echo ""
echo "Проверьте:"
echo "  docker ps"
echo "  curl http://127.0.0.1:8080/health"
echo "  curl http://127.0.0.1:3001"
echo ""
echo "Остановить все:"
echo "  docker stop eco_db eco_backend eco_frontend eco_adminer"
echo "  docker rm eco_db eco_backend eco_frontend eco_adminer"
echo ""


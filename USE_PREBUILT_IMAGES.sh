#!/bin/bash
# ==========================================
# ИСПОЛЬЗОВАНИЕ ГОТОВЫХ ОБРАЗОВ ВМЕСТО СБОРКИ
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "📦 ИСПОЛЬЗОВАНИЕ ГОТОВЫХ ОБРАЗОВ"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project

# Определяем команду docker-compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo -e "${RED}❌ docker-compose не найден!${NC}"
    exit 1
fi

# 1. Останавливаем контейнеры
echo -e "${YELLOW}[1/3] Остановка контейнеров...${NC}"
$COMPOSE_CMD -f docker-compose.production.yml down 2>/dev/null || true
echo ""

# 2. Создаем временный docker-compose без сборки
echo -e "${YELLOW}[2/3] Создание docker-compose без сборки...${NC}"

# Создаем backup
cp docker-compose.production.yml docker-compose.production.yml.backup

# Создаем версию с готовыми образами
cat > docker-compose.production.yml << 'EOF'
services:
  db:
    image: postgres:15-alpine
    container_name: eco_db
    privileged: true
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-eco_admin}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-eco_pass}
      POSTGRES_DB: ${POSTGRES_DB:-eco_client}
    ports:
      - "5433:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-eco_admin}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - eco_network

  backend:
    image: php:8.2-apache
    container_name: eco_backend
    privileged: true
    ports:
      - "8080:80"
    volumes:
      - ./backend:/var/www/html
      - backend_storage:/var/www/html/storage
    depends_on:
      db:
        condition: service_healthy
    environment:
      DB_HOST: db
      DB_NAME: ${POSTGRES_DB:-eco_client}
      DB_USER: ${POSTGRES_USER:-eco_admin}
      DB_PASSWORD: ${POSTGRES_PASSWORD:-eco_pass}
      JWT_SECRET: ${JWT_SECRET:-supersecretkey}
      BACKEND_URL: ${BACKEND_URL:-http://localhost:8080}
    command: >
      bash -c "
      apt-get update -qq &&
      apt-get install -y -qq libpq-dev libzip-dev unzip git curl &&
      docker-php-ext-install pdo pdo_pgsql zip &&
      curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer &&
      cd /var/www/html &&
      composer install --no-dev --optimize-autoloader --no-interaction &&
      chmod -R 777 storage runtime &&
      apache2-foreground
      "
    networks:
      - eco_network

  frontend:
    image: node:20-alpine
    container_name: eco_frontend
    privileged: true
    ports:
      - "3001:3000"
    volumes:
      - ./frontend:/app
      - /app/node_modules
      - /app/.next
    working_dir: /app
    environment:
      NEXT_PUBLIC_API_URL: ${BACKEND_URL:-http://localhost:8080}
      NEXT_PUBLIC_ENV: ${ENV:-production}
    command: >
      sh -c "
      npm install &&
      npm run build &&
      npm start
      "
    depends_on:
      - backend
    networks:
      - eco_network

  adminer:
    image: adminer:latest
    container_name: eco_adminer
    privileged: true
    ports:
      - "8082:8080"
    depends_on:
      - db
    networks:
      - eco_network

volumes:
  postgres_data:
  backend_storage:

networks:
  eco_network:
    driver: bridge
EOF

echo -e "${GREEN}✅ Файл создан${NC}"
echo ""

# 3. Запуск контейнеров
echo -e "${YELLOW}[3/3] Запуск контейнеров...${NC}"
$COMPOSE_CMD -f docker-compose.production.yml up -d

# Ждем
sleep 15

# Проверка статуса
echo ""
echo -e "${YELLOW}Статус контейнеров:${NC}"
$COMPOSE_CMD -f docker-compose.production.yml ps

echo ""
echo -e "${YELLOW}Последние логи:${NC}"
$COMPOSE_CMD -f docker-compose.production.yml logs --tail=10

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Проверьте:"
echo "  docker ps"
echo "  curl http://127.0.0.1:8080/health"
echo "  curl http://127.0.0.1:3001"
echo ""
echo -e "${YELLOW}Примечание: Используются готовые образы вместо сборки${NC}"
echo ""


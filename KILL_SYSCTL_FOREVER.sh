#!/bin/bash
# ==========================================
# УБИТЬ SYSCTL НАВСЕГДА
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "💀 УБИТЬ SYSCTL НАВСЕГДА"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project

# Определяем команду docker-compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker compose"
fi

# 1. Останавливаем всё
echo -e "${YELLOW}[1/5] Остановка всех контейнеров...${NC}"
$COMPOSE_CMD -f docker-compose.production.yml down 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
echo -e "${GREEN}✅ Остановлено${NC}"
echo ""

# 2. Проверяем что есть sysctl в файле
echo -e "${YELLOW}[2/5] Проверка docker-compose.production.yml на sysctl...${NC}"
if grep -qi "sysctl" docker-compose.production.yml 2>/dev/null; then
    echo -e "${RED}❌ НАЙДЕН SYSCTL! Удаляю...${NC}"
    grep -n "sysctl" docker-compose.production.yml
else
    echo -e "${GREEN}✅ sysctl не найден в файле${NC}"
fi
echo ""

# 3. Создаем backup и УДАЛЯЕМ ВСЁ что связано с sysctl
echo -e "${YELLOW}[3/5] Создание backup и удаление sysctl...${NC}"
cp docker-compose.production.yml docker-compose.production.yml.backup.$(date +%Y%m%d_%H%M%S)

# Удаляем ВСЁ что связано с sysctl
grep -v "sysctls:\|net.ipv4.ip_unprivileged_port_start\|ip_unprivileged_port_start" docker-compose.production.yml > docker-compose.production.yml.tmp
mv docker-compose.production.yml.tmp docker-compose.production.yml

# Проверяем что удалили
if grep -qi "sysctl" docker-compose.production.yml 2>/dev/null; then
    echo -e "${RED}❌ SYSCTL ВСЁ ЕЩЁ ЕСТЬ!${NC}"
    grep -n "sysctl" docker-compose.production.yml
    exit 1
else
    echo -e "${GREEN}✅ sysctl полностью удален${NC}"
fi
echo ""

# 4. Создаем ЧИСТЫЙ docker-compose БЕЗ сборки (готовые образы)
echo -e "${YELLOW}[4/5] Создание ЧИСТОГО docker-compose БЕЗ сборки...${NC}"
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
      apt-get install -y -qq libpq-dev libzip-dev unzip git curl wget &&
      docker-php-ext-install pdo pdo_pgsql zip &&
      curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer &&
      cd /var/www/html &&
      composer install --no-dev --optimize-autoloader --no-interaction --quiet &&
      chmod -R 777 storage runtime &&
      a2enmod rewrite &&
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

echo -e "${GREEN}✅ Чистый docker-compose создан (БЕЗ сборки, БЕЗ sysctl)${NC}"
echo ""

# 5. Финальная проверка и запуск
echo -e "${YELLOW}[5/5] Финальная проверка и запуск...${NC}"

# Проверяем что sysctl нет
if grep -qi "sysctl\|build:" docker-compose.production.yml 2>/dev/null; then
    echo -e "${RED}❌ ОШИБКА: sysctl или build всё ещё есть!${NC}"
    grep -n "sysctl\|build:" docker-compose.production.yml
    exit 1
fi

echo -e "${GREEN}✅ Файл чистый (нет sysctl, нет build)${NC}"
echo ""

# Запускаем
echo "Запуск контейнеров..."
$COMPOSE_CMD -f docker-compose.production.yml up -d

# Ждем
sleep 15

# Статус
echo ""
echo -e "${YELLOW}Статус контейнеров:${NC}"
$COMPOSE_CMD -f docker-compose.production.yml ps

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО! SYSCTL УБИТ НАВСЕГДА!"
echo "==========================================${NC}"
echo ""
echo "Проверьте:"
echo "  docker ps"
echo "  curl http://127.0.0.1:8080/health"
echo "  curl http://127.0.0.1:3001"
echo ""
echo -e "${YELLOW}Примечание: Используются готовые образы, сборка не требуется${NC}"
echo ""


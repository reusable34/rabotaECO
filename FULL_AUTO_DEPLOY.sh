#!/bin/bash
# ==========================================
# ПОЛНОСТЬЮ АВТОМАТИЧЕСКИЙ ДЕПЛОЙ
# Скопируйте и выполните эту команду на сервере:
# ==========================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/opt/eco-project"
IP=$(hostname -I | awk '{print $1}')

echo -e "${BLUE}=========================================="
echo "🚀 ПОЛНОСТЬЮ АВТОМАТИЧЕСКИЙ ДЕПЛОЙ"
echo "==========================================${NC}"
echo ""

# 1. Установка Docker
echo -e "${YELLOW}[1/8] Установка Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
    echo -e "${GREEN}✓ Docker установлен${NC}"
else
    echo -e "${GREEN}✓ Docker: $(docker --version)${NC}"
fi

# 2. Установка Docker Compose
echo -e "${YELLOW}[2/8] Установка Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    apt-get update -qq
    apt-get install -y docker-compose-plugin 2>/dev/null || apt-get install -y docker-compose
    echo -e "${GREEN}✓ Docker Compose установлен${NC}"
else
    echo -e "${GREEN}✓ Docker Compose установлен${NC}"
fi

# 3. Создание директории
echo -e "${YELLOW}[3/8] Подготовка проекта...${NC}"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 4. Проверка наличия проекта
if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.production.yml" ]; then
    echo -e "${YELLOW}Проект не найден. Создаю минимальную структуру...${NC}"
    
    # Создаем docker-compose.production.yml
    cat > docker-compose.production.yml << 'EOF'
services:
  db:
    image: postgres:15-alpine
    container_name: eco_db
    environment:
      POSTGRES_USER: eco_admin
      POSTGRES_PASSWORD: eco_pass
      POSTGRES_DB: eco_client
    ports:
      - "5433:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U eco_admin"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - eco_network

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: eco_backend
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
      DB_NAME: eco_client
      DB_USER: eco_admin
      DB_PASSWORD: eco_pass
      JWT_SECRET: supersecretkey
      BACKEND_URL: http://localhost:8080
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:80/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - eco_network

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: eco_frontend
    ports:
      - "3001:3000"
    volumes:
      - ./frontend:/app
      - /app/node_modules
      - /app/.next
    environment:
      NEXT_PUBLIC_API_URL: http://IP_PLACEHOLDER:8080
      NEXT_PUBLIC_ENV: production
    depends_on:
      backend:
        condition: service_started
    networks:
      - eco_network

  adminer:
    image: adminer:latest
    container_name: eco_adminer
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
    
    # Заменяем IP
    sed -i "s/IP_PLACEHOLDER/${IP}/g" docker-compose.production.yml
    
    echo -e "${YELLOW}⚠ Создана минимальная структура. Загрузите полный проект в $PROJECT_DIR${NC}"
    echo "Или выполните на вашем Mac:"
    echo "  scp -r /Users/komp/Documents/PROGRAMIROVANIE/rabotaECO root@${IP}:${PROJECT_DIR}"
    exit 1
fi

# 5. Настройка переменных
echo -e "${YELLOW}[4/8] Настройка переменных...${NC}"
mkdir -p frontend
cat > frontend/.env.local << EOF
NEXT_PUBLIC_API_URL=http://${IP}:8080
NEXT_PUBLIC_ENV=production
EOF

# 6. Выбор конфигурации
COMPOSE_FILE="docker-compose.yml"
if [ -f "docker-compose.production.yml" ]; then
    COMPOSE_FILE="docker-compose.production.yml"
fi

# 7. Запуск
echo -e "${YELLOW}[5/8] Остановка старых контейнеров...${NC}"
docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true

echo -e "${YELLOW}[6/8] Запуск контейнеров (это займет 5-10 минут)...${NC}"
docker-compose -f "$COMPOSE_FILE" up -d --build

echo -e "${YELLOW}[7/8] Ожидание запуска (60 секунд)...${NC}"
sleep 60

# 8. Миграции
echo -e "${YELLOW}[8/8] Миграции и данные...${NC}"
for i in {1..30}; do
    docker-compose -f "$COMPOSE_FILE" exec -T db pg_isready -U eco_admin &>/dev/null 2>&1 && break || sleep 2
done

docker-compose -f "$COMPOSE_FILE" exec -T backend php yii migrate --interactive=0 2>/dev/null || true
docker-compose -f "$COMPOSE_FILE" exec -T backend php yii seed 2>/dev/null || true

# Итог
echo ""
echo -e "${GREEN}=========================================="
echo "🎉 ДЕПЛОЙ ЗАВЕРШЕН!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}🌐 Доступ:${NC}"
echo "  Frontend:  http://${IP}:3001"
echo "  Backend:   http://${IP}:8080"
echo "  Adminer:   http://${IP}:8082"
echo ""


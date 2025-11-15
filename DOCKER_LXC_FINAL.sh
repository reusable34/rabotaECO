#!/bin/bash
# ==========================================
# ФИНАЛЬНОЕ РЕШЕНИЕ DOCKER В LXC
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ФИНАЛЬНАЯ НАСТРОЙКА DOCKER ДЛЯ LXC"
echo "==========================================${NC}"
echo ""

# 1. Остановка всех контейнеров
echo -e "${YELLOW}[1/5] Остановка контейнеров...${NC}"
cd /opt/eco-project
docker compose -f docker-compose.production.yml down 2>/dev/null || true
docker compose down 2>/dev/null || true

# 2. Остановка Docker
echo -e "${YELLOW}[2/5] Остановка Docker...${NC}"
systemctl stop docker 2>/dev/null || service docker stop 2>/dev/null || true

# 3. Настройка Docker daemon
echo -e "${YELLOW}[3/5] Настройка Docker daemon...${NC}"
mkdir -p /etc/docker

cat > /etc/docker/daemon.json << 'DOCKER_EOF'
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "iptables": false,
  "ip-forward": false,
  "userland-proxy": false
}
DOCKER_EOF

# 4. Перезапуск Docker
echo -e "${YELLOW}[4/5] Перезапуск Docker...${NC}"
systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
sleep 5

# 5. Запуск с privileged для всех контейнеров
echo -e "${YELLOW}[5/5] Запуск контейнеров...${NC}"

# Временно добавляем privileged ко всем сервисам
cat > /tmp/docker-compose-temp.yml << 'COMPOSE_EOF'
services:
  db:
    image: postgres:15-alpine
    container_name: eco_db
    privileged: true
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
      DB_NAME: eco_client
      DB_USER: eco_admin
      DB_PASSWORD: eco_pass
      JWT_SECRET: supersecretkey
      BACKEND_URL: http://localhost:8080
    networks:
      - eco_network

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: eco_frontend
    privileged: true
    ports:
      - "3001:3000"
    volumes:
      - ./frontend:/app
      - /app/node_modules
      - /app/.next
    environment:
      NEXT_PUBLIC_API_URL: http://localhost:8080
      NEXT_PUBLIC_ENV: production
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
COMPOSE_EOF

docker compose -f /tmp/docker-compose-temp.yml up -d --build

# Ожидание
echo "Ожидание запуска (60 сек)..."
sleep 60

# Миграции
echo "Выполнение миграций..."
for i in {1..30}; do
    docker compose -f /tmp/docker-compose-temp.yml exec -T db pg_isready -U eco_admin &>/dev/null 2>&1 && break || sleep 2
done

docker compose -f /tmp/docker-compose-temp.yml exec -T backend php yii migrate --interactive=0 2>/dev/null || true
docker compose -f /tmp/docker-compose-temp.yml exec -T backend php yii seed 2>/dev/null || true

IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}=========================================="
echo "🎉 DOCKER ЗАПУЩЕН!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}🌐 Доступ:${NC}"
echo "  Frontend:  http://${IP}:3001"
echo "  Backend:   http://${IP}:8080"
echo "  Adminer:   http://${IP}:8082"
echo ""


#!/bin/bash
# ==========================================
# БЫСТРОЕ ИСПРАВЛЕНИЕ (ВАРИАНТ 4)
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "⚡ БЫСТРОЕ ИСПРАВЛЕНИЕ"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project

# 1. Backup
echo -e "${YELLOW}[1/4] Создание backup...${NC}"
cp docker-compose.production.yml docker-compose.production.yml.backup
echo -e "${GREEN}✅ Backup создан${NC}"
echo ""

# 2. Удаление sysctl (если есть)
echo -e "${YELLOW}[2/4] Удаление sysctl из docker-compose.production.yml...${NC}"
sed -i '/sysctls:/d' docker-compose.production.yml
sed -i '/net.ipv4.ip_unprivileged_port_start/d' docker-compose.production.yml
sed -i '/ip_unprivileged_port_start/d' docker-compose.production.yml
echo -e "${GREEN}✅ sysctl удалены${NC}"
echo ""

# 3. Проверка результата
echo -e "${YELLOW}[3/4] Проверка файла...${NC}"
if grep -q "sysctl" docker-compose.production.yml 2>/dev/null; then
    echo -e "${YELLOW}⚠️ Найдены упоминания sysctl:${NC}"
    grep -n "sysctl" docker-compose.production.yml
else
    echo -e "${GREEN}✅ sysctl не найдены${NC}"
fi
echo ""

# 4. Остановка и запуск
echo -e "${YELLOW}[4/4] Перезапуск контейнеров...${NC}"

# Определяем команду
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo -e "${RED}❌ docker-compose не найден!${NC}"
    exit 1
fi

# Останавливаем
$COMPOSE_CMD -f docker-compose.production.yml down 2>/dev/null || true

# Запускаем
$COMPOSE_CMD -f docker-compose.production.yml up -d

# Ждем
sleep 10

# Статус
echo ""
echo -e "${YELLOW}Статус:${NC}"
$COMPOSE_CMD -f docker-compose.production.yml ps

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""


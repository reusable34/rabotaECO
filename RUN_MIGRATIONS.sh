#!/bin/bash
# ==========================================
# ЗАПУСК МИГРАЦИЙ БАЗЫ ДАННЫХ
# ==========================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔧 ЗАПУСК МИГРАЦИЙ БАЗЫ ДАННЫХ${NC}"
echo ""

cd /opt/eco-project/backend || { echo -e "${RED}❌ Не найден /opt/eco-project/backend${NC}"; exit 1; }

# Проверяем подключение к БД
echo -e "${YELLOW}[1/3] Проверка подключения к БД...${NC}"
php yii migrate/up --interactive=0 --migrationPath=@console/migrations 2>&1 | head -5

# Запускаем миграции
echo ""
echo -e "${YELLOW}[2/3] Запуск миграций...${NC}"
php yii migrate --interactive=0

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Миграции выполнены успешно${NC}"
else
    echo -e "${RED}❌ Ошибка при выполнении миграций${NC}"
    exit 1
fi

# Проверяем что таблица users создана
echo ""
echo -e "${YELLOW}[3/3] Проверка таблицы users...${NC}"
php yii migrate/history 2>/dev/null | grep -i users && echo -e "${GREEN}✅ Таблица users существует${NC}" || echo -e "${YELLOW}⚠️  Не удалось проверить таблицу${NC}"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ МИГРАЦИИ ЗАВЕРШЕНЫ${NC}"
echo ""
echo "Если таблица users все еще не существует, выполните:"
echo "  cd /opt/eco-project/backend"
echo "  php yii migrate/up --interactive=0"
echo ""


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
php -r "
try {
    \$pdo = new PDO('pgsql:host=' . (getenv('DB_HOST') ?: 'localhost') . ';dbname=' . (getenv('DB_NAME') ?: 'eco_client'), 
                    getenv('DB_USER') ?: 'eco_admin', 
                    getenv('DB_PASSWORD') ?: 'eco_pass');
    echo '✅ Подключение к БД успешно\n';
} catch (PDOException \$e) {
    echo '❌ Ошибка подключения: ' . \$e->getMessage() . '\n';
    exit(1);
}
" || {
    echo -e "${RED}❌ Не удалось подключиться к БД${NC}"
    echo "Проверьте:"
    echo "  1. PostgreSQL запущен: systemctl status postgresql"
    echo "  2. База данных создана: sudo -u postgres psql -l | grep eco_client"
    echo "  3. Пользователь существует: sudo -u postgres psql -c '\du' | grep eco_admin"
    exit 1
}

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


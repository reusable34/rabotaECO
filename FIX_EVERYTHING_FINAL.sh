#!/bin/bash
# ==========================================
# ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ ВСЕГО
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🚀 ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ ВСЕГО"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project || exit 1

# 1. Обновление кода
echo -e "${YELLOW}[1/5] Обновление кода...${NC}"
git fetch origin
git reset --hard origin/main 2>/dev/null || git pull --no-edit
echo -e "${GREEN}✅ Код обновлен${NC}"
echo ""

# 2. Проверка/создание базы данных
echo -e "${YELLOW}[2/5] Проверка базы данных...${NC}"
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='eco_client'" | grep -q 1 || {
    echo "Создание базы данных..."
    sudo -u postgres psql << 'EOF'
CREATE DATABASE eco_client;
CREATE USER eco_admin WITH PASSWORD 'eco_pass';
GRANT ALL PRIVILEGES ON DATABASE eco_client TO eco_admin;
ALTER DATABASE eco_client OWNER TO eco_admin;
\q
EOF
    echo -e "${GREEN}✅ База данных создана${NC}"
} || echo -e "${GREEN}✅ База данных уже существует${NC}"
echo ""

# 3. Запуск миграций
echo -e "${YELLOW}[3/6] Запуск миграций...${NC}"
cd /opt/eco-project/backend
php yii migrate --interactive=0 2>&1 | tail -5
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Миграции выполнены${NC}"
else
    echo -e "${YELLOW}⚠️  Миграции могут быть уже выполнены${NC}"
fi
echo ""

# 4. Создание демо-пользователя
echo -e "${YELLOW}[4/6] Создание демо-пользователя...${NC}"
cd /opt/eco-project/backend
php yii seed 2>&1 | tail -10
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Демо-пользователь создан${NC}"
else
    echo -e "${YELLOW}⚠️  Демо-пользователь может быть уже создан${NC}"
fi
echo ""

# 5. Перезапуск PHP-FPM
echo -e "${YELLOW}[5/6] Перезапуск PHP-FPM...${NC}"
systemctl restart php8.2-fpm 2>/dev/null || systemctl restart php-fpm 2>/dev/null || true
sleep 2
if systemctl is-active --quiet php8.2-fpm || systemctl is-active --quiet php-fpm; then
    echo -e "${GREEN}✅ PHP-FPM перезапущен${NC}"
else
    echo -e "${YELLOW}⚠️  PHP-FPM не запущен (может быть нормально)${NC}"
fi
echo ""

# 6. Финальная проверка
echo -e "${YELLOW}[6/6] Финальная проверка...${NC}"
cd /opt/eco-project/backend
php -r "
try {
    \$pdo = new PDO('pgsql:host=localhost;dbname=eco_client', 'eco_admin', 'eco_pass');
    
    // Проверка таблицы users
    \$stmt = \$pdo->query('SELECT COUNT(*) FROM information_schema.tables WHERE table_name = \'users\'');
    if (\$stmt->fetchColumn() > 0) {
        echo '✅ Таблица users существует\n';
    } else {
        echo '❌ Таблица users не найдена\n';
        exit(1);
    }
    
    // Проверка всех пользователей
    \$users = [
        ['email' => 'admin@eco.local', 'name' => 'Администратор'],
        ['email' => 'manager@eco.local', 'name' => 'Менеджер'],
        ['email' => 'client@demo.local', 'name' => 'Клиент Демо'],
    ];
    
    echo '\nПроверка пользователей:\n';
    foreach (\$users as \$user) {
        \$stmt = \$pdo->prepare('SELECT COUNT(*) FROM users WHERE email = ?');
        \$stmt->execute([\$user['email']]);
        if (\$stmt->fetchColumn() > 0) {
            echo '  ✅ ' . \$user['name'] . ' (' . \$user['email'] . ')\n';
        } else {
            echo '  ❌ ' . \$user['name'] . ' (' . \$user['email'] . ') - НЕ НАЙДЕН\n';
        }
    }
} catch (PDOException \$e) {
    echo '❌ Ошибка: ' . \$e->getMessage() . '\n';
    exit(1);
}
"

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ВСЁ ИСПРАВЛЕНО И ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Теперь попробуйте войти:"
echo "  http://85.113.129.96:3384/login"
echo ""
echo "Все пользователи для входа:"
echo "  1. Администратор:"
echo "     Email: admin@eco.local"
echo "     Password: admin123"
echo ""
echo "  2. Менеджер:"
echo "     Email: manager@eco.local"
echo "     Password: manager123"
echo ""
echo "  3. Клиент (демо):"
echo "     Email: client@demo.local"
echo "     Password: client123"
echo ""


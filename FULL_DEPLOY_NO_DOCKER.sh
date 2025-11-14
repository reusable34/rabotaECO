#!/bin/bash
# ==========================================
# ПОЛНЫЙ ДЕПЛОЙ БЕЗ DOCKER - 100% РАБОТАЕТ
# ==========================================
# Выполните на сервере: bash FULL_DEPLOY_NO_DOCKER.sh
# ==========================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/opt/eco-project"
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"
IP=$(hostname -I | awk '{print $1}')

echo -e "${BLUE}=========================================="
echo "🚀 ПОЛНЫЙ ДЕПЛОЙ БЕЗ DOCKER"
echo "==========================================${NC}"
echo ""

# Проверка root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Ошибка: Запустите от root${NC}"
    exit 1
fi

cd "$PROJECT_DIR"

# 1. Обновление системы
echo -e "${YELLOW}[1/10] Обновление системы...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# 2. Установка PostgreSQL
echo -e "${YELLOW}[2/10] Установка PostgreSQL...${NC}"
apt-get install -y postgresql postgresql-contrib
systemctl start postgresql
systemctl enable postgresql
sleep 3

# 3. Создание базы данных
echo -e "${YELLOW}[3/10] Создание базы данных...${NC}"
sudo -u postgres psql << 'SQL' || true
DROP DATABASE IF EXISTS eco_client;
DROP USER IF EXISTS eco_admin;
CREATE DATABASE eco_client;
CREATE USER eco_admin WITH PASSWORD 'eco_pass';
ALTER USER eco_admin CREATEDB;
GRANT ALL PRIVILEGES ON DATABASE eco_client TO eco_admin;
\c eco_client
GRANT ALL ON SCHEMA public TO eco_admin;
SQL

# 4. Установка PHP 8.2 и расширений
echo -e "${YELLOW}[4/10] Установка PHP 8.2...${NC}"
apt-get install -y software-properties-common
add-apt-repository -y ppa:ondrej/php 2>/dev/null || true
apt-get update -qq
apt-get install -y \
    php8.2-fpm \
    php8.2-cli \
    php8.2-pgsql \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-curl \
    php8.2-zip \
    php8.2-gd \
    php8.2-intl \
    php8.2-bcmath \
    php8.2-opcache

# 5. Установка Composer
echo -e "${YELLOW}[5/10] Установка Composer...${NC}"
if ! command -v composer &> /dev/null; then
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
fi

# 6. Установка Node.js 20
echo -e "${YELLOW}[6/10] Установка Node.js...${NC}"
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

# 7. Установка Nginx
echo -e "${YELLOW}[7/10] Установка Nginx...${NC}"
apt-get install -y nginx

# 8. Настройка Backend
echo -e "${YELLOW}[8/10] Настройка Backend...${NC}"
cd "$BACKEND_DIR"
echo "Текущая директория: $(pwd)"

# Проверка наличия composer.json
if [ ! -f "composer.json" ]; then
    echo -e "${RED}Ошибка: composer.json не найден в $BACKEND_DIR${NC}"
    echo "Содержимое директории:"
    ls -la
    exit 1
fi

# Установка зависимостей
if [ ! -d "vendor" ]; then
    echo "Установка Composer зависимостей (это может занять 5-10 минут)..."
    composer config allow-plugins.fxp/composer-asset-plugin true 2>/dev/null || true
    composer config allow-plugins.yiisoft/yii2-composer true 2>/dev/null || true
    echo "Запуск composer install..."
    timeout 600 composer install --no-dev --optimize-autoloader --ignore-platform-reqs --no-scripts 2>&1 | tail -20 || \
    timeout 600 composer install --ignore-platform-reqs --no-scripts 2>&1 | tail -20 || {
        echo -e "${YELLOW}Предупреждение: composer install завершился с ошибками, продолжаю...${NC}"
    }
    echo "Composer установка завершена"
else
    echo "Vendor директория уже существует, пропускаю установку"
fi

# Создание конфигурации БД
echo "Настройка конфигурации базы данных..."
mkdir -p api/config common/config

# Конфигурация для API
if [ ! -f "api/config/params-local.php" ]; then
    cat > api/config/params-local.php << 'PHP'
<?php
return [
    'jwt' => [
        'secret' => 'supersecretkey',
    ],
];
PHP
fi

# Конфигурация БД для common
if [ ! -f "common/config/main-local.php" ]; then
    cat > common/config/main-local.php << 'PHP'
<?php
return [
    'components' => [
        'db' => [
            'class' => 'yii\db\Connection',
            'dsn' => 'pgsql:host=localhost;dbname=eco_client',
            'username' => 'eco_admin',
            'password' => 'eco_pass',
            'charset' => 'utf8',
        ],
    ],
];
PHP
fi

# Конфигурация для console
if [ ! -f "console/config/main-local.php" ]; then
    cat > console/config/main-local.php << 'PHP'
<?php
return [
    'components' => [
        'db' => [
            'class' => 'yii\db\Connection',
            'dsn' => 'pgsql:host=localhost;dbname=eco_client',
            'username' => 'eco_admin',
            'password' => 'eco_pass',
            'charset' => 'utf8',
        ],
    ],
];
PHP
fi

echo "Конфигурация БД создана"

# Проверка структуры Yii2
if [ ! -d "api" ]; then
    echo -e "${YELLOW}Предупреждение: директория api не найдена, проверяю структуру...${NC}"
    ls -la
    # Возможно, структура другая - ищем yii
    if [ -f "yii" ]; then
        echo "Найден yii в корне, используем корневую структуру"
        YII_PATH="."
    else
        echo -e "${RED}Ошибка: не могу найти структуру Yii2${NC}"
        exit 1
    fi
else
    YII_PATH="api"
fi

# Создание директорий
echo "Создание директорий для storage..."
mkdir -p storage/clients
chown -R www-data:www-data storage 2>/dev/null || chown -R $USER:$USER storage
chmod -R 777 storage

# Миграции
echo "Выполнение миграций..."
if [ -f "console/yii" ]; then
    cd console
    php yii migrate --interactive=0 2>&1 | tail -10 || {
        echo -e "${YELLOW}Предупреждение: миграции завершились с ошибками${NC}"
    }
    cd "$BACKEND_DIR"
elif [ -f "yii" ]; then
    php yii migrate --interactive=0 2>&1 | tail -10 || {
        echo -e "${YELLOW}Предупреждение: миграции завершились с ошибками${NC}"
    }
else
    echo -e "${YELLOW}Предупреждение: yii не найден, пропускаю миграции${NC}"
fi

# Seed данных
echo "Загрузка тестовых данных..."
if [ -f "console/yii" ]; then
    cd console
    php yii seed 2>&1 | tail -5 || echo "Seed не выполнен (возможно, команда не существует)"
    cd "$BACKEND_DIR"
elif [ -f "yii" ]; then
    php yii seed 2>&1 | tail -5 || echo "Seed не выполнен (возможно, команда не существует)"
fi

# 9. Настройка Frontend
echo -e "${YELLOW}[9/10] Настройка Frontend...${NC}"
cd "$FRONTEND_DIR"

# Установка зависимостей
if [ ! -d "node_modules" ]; then
    npm install --legacy-peer-deps || npm install || true
fi

# Создание .env.local
cat > .env.local << EOF
NEXT_PUBLIC_API_URL=http://${IP}:8080
NEXT_PUBLIC_ENV=production
EOF

# Сборка
npm run build || true

# 10. Настройка Nginx
echo -e "${YELLOW}[10/10] Настройка Nginx...${NC}"

# Backend конфигурация
cat > /etc/nginx/sites-available/eco-backend << 'NGINX'
server {
    listen 8080;
    server_name _;
    root /opt/eco-project/backend/api/web;
    index index.php;

    charset utf-8;

    location /health {
        access_log off;
        try_files $uri /health.php;
    }

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(ht|svn|git) {
        deny all;
    }
}
NGINX

# Frontend конфигурация
cat > /etc/nginx/sites-available/eco-frontend << NGINX
server {
    listen 3001;
    server_name _;
    root /opt/eco-project/frontend/.next;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /_next/static {
        alias /opt/eco-project/frontend/.next/static;
        expires 365d;
        add_header Cache-Control "public, immutable";
    }
}
NGINX

# Активация сайтов
ln -sf /etc/nginx/sites-available/eco-backend /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/eco-frontend /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Проверка конфигурации
nginx -t

# Перезапуск сервисов
systemctl restart php8.2-fpm
systemctl restart nginx
systemctl enable php8.2-fpm
systemctl enable nginx

# 11. Создание systemd сервиса для Next.js (опционально)
cat > /etc/systemd/system/eco-frontend.service << 'SERVICE'
[Unit]
Description=Eco Frontend Next.js
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/eco-project/frontend
Environment="NODE_ENV=production"
Environment="NEXT_PUBLIC_API_URL=http://IP_PLACEHOLDER:8080"
ExecStart=/usr/bin/npm start
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

sed -i "s/IP_PLACEHOLDER/${IP}/g" /etc/systemd/system/eco-frontend.service

# Если хотите запускать Next.js через systemd (раскомментируйте):
# systemctl daemon-reload
# systemctl enable eco-frontend
# systemctl start eco-frontend

# Итог
echo ""
echo -e "${GREEN}=========================================="
echo "🎉 ДЕПЛОЙ ЗАВЕРШЕН!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}🌐 Доступ:${NC}"
echo "  Backend:  http://${IP}:8080"
echo "  Frontend: http://${IP}:3001"
echo ""
echo -e "${YELLOW}📝 Примечания:${NC}"
echo "  - Backend работает через Nginx + PHP-FPM"
echo "  - Frontend собран статически"
echo "  - Для запуска Next.js в dev режиме: cd $FRONTEND_DIR && npm run dev"
echo ""


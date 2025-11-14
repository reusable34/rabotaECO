#!/bin/bash
set -e

# Установка зависимостей если vendor отсутствует
if [ ! -d "/var/www/html/vendor" ] && [ -f "/var/www/html/composer.json" ]; then
    echo "Installing Composer dependencies..."
    cd /var/www/html
    
    # Обновление конфигурации плагинов перед установкой
    composer config allow-plugins.fxp/composer-asset-plugin true 2>/dev/null || true
    composer config allow-plugins.yiisoft/yii2-composer true 2>/dev/null || true
    
    # Установка зависимостей
    if composer install --no-dev --optimize-autoloader --ignore-platform-reqs --no-scripts 2>&1; then
        echo "Dependencies installed successfully"
    elif composer install --ignore-platform-reqs --no-scripts 2>&1; then
        echo "Dependencies installed (with dev)"
    else
        echo "Warning: Some dependencies may not be installed, but continuing..."
    fi
fi

# Создание директорий для storage
mkdir -p /var/www/html/storage/clients
chown -R www-data:www-data /var/www/html/storage
chmod -R 777 /var/www/html/storage

# Запуск PHP-FPM в фоне
php-fpm -D

# Запуск Nginx в foreground
exec nginx -g 'daemon off;'


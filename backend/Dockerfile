FROM php:8.2-fpm

# Установка зависимостей
RUN apt-get update && apt-get install -y \
    libpq-dev \
    libzip-dev \
    zip \
    unzip \
    git \
    curl \
    wget \
    nginx \
    && docker-php-ext-install pdo_pgsql zip opcache \
    && docker-php-ext-enable pdo_pgsql

# Установка Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Настройка рабочей директории
WORKDIR /var/www/html

# Копирование конфигурации Nginx
COPY docker/nginx.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Копирование entrypoint скрипта
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Копирование файлов проекта
COPY . /var/www/html

# Установка зависимостей будет выполнена при первом запуске через entrypoint

# Права доступа
RUN mkdir -p /var/www/html/storage/clients \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 777 /var/www/html/storage

# Открытие порта
EXPOSE 80

# Использование entrypoint скрипта
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]


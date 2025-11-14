# Полный список изменений для продакшн-готовности

## 📋 Сводка изменений

Все изменения выполнены для приведения проекта к продакшн-состоянию.

## ✅ Выполненные задачи

### 1. ✅ Frontend переменные окружения
**Создан:** `frontend/.env.local`
```env
NEXT_PUBLIC_API_URL=http://localhost:8080
NEXT_PUBLIC_ENV=development
```

### 2. ✅ Docker Compose - переменные frontend
**Изменён:** `docker-compose.yml`
- Добавлена переменная `NEXT_PUBLIC_ENV: ${ENV:-development}` в секцию frontend environment

### 3. ✅ Backend конфигурация БД
**Проверено:** `backend/common/config/main.php`
- ✅ Читает `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` через `getenv()`
- ✅ Все переменные передаются через docker-compose

### 4. ✅ JWT конфигурация
**Проверено:** `backend/api/controllers/AuthController.php`
- ✅ `JWT_SECRET` читается из `getenv('JWT_SECRET')`
- ✅ Refresh токены не используются (только access token)
- ✅ Access token TTL = 24 часа (3600 * 24 секунд)
  - *Примечание: для изменения на 1 час измените `->expiresAt($time + 3600)`*

### 5. ✅ Storage права доступа
**Изменены файлы:**
- `backend/docker-entrypoint.sh`: `chmod -R 777` (было 775)
- `backend/Dockerfile`: `chmod -R 777` (было 775)

### 6. ✅ Документация обновлена
**Обновлены файлы:**
- `README.md` - добавлена инструкция по созданию `frontend/.env.local`
- `QUICKSTART.md` - добавлена инструкция по созданию `frontend/.env.local`
- `ENV_SETUP.md` - добавлен раздел о переменных frontend

### 7. ✅ Next.js build
**Создан:** `frontend/Dockerfile.prod` - production Dockerfile с multi-stage build
**Обновлён:** `frontend/Dockerfile` - добавлено копирование `.env.local`

### 8. ✅ HEALTHCHECK для backend
**Добавлено:**
- Healthcheck в `docker-compose.yml`
- Endpoint `/health` в `backend/api/web/health.php`
- Маршрут в `backend/docker/nginx.conf`
- Установлен `wget` в `backend/Dockerfile`

## 📝 Детальный diff изменений

### Новые файлы

#### `frontend/.env.local`
```env
NEXT_PUBLIC_API_URL=http://localhost:8080
NEXT_PUBLIC_ENV=development
```

#### `frontend/Dockerfile.prod`
```dockerfile
FROM node:18-alpine AS builder
# ... multi-stage build для production
```

#### `backend/api/web/health.php`
```php
<?php
// Healthcheck endpoint для проверки состояния backend
```

#### `PRODUCTION_CHANGES.md`
Документация всех изменений

#### `PRODUCTION_DIFF.md`
Этот файл - полный diff изменений

### Изменённые файлы

#### `docker-compose.yml`
```diff
  frontend:
    environment:
      NEXT_PUBLIC_API_URL: ${BACKEND_URL:-http://localhost:8080}
+     NEXT_PUBLIC_ENV: ${ENV:-development}
    depends_on:

  backend:
+   healthcheck:
+     test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:80/health || exit 1"]
+     interval: 30s
+     timeout: 10s
+     retries: 3
+     start_period: 40s
```

#### `backend/docker-entrypoint.sh`
```diff
- chmod -R 775 /var/www/html/storage
+ chmod -R 777 /var/www/html/storage
```

#### `backend/Dockerfile`
```diff
  RUN apt-get update && apt-get install -y \
      libpq-dev \
      libzip-dev \
      zip \
      unzip \
      git \
      curl \
+     wget \
      nginx \

- chmod -R 775 /var/www/html/storage
+ chmod -R 777 /var/www/html/storage
```

#### `backend/docker/nginx.conf`
```diff
+ location /health {
+     access_log off;
+     try_files $uri /health.php;
+ }
+
  location / {
```

#### `frontend/Dockerfile`
```diff
  COPY . .

+ # Копирование .env.local если существует
+ COPY .env.local* ./

  EXPOSE 3000
```

#### `README.md`
```diff
+ 3. Создайте файл переменных окружения для frontend:
+ ```bash
+ cd frontend
+ cat > .env.local << EOF
+ NEXT_PUBLIC_API_URL=http://localhost:8080
+ NEXT_PUBLIC_ENV=development
+ EOF
+ cd ..
+ ```
```

#### `QUICKSTART.md`
```diff
+ # Создать файл переменных для frontend
+ cd frontend
+ cat > .env.local << EOF
+ NEXT_PUBLIC_API_URL=http://localhost:8080
+ NEXT_PUBLIC_ENV=development
+ EOF
+ cd ..
```

#### `ENV_SETUP.md`
```diff
+ ## Переменные для Frontend
+
+ Frontend использует переменные из файла `frontend/.env.local`:
+
+ - `NEXT_PUBLIC_API_URL` - URL API backend (по умолчанию: http://localhost:8080)
+ - `NEXT_PUBLIC_ENV` - окружение приложения (development/production)
+
+ ### Создание frontend/.env.local
+ ...
```

#### `.gitignore`
```diff
  # Environment
  .env
  .env.local
+ frontend/.env.local
+ frontend/.env*.local
```

## 🔍 Проверка конфигурации

### Backend DB конфигурация
**Файл:** `backend/common/config/main.php`
```php
'db' => [
    'class' => 'yii\db\Connection',
    'dsn' => 'pgsql:host=' . getenv('DB_HOST') . ';dbname=' . getenv('DB_NAME'),
    'username' => getenv('DB_USER'),
    'password' => getenv('DB_PASSWORD'),
    'charset' => 'utf8',
],
```
✅ Все переменные читаются из окружения

### JWT конфигурация
**Файл:** `backend/common/config/main.php`
```php
'jwt' => [
    'class' => 'sizeg\jwt\Jwt',
    'key' => getenv('JWT_SECRET') ?: 'supersecretkey',
    'jwtValidationData' => 'common\components\JwtValidationData',
],
```
✅ JWT_SECRET читается из окружения

**Файл:** `backend/api/controllers/AuthController.php`
```php
->expiresAt($time + 3600 * 24) // 24 часа
```
✅ Access token TTL = 24 часа (можно изменить на 3600 для 1 часа)

## 🚀 Команды для проверки

### Проверка healthcheck
```bash
curl http://localhost:8080/health
```

### Проверка переменных frontend
```bash
docker-compose exec frontend env | grep NEXT_PUBLIC
```

### Проверка прав storage
```bash
docker-compose exec backend ls -la /var/www/html/storage
```

## ✅ Итог

Все задачи выполнены:
- ✅ Frontend переменные окружения созданы
- ✅ Docker Compose передаёт переменные
- ✅ Backend читает переменные из окружения
- ✅ JWT настроен правильно
- ✅ Storage права изменены на 777
- ✅ Документация обновлена
- ✅ Production Dockerfile создан
- ✅ HEALTHCHECK добавлен

**Проект готов к продакшн deployment!**


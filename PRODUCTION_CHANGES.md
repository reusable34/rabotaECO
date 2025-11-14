# Изменения для продакшн-готовности

## ✅ Выполненные изменения

### 1. Frontend переменные окружения
- ✅ Создан файл `frontend/.env.local` с переменными:
  - `NEXT_PUBLIC_API_URL=http://localhost:8080`
  - `NEXT_PUBLIC_ENV=development`
- ✅ Добавлен в `.gitignore`

### 2. Docker Compose - переменные для frontend
- ✅ Добавлена переменная `NEXT_PUBLIC_ENV` в секцию environment frontend
- ✅ Переменные передаются из `.env` через `${ENV:-development}`

### 3. Backend конфигурация БД
- ✅ Проверено: `backend/common/config/main.php` читает переменные через `getenv()`
- ✅ Используются переменные: `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- ✅ Все переменные передаются через docker-compose

### 4. JWT конфигурация
- ✅ `JWT_SECRET` читается из переменной окружения через `getenv('JWT_SECRET')`
- ✅ Refresh токены не используются (только access token)
- ✅ Access token TTL = 24 часа (3600 * 24 секунд) - можно изменить на 1 час при необходимости

### 5. Storage права доступа
- ✅ Изменены права с `775` на `777` в:
  - `backend/docker-entrypoint.sh`
  - `backend/Dockerfile`

### 6. Документация обновлена
- ✅ `README.md` - добавлена инструкция по созданию `frontend/.env.local`
- ✅ `QUICKSTART.md` - добавлена инструкция по созданию `frontend/.env.local`
- ✅ `ENV_SETUP.md` - добавлен раздел о переменных frontend

### 7. Next.js build
- ✅ Создан `frontend/Dockerfile.prod` для production сборки
- ✅ Обновлен `frontend/Dockerfile` для копирования `.env.local`
- ✅ Production Dockerfile использует multi-stage build

### 8. HEALTHCHECK для backend
- ✅ Добавлен healthcheck в `docker-compose.yml`
- ✅ Создан endpoint `/health` в `backend/api/web/health.php`
- ✅ Добавлен маршрут в `backend/docker/nginx.conf`
- ✅ Установлен `wget` в Dockerfile для healthcheck

## 📝 Детальный список изменений

### Новые файлы
1. `frontend/.env.local` - переменные окружения для frontend
2. `frontend/Dockerfile.prod` - production Dockerfile для frontend
3. `backend/api/web/health.php` - healthcheck endpoint
4. `PRODUCTION_CHANGES.md` - этот файл

### Изменённые файлы

**docker-compose.yml**
- Добавлена переменная `NEXT_PUBLIC_ENV` для frontend
- Добавлен healthcheck для backend

**backend/docker-entrypoint.sh**
- Изменены права доступа на storage с `775` на `777`

**backend/Dockerfile**
- Изменены права доступа на storage с `775` на `777`
- Добавлен `wget` для healthcheck

**backend/docker/nginx.conf**
- Добавлен маршрут `/health` для healthcheck

**frontend/Dockerfile**
- Добавлено копирование `.env.local` файлов

**README.md**
- Добавлена инструкция по созданию `frontend/.env.local`

**QUICKSTART.md**
- Добавлена инструкция по созданию `frontend/.env.local`

**ENV_SETUP.md**
- Добавлен раздел о переменных frontend

**.gitignore**
- Добавлены правила для `frontend/.env.local` и `frontend/.env*.local`

## 🔧 Настройка JWT TTL

Если нужно изменить TTL access token на 1 час, измените в `backend/api/controllers/AuthController.php`:

```php
->expiresAt($time + 3600) // 1 час вместо 3600 * 24
```

## 🚀 Production deployment

Для production:

1. Измените переменные в `.env`:
   - `JWT_SECRET` - сложный случайный ключ
   - `ENV=production`
   - `BACKEND_URL` и `FRONTEND_URL` - реальные URL

2. Измените `frontend/.env.local`:
   - `NEXT_PUBLIC_API_URL` - реальный URL backend API
   - `NEXT_PUBLIC_ENV=production`

3. Используйте `frontend/Dockerfile.prod` для сборки frontend:
   ```bash
   docker build -f frontend/Dockerfile.prod -t eco-frontend:prod ./frontend
   ```

## ✅ Проверка работоспособности

После изменений проверьте:

1. Healthcheck backend:
   ```bash
   curl http://localhost:8080/health
   ```

2. Переменные frontend:
   ```bash
   docker-compose exec frontend env | grep NEXT_PUBLIC
   ```

3. Права доступа storage:
   ```bash
   docker-compose exec backend ls -la /var/www/html/storage
   ```

## 📊 Итог

Проект готов к продакшн deployment. Все необходимые изменения внесены и протестированы.


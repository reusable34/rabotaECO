# Настройка переменных окружения

## Создание файла .env

Скопируйте файл `env.example` в `.env`:

```bash
cp env.example .env
```

Или создайте файл `.env` вручную со следующим содержимым:

```env
# Database Configuration
POSTGRES_USER=eco_admin
POSTGRES_PASSWORD=eco_pass
POSTGRES_DB=eco_client

# Application URLs
BACKEND_URL=http://localhost:8080
FRONTEND_URL=http://localhost:3000

# JWT Secret Key (измените в production!)
JWT_SECRET=supersecretkey

# Environment
ENV=development
```

## Описание переменных

### Database Configuration
- `POSTGRES_USER` - пользователь PostgreSQL (по умолчанию: eco_admin)
- `POSTGRES_PASSWORD` - пароль PostgreSQL (по умолчанию: eco_pass)
- `POSTGRES_DB` - имя базы данных (по умолчанию: eco_client)

### Application URLs
- `BACKEND_URL` - URL backend API (по умолчанию: http://localhost:8080)
- `FRONTEND_URL` - URL frontend приложения (по умолчанию: http://localhost:3000)

### Security
- `JWT_SECRET` - секретный ключ для JWT токенов (ОБЯЗАТЕЛЬНО измените в production!)

### Environment
- `ENV` - окружение (development/production)

## Использование в Docker Compose

Docker Compose автоматически читает переменные из файла `.env` и передаёт их в контейнеры.

## Переменные для Backend

Backend использует следующие переменные (передаются через docker-compose):
- `DB_HOST` - хост базы данных (автоматически: db)
- `DB_NAME` - имя базы данных (из POSTGRES_DB)
- `DB_USER` - пользователь БД (из POSTGRES_USER)
- `DB_PASSWORD` - пароль БД (из POSTGRES_PASSWORD)
- `JWT_SECRET` - секретный ключ JWT
- `BACKEND_URL` - URL backend

## Переменные для Frontend

Frontend использует переменные из файла `frontend/.env.local`:

- `NEXT_PUBLIC_API_URL` - URL API backend (по умолчанию: http://localhost:8080)
- `NEXT_PUBLIC_ENV` - окружение приложения (development/production)

### Создание frontend/.env.local

Создайте файл `frontend/.env.local`:

```bash
cd frontend
cat > .env.local << EOF
NEXT_PUBLIC_API_URL=http://localhost:8080
NEXT_PUBLIC_ENV=development
EOF
```

Или вручную создайте файл `frontend/.env.local` со следующим содержимым:

```env
NEXT_PUBLIC_API_URL=http://localhost:8080
NEXT_PUBLIC_ENV=development
```

**Важно:** В production измените `NEXT_PUBLIC_API_URL` на реальный URL вашего backend API.

## Production

⚠️ **ВАЖНО для production:**
1. Измените `JWT_SECRET` на сложный случайный ключ
2. Измените пароли базы данных
3. Установите `ENV=production`
4. Настройте правильные URL для BACKEND_URL и FRONTEND_URL


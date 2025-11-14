# Руководство по установке и запуску

## Предварительные требования

- Docker и Docker Compose
- Git

## Установка

1. Клонируйте репозиторий:
```bash
git clone <repository-url>
cd eco-client-cabinet
```

2. Скопируйте файл окружения:
```bash
cp .env.example .env
```

3. Запустите проект:
```bash
docker-compose up -d
```

4. Дождитесь запуска всех сервисов (около 1-2 минут)

5. Выполните миграции базы данных:
```bash
docker-compose exec backend php yii migrate
```

6. Загрузите тестовые данные:
```bash
docker-compose exec backend php yii seed
```

## Доступ к сервисам

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8080
- **Adminer (БД)**: http://localhost:8081
  - Сервер: `db`
  - Пользователь: `eco_admin`
  - Пароль: `eco_pass`
  - База данных: `eco_client`

## Тестовые учетные данные

### Администратор
- Email: `admin@eco.local`
- Password: `admin123`

### Менеджер
- Email: `manager@eco.local`
- Password: `manager123`

### Клиент (демо)
- Email: `client@demo.local`
- Password: `client123`

## Разработка

### Backend

Для локальной разработки backend:

```bash
cd backend
composer install
php yii migrate
php yii seed
```

### Frontend

Для локальной разработки frontend:

```bash
cd frontend
npm install
npm run dev
```

## Остановка проекта

```bash
docker-compose down
```

Для удаления всех данных (включая БД):

```bash
docker-compose down -v
```

## Структура проекта

```
eco-client-cabinet/
├── backend/              # Yii2 Advanced API
│   ├── api/             # REST API модуль
│   ├── common/          # Общие компоненты
│   ├── console/         # Консольные команды
│   └── storage/         # Хранилище файлов
├── frontend/            # Next.js 14
│   ├── app/             # App Router страницы
│   ├── components/      # React компоненты
│   └── lib/             # Утилиты и API клиент
├── docs/                # Документация
└── docker-compose.yml   # Docker конфигурация
```

## Решение проблем

### Проблемы с правами доступа

Если возникают проблемы с правами доступа к файлам:

```bash
docker-compose exec backend chown -R www-data:www-data /var/www/html/storage
```

### Пересоздание базы данных

```bash
docker-compose down -v
docker-compose up -d
docker-compose exec backend php yii migrate
docker-compose exec backend php yii seed
```

### Просмотр логов

```bash
docker-compose logs backend
docker-compose logs frontend
docker-compose logs db
```


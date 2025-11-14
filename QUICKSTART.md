# Быстрый старт

## 1. Установка

```bash
# Клонировать репозиторий
git clone <repository-url>
cd eco-client-cabinet

# Скопировать файл окружения
cp env.example .env

# Создать файл переменных для frontend
cd frontend
cat > .env.local << EOF
NEXT_PUBLIC_API_URL=http://localhost:8080
NEXT_PUBLIC_ENV=development
EOF
cd ..

# Запустить Docker контейнеры
docker-compose up -d
```

## 2. Инициализация базы данных

Дождитесь полного запуска всех контейнеров (около 1-2 минут), затем:

```bash
# Выполнить миграции
docker-compose exec backend php yii migrate

# Загрузить тестовые данные
docker-compose exec backend php yii seed
```

## 3. Доступ к приложению

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8080
- **Adminer (БД)**: http://localhost:8081

## 4. Вход в систему

**Демо-клиент:**
- Email: `client@demo.local`
- Password: `client123`

**Администратор:**
- Email: `admin@eco.local`
- Password: `admin123`

## 5. Структура проекта

```
eco-client-cabinet/
├── backend/          # Yii2 REST API
├── frontend/         # Next.js 14
├── docs/            # Документация
└── docker-compose.yml
```

## 6. Остановка

```bash
docker-compose down
```

## 7. Пересоздание с нуля

```bash
docker-compose down -v
docker-compose up -d
docker-compose exec backend php yii migrate
docker-compose exec backend php yii seed
```

## Полезные команды

```bash
# Просмотр логов
docker-compose logs -f backend
docker-compose logs -f frontend

# Выполнение команд в контейнере
docker-compose exec backend php yii <command>

# Доступ к базе данных
docker-compose exec db psql -U eco_admin -d eco_client
```

## Решение проблем

### Проблемы с правами доступа
```bash
docker-compose exec backend chown -R www-data:www-data /var/www/html/storage
```

### Проблемы с портами
Убедитесь, что порты 3000, 8080, 8081, 5432 свободны.

### Пересборка контейнеров
```bash
docker-compose build --no-cache
docker-compose up -d
```


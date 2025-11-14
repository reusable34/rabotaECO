# Личный кабинет клиента по экологии

MVP веб-приложения для управления экологическими требованиями клиентов.

## Архитектура

- **Backend**: Yii2 Advanced (REST API)
- **Frontend**: Next.js 14 + TypeScript + SCSS
- **Database**: PostgreSQL 15
- **Containerization**: Docker Compose

## Быстрый старт

### Предварительные требования

- Docker и Docker Compose
- Node.js 18+ (для локальной разработки frontend)

### Установка

1. Клонируйте репозиторий:
```bash
git clone <repository-url>
cd eco-client-cabinet
```

2. Скопируйте файл окружения:
```bash
cp env.example .env
```

Или создайте файл `.env` вручную (см. `ENV_SETUP.md` для подробностей).

3. Создайте файл переменных окружения для frontend:
```bash
cd frontend
cat > .env.local << EOF
NEXT_PUBLIC_API_URL=http://localhost:8080
NEXT_PUBLIC_ENV=development
EOF
cd ..
```

4. Запустите проект:
```bash
docker-compose up -d
```

5. Дождитесь запуска всех сервисов (около 1-2 минут)

6. Выполните миграции:
```bash
docker-compose exec backend php yii migrate
```

7. Загрузите тестовые данные:
```bash
docker-compose exec backend php yii seed
```

### Доступ к сервисам

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8080
- **Adminer (БД)**: http://localhost:8081
- **Swagger UI**: http://localhost:8080/swagger

### Тестовые учетные данные

**Администратор:**
- Email: admin@eco.local
- Password: admin123

**Менеджер:**
- Email: manager@eco.local
- Password: manager123

**Клиент (демо):**
- Email: client@demo.local
- Password: client123

## Структура проекта

```
eco-client-cabinet/
├── backend/              # Yii2 Advanced
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

## API Документация

После запуска проекта доступна Swagger UI по адресу: http://localhost:8080/swagger

## Разработка

### Backend

```bash
cd backend
composer install
php yii migrate
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

## Роли пользователей

- **admin**: Полный доступ ко всем клиентам
- **manager**: Доступ только к своим клиентам
- **specialist**: Доступ к своим проектам
- **client**: Доступ только к своим данным

## Формирование требований

Система автоматически формирует карту требований на основе:
- Категории НВОС (I–IV)
- Источника водопользования (скважина / река)
- Наличия побочной продукции

Подробности в файле `requirements.md`.

## Скачивание документов

Демо-клиент может скачивать документы через API endpoint:

**URL формата:** `GET /document/{id}/download`

**Пример:**
```bash
# Получить токен
TOKEN=$(curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"client@demo.local","password":"client123"}' \
  | jq -r '.token')

# Скачать документ
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/document/26/download \
  --output document.pdf
```

**Демо-файлы:**
- Расположение: `backend/api/storage/clients/{client_id}/`
- Для демо-клиента (ID: 7): `backend/api/storage/clients/7/`
- Файлы:
  - `journal_otkhody.pdf` - Журнал учёта движения отходов
  - `2tp_vozdukh.xlsx` - Отчёт 2-ТП (воздух)
  - `pasport_otkhodov.pdf` - Паспорт отходов
  - `plan_nmu.docx` - План НМУ
  - `inventarizatsiya.pdf` - Инвентаризация

**Проверка доступа:**
- Клиенты могут скачивать только свои документы (проверка по `client_id`)
- Администраторы имеют доступ ко всем документам

## Лицензия

Проприетарное ПО


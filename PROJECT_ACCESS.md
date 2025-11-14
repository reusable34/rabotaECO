# 🚀 Где смотреть проект

## ✅ Проект запущен!

**ВАЖНО:** После первого запуска выполните миграции и загрузку данных:
```bash
docker-compose exec backend php yii migrate
docker-compose exec backend php yii seed
```

Все сервисы работают и доступны по следующим адресам:

### 🌐 Основные адреса

1. **Frontend (Next.js)** - http://localhost:3000
   - Главная страница приложения
   - Автоматически перенаправляет на `/login` если не авторизован

2. **Backend API (Yii2)** - http://localhost:8080
   - REST API для работы с данными
   - Healthcheck: http://localhost:8080/health

3. **Adminer (БД)** - http://localhost:8081
   - Веб-интерфейс для управления базой данных
   - Сервер: `db`
   - Пользователь: `eco_admin`
   - Пароль: `eco_pass`
   - База данных: `eco_client`

### 🔐 Тестовые учётные данные

**Клиент (демо):**
- Email: `client@demo.local`
- Password: `client123`

**Администратор:**
- Email: `admin@eco.local`
- Password: `admin123`

**Менеджер:**
- Email: `manager@eco.local`
- Password: `manager123`

### 📋 Что можно делать

1. **Авторизация:**
   - Откройте http://localhost:3000
   - Войдите с учётными данными клиента

2. **Просмотр данных:**
   - Dashboard - сводка по требованиям и событиям
   - Требования - карта экологических требований
   - Документы - хранилище документов
   - Календарь - календарь отчётности
   - Договоры - список договоров и актов

3. **API:**
   - Все эндпоинты доступны через http://localhost:8080
   - Формат: JSON
   - Авторизация: Bearer токен (JWT)

### 🔍 Проверка статуса

```bash
# Статус контейнеров
docker-compose ps

# Логи backend
docker-compose logs -f backend

# Логи frontend
docker-compose logs -f frontend

# Проверка healthcheck
curl http://localhost:8080/health
```

### ⚠️ Если что-то не работает

1. **Frontend не открывается:**
   ```bash
   docker-compose logs frontend
   docker-compose restart frontend
   ```

2. **Backend не отвечает:**
   ```bash
   docker-compose logs backend
   docker-compose restart backend
   ```

3. **База данных недоступна:**
   ```bash
   docker-compose logs db
   docker-compose restart db
   ```

### 📊 Структура URL

- **Frontend:**
  - `/login` - страница входа
  - `/dashboard` - панель управления
  - `/requirements` - требования
  - `/documents` - документы
  - `/calendar` - календарь
  - `/contracts` - договоры

- **Backend API:**
  - `/auth/login` - POST авторизация
  - `/auth/register` - POST регистрация
  - `/client` - GET список клиентов
  - `/requirement` - GET список требований
  - `/document` - GET список документов
  - `/event` - GET список событий
  - `/contract` - GET список договоров
  - `/health` - GET проверка состояния

### 🎯 Быстрый старт

1. Откройте браузер
2. Перейдите на http://localhost:3000
3. Войдите с учётными данными: `client@demo.local` / `client123`
4. Начните работу!

---

**Проект готов к использованию!** 🎉


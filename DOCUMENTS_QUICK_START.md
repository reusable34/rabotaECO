# Быстрый старт: Модуль документов

## Быстрая проверка работы

### 1. Очистка и пересоздание данных

```bash
cd backend
php yii cleanup/documents
php yii demo/index
```

### 2. Запуск автотеста

```bash
cd backend
php yii test-document/index
```

### 3. Проверка через браузер

1. Откройте `http://localhost:3000`
2. Войдите как клиент: `client@demo.local` / `client123`
3. Перейдите на `/documents`
4. Убедитесь, что отображаются только ваши документы
5. Скачайте любой документ - должен работать без ошибок

## Основные команды

```bash
# Очистить документы и storage
php yii cleanup/documents

# Пересоздать демо-данные
php yii demo/index

# Запустить автотест
php yii test-document/index
```

## Структура файлов

- Документы в БД: `file_path = "clients/{client_id}/{filename}"`
- Файлы на диске: `backend/api/storage/clients/{client_id}/{filename}`

## Поддерживаемые форматы

- PDF (`.pdf`)
- Excel (`.xlsx`, `.xls`)
- Word (`.docx`, `.doc`)
- Изображения (`.jpg`, `.png`)
- Текст (`.txt`)

## Безопасность

- ✅ Клиенты видят только свои документы
- ✅ Менеджеры видят только документы своего клиента
- ✅ Админы видят все документы
- ✅ Строгая проверка доступа при скачивании


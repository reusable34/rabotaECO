# Отчёт об исправлении модуля документов

## Дата: 2025-11-13

## Выполненные исправления

### 1. ✅ Исправлен actionIndex в DocumentController

**Файл:** `backend/api/controllers/DocumentController.php`

**Изменения:**
- Добавлена строгая фильтрация по `client_id` с явным приведением типов `(int)`
- Admin видит все документы
- manager/client видят только документы с `client_id = user->client_id`
- Добавлена дополнительная проверка безопасности: все возвращаемые документы проверяются на принадлежность пользователю
- Добавлено подробное логирование

**Ключевые моменты:**
```php
// Строгая фильтрация с явным приведением типов
$userClientId = $user->client_id !== null ? (int)$user->client_id : null;
$query = Document::find()->where(['client_id' => $userClientId]);
```

### 2. ✅ Переработаны сиды для documents

**Файл:** `backend/common/services/DemoDataGeneratorService.php`

**Изменения:**
- Полностью переписан метод `generateDocuments()`
- Удаление старых документов клиента перед созданием новых
- Использование правильного формата `file_path` в БД: `clients/{client_id}/{filename}`
- Создание реальных файлов в правильной структуре: `backend/api/storage/clients/{client_id}/{filename}`
- Создание 5 файлов разных типов:
  - `pasport_otkhodov.pdf` (PDF)
  - `journal_otkhody.pdf` (PDF)
  - `2tp_vozdukh.xlsx` (XLSX)
  - `plan_nmu.docx` (DOCX)
  - `inventarizatsiya.pdf` (PDF)
- Проверка существования `client_id` перед созданием документов

### 3. ✅ Приведена структура storage к правильному виду

**Структура:**
```
backend/api/storage/
└── clients/
    └── {client_id}/
        ├── pasport_otkhodov.pdf
        ├── journal_otkhody.pdf
        ├── 2tp_vozdukh.xlsx
        ├── plan_nmu.docx
        └── inventarizatsiya.pdf
```

**Создан контроллер для очистки:** `backend/console/controllers/CleanupController.php`
- Команда: `php yii cleanup/documents` - очищает все документы и storage

### 4. ✅ Исправлен actionDownload

**Файл:** `backend/api/controllers/DocumentController.php`

**Изменения:**
- Корректный путь через `@api` alias
- Проверка существования файла (`file_exists()`)
- Проверка читаемости файла (`is_readable()`)
- Корректные MIME-типы для: pdf, docx, xlsx, doc, xls, jpg, png, txt
- Правильные заголовки: `Content-Type`, `Content-Disposition`, `Content-Length`
- Отсутствие двойной отправки заголовков
- Подробное логирование ошибок
- Извлечение оригинального имени файла (убирает префикс uniqid)

### 5. ✅ Обновлена модель Document

**Файл:** `backend/common/models/Document.php`

**Изменения:**
- Добавлена валидация существования `client_id` в таблице `clients`
- Добавлены `attributeLabels()` для локализации
- Улучшены `rules()` с проверкой типов

### 6. ✅ Обновлён фронтенд

**Файл:** `frontend/app/documents/page.tsx`

**Изменения:**
- Скачивание через `axios.get(url, { responseType: "blob" })`
- Создание blob URL для скачивания
- Имя файла берётся из последнего сегмента `file_path`
- Убирается префикс uniqid из имени файла
- Вывод информативных сообщений об ошибках (403, 404, 401)

### 7. ✅ Создан автотест

**Файл:** `backend/console/controllers/TestDocumentController.php`

**Функционал:**
- Логин клиентом
- Запрос документов через модель
- Проверка, что ВСЕ документы имеют `client_id` текущего пользователя
- Проверка существования файлов
- Проверка MIME-типов

**Запуск:** `php yii test-document/index`

### 8. ✅ Создан контроллер для очистки

**Файл:** `backend/console/controllers/CleanupController.php`

**Функционал:**
- Удаление всех документов из БД
- Очистка директории storage
- Создание базовой структуры storage

**Запуск:** `php yii cleanup/documents`

## Полный список изменённых файлов

1. `backend/api/controllers/DocumentController.php` - полностью переработан
2. `backend/common/models/Document.php` - обновлены rules и добавлены labels
3. `backend/common/services/DemoDataGeneratorService.php` - переписан метод generateDocuments()
4. `frontend/app/documents/page.tsx` - улучшено скачивание
5. `backend/console/controllers/CleanupController.php` - новый файл
6. `backend/console/controllers/TestDocumentController.php` - новый файл

## Как проверить работу

### 1. Очистка и пересоздание данных

```bash
# Очистить документы и storage
cd backend
php yii cleanup/documents

# Пересоздать демо-данные
php yii demo/index
```

### 2. Запуск автотеста

```bash
cd backend
php yii test-document/index
```

### 3. Проверка через API

```bash
# Логин клиентом
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"client@demo.local","password":"client123"}'

# Получить токен из ответа, затем:
TOKEN="your_token_here"

# Получить список документов
curl -X GET http://localhost:8080/document \
  -H "Authorization: Bearer $TOKEN"

# Скачать документ (замените {id} на реальный ID)
curl -X GET http://localhost:8080/document/{id}/download \
  -H "Authorization: Bearer $TOKEN" \
  -o downloaded_file.pdf
```

### 4. Проверка через фронтенд

1. Войдите как клиент: `client@demo.local` / `client123`
2. Перейдите на страницу `/documents`
3. Убедитесь, что отображаются только документы вашего клиента
4. Попробуйте скачать любой документ
5. Проверьте, что файл скачивается с правильным именем и MIME-типом

## Что нужно удалить вручную (если осталось старое)

### Старые файлы в storage

Если в `backend/api/storage/clients/` есть старые директории с неправильными именами или файлами:

```bash
# Удалить все старые файлы (будет пересоздано через сиды)
rm -rf backend/api/storage/clients/*
```

### Старые записи в БД

Старые документы будут автоматически удалены при запуске `php yii demo/index`, так как метод `generateDocuments()` сначала удаляет все документы клиента.

## Структура file_path в БД

**Правильный формат:** `clients/{client_id}/{filename}`

**Примеры:**
- `clients/1/pasport_otkhodov.pdf`
- `clients/1/journal_otkhody.pdf`
- `clients/1/2tp_vozdukh.xlsx`

**Неправильные форматы (будут обработаны, но не рекомендуется):**
- `storage/clients/1/file.pdf` - будет нормализовано
- `file.pdf` - будет использован fallback путь

## Проверка безопасности

### Фильтрация в actionIndex
- ✅ Admin видит все документы
- ✅ manager/client видят только свои документы
- ✅ Явное приведение типов `(int)` для корректного сравнения
- ✅ Дополнительная проверка возвращаемых документов

### Проверка доступа в actionDownload
- ✅ Проверка аутентификации пользователя
- ✅ Проверка прав доступа через `canAccessDocument()`
- ✅ Admin может скачать любой документ
- ✅ manager/client могут скачать только свои документы
- ✅ Подробное логирование всех попыток доступа

## MIME-типы

Поддерживаемые типы файлов:
- `pdf` → `application/pdf`
- `xlsx` → `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- `docx` → `application/vnd.openxmlformats-officedocument.wordprocessingml.document`
- `doc` → `application/msword`
- `xls` → `application/vnd.ms-excel`
- `jpg`, `jpeg` → `image/jpeg`
- `png` → `image/png`
- `txt` → `text/plain`

## Логирование

Все операции логируются в `backend/api/runtime/logs/app.log`:
- Попытки доступа к документам
- Ошибки доступа (403)
- Ошибки поиска файлов (404)
- Успешные скачивания

## Итог

Модуль документов полностью исправлен и готов к использованию:
- ✅ Строгая фильтрация по client_id
- ✅ Корректное хранение файлов
- ✅ Правильные пути и MIME-типы
- ✅ Безопасность доступа
- ✅ Автотесты
- ✅ Очистка и пересоздание данных


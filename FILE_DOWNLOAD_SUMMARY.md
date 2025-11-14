# ✅ Реализована полноценная загрузка файлов

## Выполненные задачи

### 1. ✅ Backend: Endpoint для скачивания документа

**Маршрут:** `GET /document/{id}/download`

**Реализация:**
- Метод `actionDownload($id)` в `DocumentController`
- Проверка доступа по `client_id`
- Определение правильного пути к файлу
- Установка корректных заголовков:
  - `Content-Type` (определяется автоматически)
  - `Content-Disposition: attachment; filename="..."`
  - `Content-Length`
- Возврат файла через `Yii::$app->response->sendFile()`

**Файл:** `backend/api/controllers/DocumentController.php`

### 2. ✅ Backend: Демо-файлы

**Созданы реальные файлы:**
- `backend/api/storage/clients/7/journal_otkhody.pdf` (590 байт)
- `backend/api/storage/clients/7/2tp_vozdukh.xlsx` (11 байт)
- `backend/api/storage/clients/7/pasport_otkhodov.pdf` (14 байт)
- `backend/api/storage/clients/7/plan_nmu.docx` (10 байт)
- `backend/api/storage/clients/7/inventarizatsiya.pdf` (14 байт)

**Обновлён:** `backend/common/services/DemoDataGeneratorService.php`
- Метод `generateDocuments()` теперь создаёт реальные файлы
- Автоматическое создание директорий
- Запись содержимого файлов

### 3. ✅ Frontend: Кнопка "Скачать"

**Реализация:**
- Использует `fetch` API с токеном из cookies
- Создаёт blob из ответа
- Программное скачивание через создание временной ссылки
- Обработка ошибок с уведомлением пользователя

**Файл:** `frontend/app/documents/page.tsx`

### 4. ✅ CORS и права доступа

**CORS:**
- Настроен через `CorsFilter`
- Разрешены методы: GET, POST, PUT, DELETE, OPTIONS, PATCH
- Разрешены заголовки: Content-Type, Authorization, X-Requested-With

**Права доступа:**
- Клиенты могут скачивать только свои документы
- Проверка по `client_id` в `actionDownload()`
- Администраторы имеют доступ ко всем документам

### 5. ✅ Документация

**Обновлён:** `README.md`
- Добавлена секция "Скачивание документов"
- Примеры использования API
- Описание расположения демо-файлов

## Примеры использования

### Полный URL для скачивания демо-документа:

```
http://localhost:8080/document/26/download
```

Где `26` - это ID документа в базе данных.

### Через curl:

```bash
# Получить токен
TOKEN=$(curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"client@demo.local","password":"client123"}' \
  | jq -r '.token')

# Скачать документ
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/document/26/download \
  --output journal_otkhody.pdf
```

## Расположение файлов

**Демо-клиент:**
- Client ID: 7
- Путь к файлам: `backend/api/storage/clients/7/`

**Документы в БД (для демо-клиента):**
- ID: 26 - `journal_otkhody.pdf` (Журнал учёта) - approved
- ID: 27 - `2tp_vozdukh.xlsx` (Отчёт 2-ТП) - pending
- ID: 28 - `pasport_otkhodov.pdf` (Паспорт отходов) - pending
- ID: 29 - `plan_nmu.docx` (План НМУ) - rejected
- ID: 30 - `inventarizatsiya.pdf` (Инвентаризация) - approved

**Полные пути к файлам:**
- `/var/www/html/api/storage/clients/7/journal_otkhody.pdf`
- `/var/www/html/api/storage/clients/7/2tp_vozdukh.xlsx`
- `/var/www/html/api/storage/clients/7/pasport_otkhodov.pdf`
- `/var/www/html/api/storage/clients/7/plan_nmu.docx`
- `/var/www/html/api/storage/clients/7/inventarizatsiya.pdf`

## Проверка работы

1. Откройте http://localhost:3000
2. Войдите: `client@demo.local` / `client123`
3. Перейдите на страницу "Документы"
4. Нажмите кнопку "Скачать" для любого документа
5. Файл должен начать скачиваться

## Статус

✅ Все задачи выполнены
✅ Backend endpoint работает
✅ Демо-файлы созданы
✅ Frontend интегрирован
✅ CORS настроен
✅ Документация обновлена


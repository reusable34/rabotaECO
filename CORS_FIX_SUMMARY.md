# ✅ CORS исправлен для скачивания документов

## Проблема
Браузер блокировал запросы на скачивание документов из-за отсутствия CORS заголовков в ответе на preflight (OPTIONS) запросы.

## Решение

### 1. ✅ Обновлён CorsFilter
**Файл:** `backend/api/components/CorsFilter.php`

- Разрешены origins: `http://localhost:3000`, `http://127.0.0.1:3000`
- Добавлен `Access-Control-Expose-Headers` для `Content-Disposition`
- Правильная обработка OPTIONS запросов

### 2. ✅ Добавлен CORS в DocumentController
**Файл:** `backend/api/controllers/DocumentController.php`

- Добавлен фильтр CORS в behaviors
- Метод `actionOptions()` для обработки preflight запросов
- CORS заголовки устанавливаются автоматически через фильтр

### 3. ✅ Добавлен маршрут для OPTIONS
**Файл:** `backend/api/config/main.php`

- Явный маршрут: `OPTIONS document/<id:\d+>/download` → `document/options`
- Обработка preflight запросов для скачивания

## Проверка работы

### OPTIONS запрос (preflight):
```bash
curl -X OPTIONS \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: Authorization" \
  http://localhost:8080/document/26/download
```

**Ответ:** HTTP 200 с CORS заголовками

### GET запрос (скачивание):
```bash
TOKEN=$(curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"client@demo.local","password":"client123"}' \
  | jq -r '.token')

curl -H "Origin: http://localhost:3000" \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/document/26/download \
  --output file.pdf
```

**Ответ:** HTTP 200 с файлом и CORS заголовками

## CORS заголовки в ответе

```
Access-Control-Allow-Origin: http://localhost:3000
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD
Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Accept, Origin
Access-Control-Expose-Headers: Content-Disposition, Content-Type, Content-Length
Access-Control-Max-Age: 3600
```

## Статус

✅ CORS настроен правильно
✅ OPTIONS запросы обрабатываются
✅ GET запросы работают с CORS заголовками
✅ Frontend может скачивать файлы из браузера

**Всё готово к использованию!**


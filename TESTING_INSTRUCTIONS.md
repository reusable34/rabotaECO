# Инструкция по тестированию исправлений

## Быстрая проверка

### 1. Очистка и пересоздание данных

```bash
docker-compose exec backend php yii cleanup/documents
docker-compose exec backend php yii seed/index
```

### 2. Проверка файлов на сервере

```bash
# Проверить, что файлы созданы
docker-compose exec backend ls -lah /var/www/html/api/storage/clients/7/

# Проверить типы файлов
docker-compose exec backend file /var/www/html/api/storage/clients/7/*.pdf
docker-compose exec backend file /var/www/html/api/storage/clients/7/*.xlsx
docker-compose exec backend file /var/www/html/api/storage/clients/7/*.docx

# Проверить первые байты PDF (должно быть %PDF-1.4)
docker-compose exec backend head -c 20 /var/www/html/api/storage/clients/7/pasport_otkhodov.pdf | od -An -tx1
```

**Ожидаемый результат:**
- PDF файлы: `25 50 44 46` = `%PDF`
- XLSX/DOCX файлы: `50 4b 03 04` = `PK\x03\x04`

### 3. Тестирование скачивания через браузер

1. Откройте `http://localhost:3000`
2. Войдите как клиент: `client@demo.local` / `client123`
3. Перейдите на `/documents`
4. Скачайте каждый тип файла:
   - **PDF** (`pasport_otkhodov.pdf`) - должен открываться в Preview/Adobe Reader
   - **PDF** (`journal_otkhody.pdf`) - должен открываться без ошибок
   - **XLSX** (`2tp_vozdukh.xlsx`) - должен открываться в Excel
   - **DOCX** (`plan_nmu.docx`) - должен открываться в Word
   - **PDF** (`inventarizatsiya.pdf`) - должен открываться без ошибок

### 4. Проверка скачанных файлов

После скачивания проверьте:

```bash
# Проверить тип скачанного файла
file downloaded_file.pdf
# Должно показать: PDF document, version 1.4

# Проверить первые байты
head -c 20 downloaded_file.pdf | od -An -tx1
# Должно показать: 25 50 44 46 (без мусора в начале)
```

### 5. Проверка через curl

```bash
# Логин
TOKEN=$(curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"client@demo.local","password":"client123"}' \
  | jq -r '.token')

# Скачать PDF
curl -X GET "http://localhost:8080/document/1/download" \
  -H "Authorization: Bearer $TOKEN" \
  -o test.pdf

# Проверить файл
file test.pdf
head -c 20 test.pdf
# Должно начинаться с: %PDF-1.4
```

## Критерии успеха

✅ PDF файлы открываются в Preview/Adobe Reader без ошибок
✅ DOCX файлы открываются в Microsoft Word
✅ XLSX файлы открываются в Microsoft Excel
✅ Нет мусора в начале файлов
✅ Первые байты файлов правильные
✅ Размер файлов совпадает с оригиналом
✅ MIME-типы корректные

## Если файлы всё ещё повреждены

1. Проверьте логи: `docker-compose exec backend tail -f /var/www/html/api/runtime/logs/app.log`
2. Проверьте, что нет вывода в других местах
3. Убедитесь, что `clearOutputBuffers()` вызывается перед `sendFile()`
4. Проверьте, что файлы на сервере не повреждены


# Исправление генерации DOCX и XLSX файлов

## Дата: 2025-11-13

## Проблема
DOCX и XLSX файлы создавались как невалидные текстовые файлы, которые не открывались в Word и Excel.

## Решение
Переписана генерация документов в `DemoDataGeneratorService` для создания реальных валидных ZIP-архивов через `ZipArchive`.

## Изменения

### 1. ✅ Переписан метод `generateDocuments()`

**Файл:** `backend/common/services/DemoDataGeneratorService.php`

**Изменения:**
- Убрана генерация через строки для DOCX/XLSX
- Добавлены отдельные методы: `createPdfFile()`, `createDocxFile()`, `createXlsxFile()`
- Используется `ZipArchive` для создания DOCX и XLSX

### 2. ✅ Создан метод `createDocxFile()`

**Структура DOCX (ZIP-архив):**
- `[Content_Types].xml` - типы контента
- `_rels/.rels` - связи документа
- `word/document.xml` - содержимое документа с текстом "Document"

**Результат:** Валидный DOCX файл, открывается в Microsoft Word без ошибок

### 3. ✅ Создан метод `createXlsxFile()`

**Структура XLSX (ZIP-архив):**
- `[Content_Types].xml` - типы контента
- `_rels/.rels` - связи документа
- `xl/workbook.xml` - книга Excel
- `xl/_rels/workbook.xml.rels` - связи книги
- `xl/worksheets/sheet1.xml` - лист с одной ячейкой "Document"

**Результат:** Валидный XLSX файл, открывается в Microsoft Excel без ошибок

### 4. ✅ Сохранён метод `createPdfFile()`

**PDF:** Продолжает создаваться через строку `%PDF-1.4 ...`

## Проверка файлов

### На сервере:
```bash
# Проверить типы файлов
docker-compose exec backend file /var/www/html/api/storage/clients/7/*.docx
docker-compose exec backend file /var/www/html/api/storage/clients/7/*.xlsx

# Результат:
# DOCX: Microsoft Word 2007+
# XLSX: Microsoft Excel 2007+

# Проверить структуру ZIP
docker-compose exec backend unzip -l /var/www/html/api/storage/clients/7/plan_nmu.docx
docker-compose exec backend unzip -l /var/www/html/api/storage/clients/7/2tp_vozdukh.xlsx
```

### Первые байты:
- DOCX/XLSX: `50 4b 03 04` = `PK\x03\x04` (ZIP-архив)
- PDF: `25 50 44 46` = `%PDF`

## Результат

✅ DOCX файлы открываются в Microsoft Word без предупреждений
✅ XLSX файлы открываются в Microsoft Excel без предупреждений
✅ PDF файлы продолжают работать как раньше
✅ Все файлы создаются как валидные бинарные файлы
✅ MIME-типы определяются корректно

## Изменённые файлы

1. `backend/common/services/DemoDataGeneratorService.php` - переписана генерация документов

## Тестирование

1. Войдите как клиент: `client@demo.local` / `client123`
2. Перейдите на `/documents`
3. Скачайте DOCX файл - должен открываться в Word
4. Скачайте XLSX файл - должен открываться в Excel
5. Скачайте PDF файл - должен открываться в Preview/Adobe Reader

Все файлы должны открываться без ошибок и предупреждений!


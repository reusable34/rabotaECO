<?php

namespace common\services;

use common\models\Client;
use common\models\Contract;
use common\models\Document;
use common\models\Event;
use common\models\Requirement;
use common\models\Risk;
use common\services\RequirementGeneratorService;
use Yii;

/**
 * Сервис для генерации полноценных демо-данных
 */
class DemoDataGeneratorService
{
    /**
     * Генерация всех демо-данных для клиента
     *
     * @param Client $client
     * @return array Статистика созданных данных
     */
    public static function generateDemoData(Client $client): array
    {
        $stats = [
            'requirements' => 0,
            'risks' => 0,
            'events' => 0,
            'documents' => 0,
            'contracts' => 0,
        ];

        // 1. Генерация требований с разными статусами и дедлайнами
        $stats['requirements'] = self::generateRequirements($client);

        // 2. Генерация рисков для требований
        $stats['risks'] = self::generateRisks($client);

        // 3. Генерация событий (календарь)
        $stats['events'] = self::generateEvents($client);

        // 4. Генерация документов
        $stats['documents'] = self::generateDocuments($client);

        // 5. Генерация договоров
        $stats['contracts'] = self::generateContracts($client);

        return $stats;
    }

    /**
     * Генерация требований с разными статусами и дедлайнами
     */
    private static function generateRequirements(Client $client): int
    {
        // Сначала генерируем базовые требования через RequirementGeneratorService
        $baseRequirements = RequirementGeneratorService::generateRequirements($client);
        $count = count($baseRequirements);

        // Статусы для распределения по требованиям
        $statuses = [
            Requirement::STATUS_COMPLETED,
            Requirement::STATUS_IN_PROGRESS,
            Requirement::STATUS_IN_PROGRESS,
            Requirement::STATUS_PENDING,
            Requirement::STATUS_PENDING,
            Requirement::STATUS_NOT_COMPLETED,
        ];

        // Обновляем статусы и дедлайны существующих требований
        foreach ($baseRequirements as $index => $req) {
            $statusIndex = $index % count($statuses);
            $req->status = $statuses[$statusIndex];
            
            // Разные дедлайны: часть прошедшие, часть будущие
            if ($req->status === Requirement::STATUS_COMPLETED || $req->status === Requirement::STATUS_NOT_COMPLETED) {
                $req->deadline = date('Y-m-d', strtotime('-' . rand(5, 30) . ' days'));
            } else {
                $req->deadline = date('Y-m-d', strtotime('+' . rand(10, 90) . ' days'));
            }
            
            $req->save();
        }

        // Добавляем дополнительные требования, если их меньше 15
        if ($count < 15) {
            $extraTitles = [
                'Отчёт о выполнении мероприятий по охране окружающей среды',
                'Программа производственного экологического контроля',
                'Декларация о количестве выбросов загрязняющих веществ',
                'Справка о наличии источников выбросов',
                'Расчёт нормативов допустимых выбросов',
            ];

            foreach ($extraTitles as $title) {
                $requirement = new Requirement();
                $requirement->client_id = $client->id;
                $requirement->title = $title;
                $requirement->status = Requirement::STATUS_PENDING;
                $requirement->deadline = date('Y-m-d', strtotime('+' . rand(10, 90) . ' days'));
                if ($requirement->save()) {
                    $count++;
                }
            }
        }

        return $count;
    }

    /**
     * Генерация рисков с статьями КоАП и штрафами
     */
    private static function generateRisks(Client $client): int
    {
        $requirements = Requirement::findAll(['client_id' => $client->id]);
        $risksData = [
            ['article' => '8.2 КоАП', 'fine_min' => 20000, 'fine_max' => 100000],
            ['article' => '8.21 КоАП', 'fine_min' => 40000, 'fine_max' => 200000],
            ['article' => '8.1 КоАП', 'fine_min' => 10000, 'fine_max' => 250000],
            ['article' => '8.5 КоАП', 'fine_min' => 30000, 'fine_max' => 150000],
            ['article' => '8.46 КоАП', 'fine_min' => 50000, 'fine_max' => 300000],
        ];

        $count = 0;
        foreach ($requirements as $index => $requirement) {
            $riskData = $risksData[$index % count($risksData)];
            
            $risk = Risk::findOne(['requirement_id' => $requirement->id]);
            if (!$risk) {
                $risk = new Risk();
                $risk->requirement_id = $requirement->id;
                $risk->article = $riskData['article'];
                $risk->fine_min = $riskData['fine_min'];
                $risk->fine_max = $riskData['fine_max'];
                if ($risk->save()) {
                    $count++;
                }
            }
        }

        return $count;
    }

    /**
     * Генерация событий (3 будущих, 2 прошедших)
     */
    private static function generateEvents(Client $client): int
    {
        $events = [
            // Будущие события
            [
                'title' => 'Сдача отчёта 2-ТП (воздух)',
                'date' => date('Y-m-d', strtotime('+15 days')),
                'completed' => false,
            ],
            [
                'title' => 'Сдача отчёта 2-ТП (отходы)',
                'date' => date('Y-m-d', strtotime('+30 days')),
                'completed' => false,
            ],
            [
                'title' => 'Подача Декларации о плате за НВОС',
                'date' => date('Y-m-d', strtotime('+45 days')),
                'completed' => false,
            ],
            // Прошедшие события
            [
                'title' => 'Сдача Журнала учёта движения отходов',
                'date' => date('Y-m-d', strtotime('-20 days')),
                'completed' => true,
            ],
            [
                'title' => 'Проверка Росприроднадзора',
                'date' => date('Y-m-d', strtotime('-10 days')),
                'completed' => true,
            ],
        ];

        $count = 0;
        foreach ($events as $eventData) {
            $event = new Event();
            $event->client_id = $client->id;
            $event->title = $eventData['title'];
            $event->date = $eventData['date'];
            $event->completed = $eventData['completed'];
            if ($event->save()) {
                $count++;
            }
        }

        return $count;
    }

    /**
     * Генерация документов с разными статусами и создание реальных файлов
     * file_path в БД: clients/{client_id}/{filename}
     * Файлы создаются в: backend/api/storage/clients/{client_id}/{filename}
     */
    private static function generateDocuments(Client $client): int
    {
        // Проверяем, что client_id существует
        if (!$client->id) {
            return 0;
        }

        // Создаём директорию для файлов клиента
        $storagePath = Yii::getAlias('@api/storage/clients/' . $client->id);
        if (!is_dir($storagePath)) {
            mkdir($storagePath, 0755, true);
        }

        // Удаляем старые документы этого клиента
        Document::deleteAll(['client_id' => $client->id]);

        // Документы для создания
        $documents = [
            [
                'filename' => 'pasport_otkhodov.pdf',
                'type' => 'Паспорт отходов',
                'status' => Document::STATUS_PENDING,
            ],
            [
                'filename' => 'journal_otkhody.pdf',
                'type' => 'Журнал учёта движения отходов',
                'status' => Document::STATUS_APPROVED,
            ],
            [
                'filename' => '2tp_vozdukh.xlsx',
                'type' => 'Отчёт 2-ТП (воздух)',
                'status' => Document::STATUS_PENDING,
            ],
            [
                'filename' => 'plan_nmu.docx',
                'type' => 'План мероприятий при НМУ',
                'status' => Document::STATUS_REJECTED,
            ],
            [
                'filename' => 'inventarizatsiya.pdf',
                'type' => 'Инвентаризация источников выбросов',
                'status' => Document::STATUS_APPROVED,
            ],
        ];

        $count = 0;
        foreach ($documents as $docData) {
            $filename = $docData['filename'];
            $fullFilePath = $storagePath . '/' . $filename;
            $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
            
            // Создаём файл в зависимости от типа
            $created = false;
            if ($ext === 'pdf') {
                $created = self::createPdfFile($fullFilePath);
            } elseif ($ext === 'docx') {
                $created = self::createDocxFile($fullFilePath);
            } elseif ($ext === 'xlsx') {
                $created = self::createXlsxFile($fullFilePath);
            }
            
            if (!$created) {
                continue;
            }

            // file_path в БД: clients/{client_id}/{filename}
            $dbFilePath = 'clients/' . $client->id . '/' . $filename;

            // Создаём запись в БД
            $document = new Document();
            $document->client_id = (int)$client->id;
            $document->file_path = $dbFilePath;
            $document->type = $docData['type'];
            $document->status = $docData['status'];
            
            if ($document->save()) {
                $count++;
            }
        }

        return $count;
    }

    /**
     * Создание минимального валидного PDF файла
     */
    private static function createPdfFile($filePath): bool
    {
        $content = "%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n2 0 obj\n<<\n/Type /Pages\n/Kids [3 0 R]\n/Count 1\n>>\nendobj\n3 0 obj\n<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n/Contents 4 0 R\n/Resources <<\n/Font <<\n/F1 <<\n/Type /Font\n/Subtype /Type1\n/BaseFont /Helvetica\n>>\n>>\n>>\n>>\nendobj\n4 0 obj\n<<\n/Length 20\n>>\nstream\nBT\n/F1 12 Tf\n100 700 Td\n(Document) Tj\nET\nendstream\nendobj\nxref\n0 5\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n0000000284 00000 n \ntrailer\n<<\n/Size 5\n/Root 1 0 R\n>>\nstartxref\n354\n%%EOF";
        return file_put_contents($filePath, $content, LOCK_EX) !== false;
    }

    /**
     * Создание минимального валидного DOCX файла через ZipArchive
     */
    private static function createDocxFile($filePath): bool
    {
        if (!class_exists('ZipArchive')) {
            return false;
        }

        $zip = new \ZipArchive();
        if ($zip->open($filePath, \ZipArchive::CREATE | \ZipArchive::OVERWRITE) !== true) {
            return false;
        }

        // [Content_Types].xml
        $contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>';
        $zip->addFromString('[Content_Types].xml', $contentTypes);

        // _rels/.rels
        $rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>';
        $zip->addFromString('_rels/.rels', $rels);

        // word/document.xml
        $document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
<w:p>
<w:r>
<w:t>Document</w:t>
</w:r>
</w:p>
</w:body>
</w:document>';
        $zip->addFromString('word/document.xml', $document);

        $result = $zip->close();
        return $result === true;
    }

    /**
     * Создание минимального валидного XLSX файла через ZipArchive
     */
    private static function createXlsxFile($filePath): bool
    {
        if (!class_exists('ZipArchive')) {
            return false;
        }

        $zip = new \ZipArchive();
        if ($zip->open($filePath, \ZipArchive::CREATE | \ZipArchive::OVERWRITE) !== true) {
            return false;
        }

        // [Content_Types].xml
        $contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>';
        $zip->addFromString('[Content_Types].xml', $contentTypes);

        // _rels/.rels
        $rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>';
        $zip->addFromString('_rels/.rels', $rels);

        // xl/workbook.xml
        $workbook = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>
<sheet name="Sheet1" sheetId="1" r:id="rId1"/>
</sheets>
</workbook>';
        $zip->addFromString('xl/workbook.xml', $workbook);

        // xl/_rels/workbook.xml.rels
        $workbookRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>';
        $zip->addFromString('xl/_rels/workbook.xml.rels', $workbookRels);

        // xl/worksheets/sheet1.xml
        $sheet = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetData>
<row r="1">
<c r="A1" t="inlineStr">
<is>
<t>Document</t>
</is>
</c>
</row>
</sheetData>
</worksheet>';
        $zip->addFromString('xl/worksheets/sheet1.xml', $sheet);

        $result = $zip->close();
        return $result === true;
    }

    /**
     * Генерация договоров
     */
    private static function generateContracts(Client $client): int
    {
        $contracts = [
            [
                'number' => 'ДОГ-2024-001',
                'status' => Contract::STATUS_ACTIVE,
                'date' => date('Y-m-d', strtotime('-30 days')),
            ],
            [
                'number' => 'АКТ-2024-001',
                'status' => Contract::STATUS_COMPLETED,
                'date' => date('Y-m-d', strtotime('-10 days')),
            ],
        ];

        $count = 0;
        foreach ($contracts as $contractData) {
            // Проверяем, не существует ли уже договор с таким номером для этого клиента
            $existing = Contract::findOne([
                'client_id' => $client->id,
                'number' => $contractData['number']
            ]);
            
            if ($existing) {
                Yii::info("Contract {$contractData['number']} already exists for client {$client->id}, skipping");
                continue;
            }
            
            $contract = new Contract();
            $contract->client_id = $client->id;
            $contract->number = $contractData['number'];
            $contract->status = $contractData['status'];
            $contract->date = $contractData['date'];
            if ($contract->save()) {
                $count++;
            } else {
                Yii::error("Failed to save contract {$contractData['number']}: " . json_encode($contract->errors));
            }
        }

        return $count;
    }
}


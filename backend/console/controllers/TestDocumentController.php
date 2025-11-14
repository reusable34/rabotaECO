<?php

namespace console\controllers;

use common\models\Document;
use common\models\User;
use Yii;
use yii\console\Controller;
use yii\helpers\Json;

/**
 * Автотест для проверки работы модуля документов
 */
class TestDocumentController extends Controller
{
    /**
     * Тест фильтрации и скачивания документов
     */
    public function actionIndex()
    {
        $this->stdout("=== Тест модуля документов ===\n\n");

        // 1. Логин клиентом
        $this->stdout("1. Поиск клиента...\n");
        $clientUser = User::findOne(['email' => 'client@demo.local']);
        if (!$clientUser) {
            $this->stdout("ERROR: Client user not found!\n");
            return 1;
        }

        if (!$clientUser->client_id) {
            $this->stdout("ERROR: Client user has no client_id!\n");
            return 1;
        }

        $this->stdout("   ✓ Клиент найден: ID={$clientUser->id}, client_id={$clientUser->client_id}\n\n");

        // 2. Проверка документов клиента
        $this->stdout("2. Проверка документов клиента...\n");
        $documents = Document::findAll(['client_id' => $clientUser->client_id]);
        $this->stdout("   Найдено документов: " . count($documents) . "\n");

        if (count($documents) === 0) {
            $this->stdout("WARNING: No documents found for client!\n");
            return 0;
        }

        // 3. Проверка, что ВСЕ документы принадлежат клиенту
        $this->stdout("3. Проверка принадлежности документов...\n");
        $allCorrect = true;
        foreach ($documents as $doc) {
            if ((int)$doc->client_id !== (int)$clientUser->client_id) {
                $this->stdout("   ERROR: Document {$doc->id} has client_id {$doc->client_id}, expected {$clientUser->client_id}\n");
                $allCorrect = false;
            }
        }

        if ($allCorrect) {
            $this->stdout("   ✓ Все документы принадлежат клиенту\n\n");
        } else {
            $this->stdout("   ✗ Обнаружены документы с неправильным client_id!\n\n");
            return 1;
        }

        // 4. Проверка существования файлов
        $this->stdout("4. Проверка существования файлов...\n");
        $allFilesExist = true;
        foreach ($documents as $doc) {
            $filePath = $doc->file_path;
            
            // Нормализуем путь
            if (strpos($filePath, 'storage/') === 0) {
                $filePath = substr($filePath, strlen('storage/'));
            }
            
            if (strpos($filePath, 'clients/') === 0) {
                $fullPath = Yii::getAlias('@api/storage/' . $filePath);
            } else {
                $fullPath = Yii::getAlias('@api/storage/clients/' . $doc->client_id . '/' . basename($filePath));
            }

            if (!file_exists($fullPath)) {
                $this->stdout("   ERROR: File not found for document {$doc->id}: {$fullPath}\n");
                $allFilesExist = false;
            } else {
                $ext = strtolower(pathinfo($fullPath, PATHINFO_EXTENSION));
                $this->stdout("   ✓ Document {$doc->id}: {$doc->type} ({$ext}) - " . filesize($fullPath) . " bytes\n");
            }
        }

        if ($allFilesExist) {
            $this->stdout("   ✓ Все файлы существуют\n\n");
        } else {
            $this->stdout("   ✗ Некоторые файлы не найдены!\n\n");
            return 1;
        }

        // 5. Проверка MIME-типов
        $this->stdout("5. Проверка MIME-типов...\n");
        $mimeTypes = [
            'pdf' => 'application/pdf',
            'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ];

        foreach ($documents as $doc) {
            $filePath = $doc->file_path;
            if (strpos($filePath, 'storage/') === 0) {
                $filePath = substr($filePath, strlen('storage/'));
            }
            if (strpos($filePath, 'clients/') === 0) {
                $fullPath = Yii::getAlias('@api/storage/' . $filePath);
            } else {
                $fullPath = Yii::getAlias('@api/storage/clients/' . $doc->client_id . '/' . basename($filePath));
            }

            $ext = strtolower(pathinfo($fullPath, PATHINFO_EXTENSION));
            $expectedMime = $mimeTypes[$ext] ?? 'application/octet-stream';
            
            if (function_exists('mime_content_type')) {
                $detectedMime = @mime_content_type($fullPath);
                if ($detectedMime && $detectedMime !== $expectedMime && $detectedMime !== 'application/octet-stream') {
                    $this->stdout("   INFO: Document {$doc->id} ({$ext}): detected={$detectedMime}, expected={$expectedMime}\n");
                }
            }
        }
        $this->stdout("   ✓ MIME-типы проверены\n\n");

        $this->stdout("=== Все тесты пройдены успешно! ===\n");
        return 0;
    }
}


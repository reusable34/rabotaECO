<?php

namespace console\controllers;

use common\models\Document;
use Yii;
use yii\console\Controller;

/**
 * Контроллер для очистки storage и документов
 */
class CleanupController extends Controller
{
    /**
     * Очистка всех документов и storage
     */
    public function actionDocuments()
    {
        $this->stdout("Cleaning up documents and storage...\n");

        // Удаляем все документы из БД
        $deleted = Document::deleteAll();
        $this->stdout("Deleted {$deleted} documents from database\n");

        // Очищаем storage
        $storagePath = Yii::getAlias('@api/storage/clients');
        if (is_dir($storagePath)) {
            $this->removeDirectory($storagePath);
            $this->stdout("Cleaned storage directory: {$storagePath}\n");
        }

        // Создаём базовую структуру
        if (!is_dir($storagePath)) {
            mkdir($storagePath, 0755, true);
            $this->stdout("Created storage directory: {$storagePath}\n");
        }

        $this->stdout("Cleanup completed!\n");
    }

    /**
     * Рекурсивное удаление директории
     */
    private function removeDirectory($dir)
    {
        if (!is_dir($dir)) {
            return;
        }

        $files = array_diff(scandir($dir), ['.', '..']);
        foreach ($files as $file) {
            $path = $dir . '/' . $file;
            if (is_dir($path)) {
                $this->removeDirectory($path);
            } else {
                unlink($path);
            }
        }
        rmdir($dir);
    }
}


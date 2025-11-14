<?php

namespace console\controllers;

use common\models\Client;
use common\models\Requirement;
use common\services\RequirementGeneratorService;
use Yii;
use yii\console\Controller;
use yii\db\Transaction;

/**
 * Контроллер для принудительного пересчета требований для всех клиентов
 */
class RecalculateAllController extends Controller
{
    /**
     * Пересчитать требования для всех клиентов
     */
    public function actionAll()
    {
        $this->stdout("=== ПРИНУДИТЕЛЬНЫЙ ПЕРЕСЧЕТ ТРЕБОВАНИЙ ДЛЯ ВСЕХ КЛИЕНТОВ ===\n\n");

        $clients = Client::find()->all();
        $total = count($clients);
        $success = 0;
        $failed = 0;

        foreach ($clients as $idx => $client) {
            $this->stdout("[" . ($idx + 1) . "/{$total}] Клиент ID {$client->id}, категория {$client->category_id}... ");

            try {
                $transaction = Yii::$app->db->beginTransaction();
                
                // Удаляем все старые требования
                Requirement::deleteAll(['client_id' => $client->id]);
                
                // Генерируем новые
                $requirements = RequirementGeneratorService::generateRequirements($client);
                
                $transaction->commit();
                
                $this->stdout("✓ Создано " . count($requirements) . " требований\n");
                $success++;
                
            } catch (\Exception $e) {
                $transaction->rollBack();
                $this->stdout("✗ ОШИБКА: {$e->getMessage()}\n");
                $failed++;
            }
        }

        $this->stdout("\n=== ИТОГИ ===\n");
        $this->stdout("Успешно: {$success}\n");
        $this->stdout("Ошибок: {$failed}\n");

        return $failed > 0 ? 1 : 0;
    }

    /**
     * Пересчитать требования для конкретного клиента
     */
    public function actionClient($clientId)
    {
        $client = Client::findOne($clientId);
        if (!$client) {
            $this->stdout("Клиент с ID {$clientId} не найден\n");
            return 1;
        }

        $this->stdout("=== ПЕРЕСЧЕТ ТРЕБОВАНИЙ ДЛЯ КЛИЕНТА {$clientId} ===\n");
        $this->stdout("Категория: {$client->category_id}\n\n");

        try {
            $transaction = Yii::$app->db->beginTransaction();
            
            // Удаляем все старые требования
            $deleted = Requirement::deleteAll(['client_id' => $client->id]);
            $this->stdout("Удалено старых требований: {$deleted}\n");
            
            // Генерируем новые
            $requirements = RequirementGeneratorService::generateRequirements($client);
            
            $transaction->commit();
            
            $this->stdout("Создано новых требований: " . count($requirements) . "\n\n");
            $this->stdout("СПИСОК СОЗДАННЫХ ТРЕБОВАНИЙ:\n");
            foreach ($requirements as $idx => $req) {
                $this->stdout(sprintf("%2d. %s\n", $idx + 1, $req->title));
            }
            
            return 0;
            
        } catch (\Exception $e) {
            $transaction->rollBack();
            $this->stdout("ОШИБКА: {$e->getMessage()}\n");
            return 1;
        }
    }
}


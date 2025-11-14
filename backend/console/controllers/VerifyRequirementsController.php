<?php

namespace console\controllers;

use common\models\Client;
use common\models\Requirement;
use Yii;
use yii\console\Controller;

/**
 * Контроллер для проверки соответствия требований в БД ожидаемым
 */
class VerifyRequirementsController extends Controller
{
    /**
     * Проверить требования для всех клиентов
     */
    public function actionAll()
    {
        $this->stdout("=== ПРОВЕРКА ТРЕБОВАНИЙ В БД ===\n\n");

        $clients = Client::find()->all();
        $expectedBaseCounts = [1 => 18, 2 => 18, 3 => 16, 4 => 8];
        
        $errors = [];
        
        foreach ($clients as $client) {
            $this->stdout("Клиент ID {$client->id}, категория {$client->category_id}:\n");
            
            $requirements = Requirement::findAll(['client_id' => $client->id]);
            $expectedBase = $expectedBaseCounts[$client->category_id] ?? 0;
            $expectedAdditional = 0;
            if ($client->has_well) $expectedAdditional++;
            if ($client->has_river) $expectedAdditional += 2;
            if ($client->has_byproduct) $expectedAdditional++;
            $expectedTotal = $expectedBase + $expectedAdditional;
            
            $actualCount = count($requirements);
            
            if ($actualCount != $expectedTotal) {
                $this->stdout("  ✗ ОШИБКА: Ожидалось {$expectedTotal}, найдено {$actualCount}\n");
                $errors[] = "Клиент ID {$client->id}, категория {$client->category_id}: {$actualCount}/{$expectedTotal}";
            } else {
                $this->stdout("  ✓ Правильно: {$actualCount} требований\n");
            }
            
            // Показываем все требования
            $this->stdout("  Требования в БД:\n");
            foreach ($requirements as $idx => $req) {
                $this->stdout(sprintf("    %2d. [ID %3d] %s\n", $idx + 1, $req->id, $req->title));
            }
            $this->stdout("\n");
        }
        
        if (!empty($errors)) {
            $this->stdout("\n=== ОШИБКИ ===\n");
            foreach ($errors as $error) {
                $this->stdout("  - {$error}\n");
            }
            return 1;
        }
        
        $this->stdout("\n✓ Все требования правильные!\n");
        return 0;
    }
}


<?php

namespace console\controllers;

use common\models\Client;
use common\models\Requirement;
use Yii;
use yii\console\Controller;

/**
 * Контроллер для проверки требований в БД
 */
class CheckRequirementsController extends Controller
{
    /**
     * Проверить требования для конкретного клиента
     */
    public function actionCheck($clientId)
    {
        $client = Client::findOne($clientId);
        if (!$client) {
            $this->stdout("Клиент с ID {$clientId} не найден\n");
            return 1;
        }

        $this->stdout("=== ПРОВЕРКА ТРЕБОВАНИЙ ДЛЯ КЛИЕНТА {$clientId} ===\n");
        $this->stdout("Категория: {$client->category_id}\n");
        $this->stdout("Скважина: " . ($client->has_well ? 'да' : 'нет') . "\n");
        $this->stdout("Река: " . ($client->has_river ? 'да' : 'нет') . "\n");
        $this->stdout("Побочный продукт: " . ($client->has_byproduct ? 'да' : 'нет') . "\n\n");

        $requirements = Requirement::findAll(['client_id' => $clientId]);
        $this->stdout("Требований в БД: " . count($requirements) . "\n\n");

        $expectedBaseCounts = [
            1 => 18,
            2 => 18,
            3 => 16,
            4 => 8,
        ];

        $expectedBase = $expectedBaseCounts[$client->category_id] ?? 0;
        $expectedAdditional = 0;
        if ($client->has_well) $expectedAdditional++;
        if ($client->has_river) $expectedAdditional += 2;
        if ($client->has_byproduct) $expectedAdditional++;
        $expectedTotal = $expectedBase + $expectedAdditional;

        $this->stdout("Ожидается: {$expectedTotal} требований ({$expectedBase} базовых + {$expectedAdditional} дополнительных)\n\n");

        if (count($requirements) != $expectedTotal) {
            $this->stdout("✗ ОШИБКА: Несоответствие количества!\n");
        } else {
            $this->stdout("✓ Количество правильное\n");
        }

        $this->stdout("\nСПИСОК ТРЕБОВАНИЙ В БД:\n");
        foreach ($requirements as $idx => $req) {
            $this->stdout(sprintf("%2d. %s\n", $idx + 1, $req->title));
        }

        return 0;
    }

    /**
     * Проверить всех клиентов
     */
    public function actionCheckAll()
    {
        $clients = Client::find()->all();
        $this->stdout("=== ПРОВЕРКА ВСЕХ КЛИЕНТОВ ===\n\n");

        $expectedBaseCounts = [1 => 18, 2 => 18, 3 => 16, 4 => 8];
        $errors = [];

        foreach ($clients as $client) {
            $requirements = Requirement::findAll(['client_id' => $client->id]);
            $expectedBase = $expectedBaseCounts[$client->category_id] ?? 0;
            $expectedAdditional = 0;
            if ($client->has_well) $expectedAdditional++;
            if ($client->has_river) $expectedAdditional += 2;
            if ($client->has_byproduct) $expectedAdditional++;
            $expectedTotal = $expectedBase + $expectedAdditional;

            $actualCount = count($requirements);
            $status = $actualCount == $expectedTotal ? "✓" : "✗";

            $this->stdout("{$status} Клиент ID {$client->id}, категория {$client->category_id}: {$actualCount}/{$expectedTotal} требований\n");

            if ($actualCount != $expectedTotal) {
                $errors[] = "Клиент ID {$client->id}, категория {$client->category_id}: ожидалось {$expectedTotal}, найдено {$actualCount}";
            }
        }

        if (!empty($errors)) {
            $this->stdout("\nОШИБКИ:\n");
            foreach ($errors as $error) {
                $this->stdout("  - {$error}\n");
            }
            return 1;
        }

        $this->stdout("\n✓ Все клиенты имеют правильное количество требований\n");
        return 0;
    }
}


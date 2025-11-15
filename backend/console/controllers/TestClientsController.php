<?php

namespace console\controllers;

use common\models\Client;
use common\models\Requirement;
use common\models\Risk;
use common\models\Document;
use common\models\Contract;
use common\models\Event;
use common\services\RequirementGeneratorService;
use Yii;
use yii\console\Controller;

/**
 * Контроллер для создания тестовых клиентов
 */
class TestClientsController extends Controller
{
    /**
     * Удалить всех клиентов и создать тестовых
     */
    public function actionCreate()
    {
        $this->stdout("==========================================\n");
        $this->stdout("🧪 СОЗДАНИЕ ТЕСТОВЫХ КЛИЕНТОВ\n");
        $this->stdout("==========================================\n\n");

        // 1. Удаление всех существующих клиентов
        $this->stdout("[1/3] Удаление всех существующих клиентов...\n");
        
        // Удаляем риски
        $riskCount = Risk::find()->count();
        Yii::$app->db->createCommand("DELETE FROM risks")->execute();
        $this->stdout("Удалено рисков: {$riskCount}\n");
        
        // Удаляем требования
        $reqCount = Requirement::find()->count();
        Requirement::deleteAll();
        $this->stdout("Удалено требований: {$reqCount}\n");
        
        // Удаляем документы, договоры, события
        Document::deleteAll();
        Contract::deleteAll();
        Event::deleteAll();
        $this->stdout("Удалены документы, договоры и события\n");
        
        // Удаляем клиентов
        $clientCount = Client::find()->count();
        Client::deleteAll();
        $this->stdout("Удалено клиентов: {$clientCount}\n");
        
        $this->stdout("✅ Очистка завершена\n\n");

        // 2. Создание тестовых клиентов
        $this->stdout("[2/3] Создание тестовых клиентов...\n\n");

        // Клиент I категории (без дополнительных параметров)
        $client1 = new Client();
        $client1->name = 'Тестовый клиент I категории';
        $client1->category_id = 1;
        $client1->has_well = false;
        $client1->has_river = false;
        $client1->has_byproduct = false;
        $client1->responsible_person = 'Иванов Иван Иванович';
        if ($client1->save()) {
            $this->stdout("✅ Создан клиент I категории (ID: {$client1->id})\n");
            RequirementGeneratorService::generateRequirements($client1);
            $reqCount = Requirement::find()->where(['client_id' => $client1->id])->count();
            $this->stdout("   Создано требований: {$reqCount} (ожидается: 18)\n\n");
        } else {
            $this->stdout("❌ Ошибка создания клиента I категории: " . json_encode($client1->errors) . "\n\n");
        }

        // Клиент II категории (с рекой)
        $client2 = new Client();
        $client2->name = 'Тестовый клиент II категории (с рекой)';
        $client2->category_id = 2;
        $client2->has_well = false;
        $client2->has_river = true;
        $client2->has_byproduct = false;
        $client2->responsible_person = 'Петров Петр Петрович';
        if ($client2->save()) {
            $this->stdout("✅ Создан клиент II категории (ID: {$client2->id})\n");
            RequirementGeneratorService::generateRequirements($client2);
            $reqCount = Requirement::find()->where(['client_id' => $client2->id])->count();
            $this->stdout("   Создано требований: {$reqCount} (ожидается: 20 = 18 базовых + 2 река)\n\n");
        } else {
            $this->stdout("❌ Ошибка создания клиента II категории: " . json_encode($client2->errors) . "\n\n");
        }

        // Клиент III категории (без дополнительных параметров)
        $client3 = new Client();
        $client3->name = 'Тестовый клиент III категории';
        $client3->category_id = 3;
        $client3->has_well = false;
        $client3->has_river = false;
        $client3->has_byproduct = false;
        $client3->responsible_person = 'Сидоров Сидор Сидорович';
        if ($client3->save()) {
            $this->stdout("✅ Создан клиент III категории (ID: {$client3->id})\n");
            RequirementGeneratorService::generateRequirements($client3);
            $reqCount = Requirement::find()->where(['client_id' => $client3->id])->count();
            $this->stdout("   Создано требований: {$reqCount} (ожидается: 16)\n\n");
        } else {
            $this->stdout("❌ Ошибка создания клиента III категории: " . json_encode($client3->errors) . "\n\n");
        }

        // Клиент IV категории (со скважиной и побочным продуктом)
        $client4 = new Client();
        $client4->name = 'Тестовый клиент IV категории (скважина + побочный продукт)';
        $client4->category_id = 4;
        $client4->has_well = true;
        $client4->has_river = false;
        $client4->has_byproduct = true;
        $client4->responsible_person = 'Кузнецов Кузьма Кузьмич';
        if ($client4->save()) {
            $this->stdout("✅ Создан клиент IV категории (ID: {$client4->id})\n");
            RequirementGeneratorService::generateRequirements($client4);
            $reqCount = Requirement::find()->where(['client_id' => $client4->id])->count();
            $this->stdout("   Создано требований: {$reqCount} (ожидается: 10 = 8 базовых + 1 скважина + 1 побочный продукт)\n\n");
        } else {
            $this->stdout("❌ Ошибка создания клиента IV категории: " . json_encode($client4->errors) . "\n\n");
        }

        $this->stdout("✅ Все тестовые клиенты созданы\n\n");

        // 3. Итоговая статистика
        $this->stdout("[3/3] Итоговая статистика...\n\n");
        $this->stdout("📊 СТАТИСТИКА:\n");
        $this->stdout("==========================================\n");

        $clients = Client::find()->all();
        foreach ($clients as $client) {
            $reqCount = Requirement::find()->where(['client_id' => $client->id])->count();
            $expectedCounts = [
                1 => 18,
                2 => 18 + ($client->has_river ? 2 : 0),
                3 => 16,
                4 => 8 + ($client->has_well ? 1 : 0) + ($client->has_byproduct ? 1 : 0),
            ];
            $expected = $expectedCounts[$client->category_id] ?? 0;
            $status = ($reqCount == $expected) ? '✅' : '❌';
            
            $this->stdout("{$status} Клиент ID {$client->id}: {$client->name}\n");
            $this->stdout("   Категория: {$client->category_id}\n");
            $this->stdout("   Скважина: " . ($client->has_well ? 'да' : 'нет') . "\n");
            $this->stdout("   Река: " . ($client->has_river ? 'да' : 'нет') . "\n");
            $this->stdout("   Побочный продукт: " . ($client->has_byproduct ? 'да' : 'нет') . "\n");
            $this->stdout("   Требований: {$reqCount} (ожидается: {$expected})\n");
            $this->stdout("\n");
        }

        $this->stdout("==========================================\n");
        $this->stdout("✅ ГОТОВО!\n");
        $this->stdout("==========================================\n\n");
        $this->stdout("Тестовые клиенты созданы. Проверьте на сайте:\n");
        $this->stdout("  - Клиент I категории: должно быть 18 требований\n");
        $this->stdout("  - Клиент II категории (с рекой): должно быть 20 требований\n");
        $this->stdout("  - Клиент III категории: должно быть 16 требований\n");
        $this->stdout("  - Клиент IV категории (скважина + побочный продукт): должно быть 10 требований\n\n");
    }
}


<?php

namespace console\controllers;

use common\models\Category;
use common\models\Client;
use common\models\Contract;
use common\models\Document;
use common\models\Event;
use common\models\Requirement;
use common\models\Risk;
use common\models\User;
use common\services\DemoDataGeneratorService;
use Yii;
use yii\console\Controller;
use yii\console\ExitCode;

class DemoController extends Controller
{
    /**
     * Сброс и пересоздание всех демо-данных
     */
    public function actionReset()
    {
        $this->stdout("=== Сброс демо-данных ===\n\n");

        // 1. Очистка данных демо-клиента
        $this->stdout("1. Очистка существующих данных...\n");
        $demoClient = Client::findOne(['name' => 'Демо-клиент']);
        
        if ($demoClient) {
            // Удаляем связанные данные
            $requirementIds = Requirement::find()->select('id')->where(['client_id' => $demoClient->id])->column();
            if (!empty($requirementIds)) {
                Risk::deleteAll(['requirement_id' => $requirementIds]);
            }
            Requirement::deleteAll(['client_id' => $demoClient->id]);
            Event::deleteAll(['client_id' => $demoClient->id]);
            Document::deleteAll(['client_id' => $demoClient->id]);
            Contract::deleteAll(['client_id' => $demoClient->id]);
            
            // Удаляем пользователя-клиента
            $clientUser = User::findOne(['client_id' => $demoClient->id]);
            if ($clientUser) {
                $clientUser->delete();
            }
            
            // Удаляем клиента
            $demoClient->delete();
            $this->stdout("   ✓ Данные демо-клиента удалены\n");
        }

        // 2. Применение миграций
        $this->stdout("\n2. Применение миграций...\n");
        $migrateController = new \yii\console\controllers\MigrateController('migrate', Yii::$app);
        $migrateController->interactive = false;
        $migrateController->runAction('up');
        $this->stdout("   ✓ Миграции применены\n");

        // 3. Загрузка базовых данных (категории, пользователи)
        $this->stdout("\n3. Загрузка базовых данных...\n");
        $seedController = new SeedController('seed', Yii::$app);
        $seedController->runAction('index');
        $this->stdout("   ✓ Базовые данные загружены\n");

        // 4. Создание демо-клиента с полным набором данных
        $this->stdout("\n4. Создание демо-клиента с полным набором данных...\n");
        $categoryII = Category::findOne(['title' => 'II категория']);
        if (!$categoryII) {
            $this->stdout("ERROR: Category 'II категория' not found!\n");
            return ExitCode::DATAERR;
        }

        $demoClient = new Client();
        $demoClient->name = 'Демо-клиент';
        $demoClient->category_id = $categoryII->id;
        $demoClient->has_well = true;
        $demoClient->has_river = false;
        $demoClient->has_byproduct = true;
        
        if (!$demoClient->save()) {
            $this->stdout("ERROR: Failed to create demo client: " . json_encode($demoClient->errors) . "\n");
            return ExitCode::DATAERR;
        }
        $this->stdout("   ✓ Демо-клиент создан (ID: {$demoClient->id})\n");

        // 5. Генерация всех демо-данных
        $this->stdout("\n5. Генерация демо-данных...\n");
        try {
            $stats = DemoDataGeneratorService::generateDemoData($demoClient);
            $this->stdout("   ✓ Требования: {$stats['requirements']}\n");
            $this->stdout("   ✓ Риски: {$stats['risks']}\n");
            $this->stdout("   ✓ События: {$stats['events']}\n");
            $this->stdout("   ✓ Документы: {$stats['documents']}\n");
            $this->stdout("   ✓ Договоры: {$stats['contracts']}\n");
        } catch (\Exception $e) {
            $this->stdout("ERROR: Failed to generate demo data: " . $e->getMessage() . "\n");
            $this->stdout("Stack trace: " . $e->getTraceAsString() . "\n");
            return ExitCode::DATAERR;
        }

        // 6. Создание пользователя-клиента
        $this->stdout("\n6. Создание пользователя-клиента...\n");
        $clientUser = User::findOne(['email' => 'client@demo.local']);
        if (!$clientUser) {
            $clientUser = new User();
            $clientUser->name = 'Клиент Демо';
            $clientUser->email = 'client@demo.local';
            $clientUser->setPassword('client123');
            $clientUser->role = User::ROLE_CLIENT;
            $clientUser->client_id = $demoClient->id;
            $clientUser->generateAuthKey();
            
            if (!$clientUser->save()) {
                $this->stdout("ERROR: Failed to create client user: " . json_encode($clientUser->errors) . "\n");
                return ExitCode::DATAERR;
            }
            $this->stdout("   ✓ Пользователь создан\n");
        } else {
            // Обновляем client_id если пользователь уже существует
            $clientUser->client_id = $demoClient->id;
            $clientUser->save();
            $this->stdout("   ✓ Пользователь обновлён\n");
        }

        // 7. Вывод статистики
        $this->stdout("\n=== Статистика созданных данных ===\n");
        $requirements = Requirement::findAll(['client_id' => $demoClient->id]);
        $this->stdout("\nТребования (" . count($requirements) . "):\n");
        foreach ($requirements as $req) {
            $this->stdout("  - [{$req->status}] {$req->title} (дедлайн: {$req->deadline})\n");
        }

        $events = Event::findAll(['client_id' => $demoClient->id]);
        $this->stdout("\nСобытия (" . count($events) . "):\n");
        foreach ($events as $event) {
            $status = $event->completed ? '✓ Выполнено' : '○ Ожидается';
            $this->stdout("  - {$status}: {$event->title} ({$event->date})\n");
        }

        $documents = Document::findAll(['client_id' => $demoClient->id]);
        $this->stdout("\nДокументы (" . count($documents) . "):\n");
        foreach ($documents as $doc) {
            $this->stdout("  - [{$doc->status}] {$doc->type} ({$doc->file_path})\n");
        }

        $contracts = Contract::findAll(['client_id' => $demoClient->id]);
        $this->stdout("\nДоговоры (" . count($contracts) . "):\n");
        foreach ($contracts as $contract) {
            $this->stdout("  - [{$contract->status}] {$contract->number} ({$contract->date})\n");
        }

        $risks = Risk::find()
            ->innerJoin('requirements', 'risks.requirement_id = requirements.id')
            ->where(['requirements.client_id' => $demoClient->id])
            ->all();
        $this->stdout("\nРиски (" . count($risks) . "):\n");
        foreach ($risks as $risk) {
            $this->stdout("  - {$risk->article}: {$risk->fine_min} - {$risk->fine_max} ₽\n");
        }

        $this->stdout("\n=== Готово! ===\n");
        $this->stdout("Войдите в систему:\n");
        $this->stdout("  Email: client@demo.local\n");
        $this->stdout("  Password: client123\n\n");

        return ExitCode::OK;
    }
}


<?php

namespace console\controllers;

use common\models\Category;
use common\models\Client;
use common\services\DemoDataGeneratorService;
use common\services\RequirementGeneratorService;
use common\models\User;
use Yii;
use yii\console\Controller;

class SeedController extends Controller
{
    public function actionIndex()
    {
        $this->stdout("Seeding database...\n");

        // Создание категорий НВОС
        $categories = [
            ['title' => 'I категория', 'description' => 'Объекты I категории НВОС'],
            ['title' => 'II категория', 'description' => 'Объекты II категории НВОС'],
            ['title' => 'III категория', 'description' => 'Объекты III категории НВОС'],
            ['title' => 'IV категория', 'description' => 'Объекты IV категории НВОС'],
        ];

        foreach ($categories as $cat) {
            $category = Category::findOne(['title' => $cat['title']]);
            if (!$category) {
                $category = new Category();
                $category->title = $cat['title'];
                $category->description = $cat['description'];
                $category->save();
            }
        }

        // Создание пользователей
        $admin = User::findOne(['email' => 'admin@eco.local']);
        if (!$admin) {
            $admin = new User();
            $admin->name = 'Администратор';
            $admin->email = 'admin@eco.local';
            $admin->setPassword('admin123');
            $admin->role = User::ROLE_ADMIN;
            $admin->generateAuthKey();
            $admin->save();
        }

        $manager = User::findOne(['email' => 'manager@eco.local']);
        if (!$manager) {
            $manager = new User();
            $manager->name = 'Менеджер';
            $manager->email = 'manager@eco.local';
            $manager->setPassword('manager123');
            $manager->role = User::ROLE_MANAGER;
            $manager->generateAuthKey();
            $manager->save();
        }

        // Создание демо-клиента
        $categoryII = Category::findOne(['title' => 'II категория']);
        if (!$categoryII) {
            $this->stdout("ERROR: Category 'II категория' not found!\n");
            return;
        }

        $demoClient = Client::findOne(['name' => 'Демо-клиент']);
        if (!$demoClient) {
            $demoClient = new Client();
            $demoClient->name = 'Демо-клиент';
            $demoClient->category_id = $categoryII->id;
            $demoClient->has_well = true;
            $demoClient->has_river = false;
            $demoClient->has_byproduct = true;
            if (!$demoClient->save()) {
                $this->stdout("ERROR: Failed to create demo client: " . json_encode($demoClient->errors) . "\n");
                return;
            }
        }

        // Генерация всех демо-данных (для нового и существующего клиента)
        try {
            $stats = DemoDataGeneratorService::generateDemoData($demoClient);
            $this->stdout("Demo data generated:\n");
            $this->stdout("  - Requirements: {$stats['requirements']}\n");
            $this->stdout("  - Risks: {$stats['risks']}\n");
            $this->stdout("  - Events: {$stats['events']}\n");
            $this->stdout("  - Documents: {$stats['documents']}\n");
            $this->stdout("  - Contracts: {$stats['contracts']}\n");
        } catch (\Exception $e) {
            $this->stdout("WARNING: Failed to generate demo data: " . $e->getMessage() . "\n");
            $this->stdout("Stack trace: " . $e->getTraceAsString() . "\n");
        }

        // Создание или обновление пользователя-клиента
        $clientUser = User::findOne(['email' => 'client@demo.local']);
        if (!$clientUser && $demoClient->id) {
            $clientUser = new User();
            $clientUser->name = 'Клиент Демо';
            $clientUser->email = 'client@demo.local';
            $clientUser->setPassword('client123');
            $clientUser->role = User::ROLE_CLIENT;
            $clientUser->client_id = $demoClient->id;
            $clientUser->generateAuthKey();
            if (!$clientUser->save()) {
                $this->stdout("ERROR: Failed to create client user: " . json_encode($clientUser->errors) . "\n");
            }
        } elseif ($clientUser && $demoClient->id && $clientUser->client_id != $demoClient->id) {
            // Обновляем client_id если он не совпадает
            $clientUser->client_id = $demoClient->id;
            $clientUser->save();
            $this->stdout("Updated client user client_id to {$demoClient->id}\n");
        }

        $this->stdout("Database seeded successfully!\n");
    }
}

#!/bin/bash
# ==========================================
# СОЗДАНИЕ ТЕСТОВЫХ КЛИЕНТОВ ДЛЯ ПРОВЕРКИ
# ==========================================
# Удаляет всех клиентов и создает 4 тестовых клиента (по одному для каждой категории)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🧪 СОЗДАНИЕ ТЕСТОВЫХ КЛИЕНТОВ"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project/backend

# 1. Удаление всех существующих клиентов
echo -e "${YELLOW}[1/3] Удаление всех существующих клиентов...${NC}"

php yii shell << 'PHP_EOF'
// Удаляем все требования и риски
echo "Удаление требований и рисков...\n";
$reqCount = \common\models\Requirement::find()->count();
$riskCount = \common\models\Risk::find()->count();
echo "Найдено требований: $reqCount\n";
echo "Найдено рисков: $riskCount\n";

// Удаляем риски
\Yii::$app->db->createCommand("DELETE FROM risks")->execute();
echo "Риски удалены\n";

// Удаляем требования
\common\models\Requirement::deleteAll();
echo "Требования удалены\n";

// Удаляем документы, договоры, события
\common\models\Document::deleteAll();
\common\models\Contract::deleteAll();
\common\models\Event::deleteAll();
echo "Документы, договоры и события удалены\n";

// Удаляем клиентов
$clientCount = \common\models\Client::find()->count();
echo "Найдено клиентов: $clientCount\n";
\common\models\Client::deleteAll();
echo "Все клиенты удалены\n";

echo "✅ Очистка завершена\n";
PHP_EOF

echo -e "${GREEN}✅ Все клиенты и связанные данные удалены${NC}"
echo ""

# 2. Создание тестовых клиентов
echo -e "${YELLOW}[2/3] Создание тестовых клиентов...${NC}"

php yii shell << 'PHP_EOF'
use common\models\Client;
use common\services\RequirementGeneratorService;

// Клиент I категории (без дополнительных параметров)
$client1 = new Client();
$client1->name = 'Тестовый клиент I категории';
$client1->category_id = 1;
$client1->has_well = false;
$client1->has_river = false;
$client1->has_byproduct = false;
$client1->responsible_person = 'Иванов Иван Иванович';
if ($client1->save()) {
    echo "✅ Создан клиент I категории (ID: {$client1->id})\n";
    RequirementGeneratorService::generateRequirements($client1);
    $reqCount = \common\models\Requirement::find()->where(['client_id' => $client1->id])->count();
    echo "   Создано требований: $reqCount (ожидается: 18)\n";
} else {
    echo "❌ Ошибка создания клиента I категории: " . json_encode($client1->errors) . "\n";
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
    echo "✅ Создан клиент II категории (ID: {$client2->id})\n";
    RequirementGeneratorService::generateRequirements($client2);
    $reqCount = \common\models\Requirement::find()->where(['client_id' => $client2->id])->count();
    echo "   Создано требований: $reqCount (ожидается: 20 = 18 базовых + 2 река)\n";
} else {
    echo "❌ Ошибка создания клиента II категории: " . json_encode($client2->errors) . "\n";
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
    echo "✅ Создан клиент III категории (ID: {$client3->id})\n";
    RequirementGeneratorService::generateRequirements($client3);
    $reqCount = \common\models\Requirement::find()->where(['client_id' => $client3->id])->count();
    echo "   Создано требований: $reqCount (ожидается: 16)\n";
} else {
    echo "❌ Ошибка создания клиента III категории: " . json_encode($client3->errors) . "\n";
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
    echo "✅ Создан клиент IV категории (ID: {$client4->id})\n";
    RequirementGeneratorService::generateRequirements($client4);
    $reqCount = \common\models\Requirement::find()->where(['client_id' => $client4->id])->count();
    echo "   Создано требований: $reqCount (ожидается: 10 = 8 базовых + 1 скважина + 1 побочный продукт)\n";
} else {
    echo "❌ Ошибка создания клиента IV категории: " . json_encode($client4->errors) . "\n";
}

echo "\n✅ Все тестовые клиенты созданы\n";
PHP_EOF

echo ""

# 3. Итоговая статистика
echo -e "${YELLOW}[3/3] Итоговая статистика...${NC}"

php yii shell << 'PHP_EOF'
$clients = \common\models\Client::find()->all();
echo "\n📊 СТАТИСТИКА:\n";
echo "==========================================\n";
foreach ($clients as $client) {
    $reqCount = \common\models\Requirement::find()->where(['client_id' => $client->id])->count();
    $expectedCounts = [
        1 => 18,
        2 => 18 + ($client->has_river ? 2 : 0),
        3 => 16,
        4 => 8 + ($client->has_well ? 1 : 0) + ($client->has_byproduct ? 1 : 0),
    ];
    $expected = $expectedCounts[$client->category_id] ?? 0;
    $status = ($reqCount == $expected) ? '✅' : '❌';
    echo "$status Клиент ID {$client->id}: {$client->name}\n";
    echo "   Категория: {$client->category_id}\n";
    echo "   Скважина: " . ($client->has_well ? 'да' : 'нет') . "\n";
    echo "   Река: " . ($client->has_river ? 'да' : 'нет') . "\n";
    echo "   Побочный продукт: " . ($client->has_byproduct ? 'да' : 'нет') . "\n";
    echo "   Требований: $reqCount (ожидается: $expected)\n";
    echo "\n";
}
PHP_EOF

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Тестовые клиенты созданы. Проверьте на сайте:"
echo "  - Клиент I категории: должно быть 18 требований"
echo "  - Клиент II категории (с рекой): должно быть 20 требований"
echo "  - Клиент III категории: должно быть 16 требований"
echo "  - Клиент IV категории (скважина + побочный продукт): должно быть 10 требований"
echo ""


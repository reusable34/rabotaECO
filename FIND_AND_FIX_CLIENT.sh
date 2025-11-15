#!/bin/bash
# ==========================================
# НАЙТИ КЛИЕНТА ПО НАЗВАНИЮ И ИСПРАВИТЬ ТРЕБОВАНИЯ
# ==========================================

if [ -z "$1" ]; then
    echo "❌ Ошибка: не указано название клиента (или часть названия)"
    echo ""
    echo "Использование: $0 <НАЗВАНИЕ_КЛИЕНТА>"
    echo ""
    echo "Пример:"
    echo "  $0 'IV категории'    - найти и исправить клиента с 'IV категории' в названии"
    echo "  $0 'скважина'         - найти и исправить клиента с 'скважина' в названии"
    exit 1
fi

SEARCH_NAME="$1"
PROJECT_DIR="/opt/eco-project"
BACKEND_DIR="$PROJECT_DIR/backend"

cd "$PROJECT_DIR" || exit 1

echo "=========================================="
echo "🔍 ПОИСК КЛИЕНТА: '$SEARCH_NAME'"
echo "=========================================="
echo ""

# Ищем клиента по названию
cd "$BACKEND_DIR" || exit 1

# Создаем временный PHP скрипт для поиска
TMP_SCRIPT=$(mktemp /tmp/find_client_XXXXXX.php)
cat > "$TMP_SCRIPT" << 'PHPSCRIPT'
<?php
require __DIR__ . '/vendor/autoload.php';
require __DIR__ . '/vendor/yiisoft/yii2/Yii.php';

$config = yii\helpers\ArrayHelper::merge(
    require __DIR__ . '/common/config/main.php',
    require __DIR__ . '/console/config/main.php'
);

new yii\console\Application($config);

$searchName = $argv[1] ?? '';
if (!$searchName) {
    echo "❌ Укажите название для поиска\n";
    exit(1);
}

$clients = \common\models\Client::find()
    ->where(['like', 'name', $searchName])
    ->all();

if (empty($clients)) {
    echo "❌ Клиенты с названием содержащим '$searchName' не найдены\n";
    exit(1);
}

echo "Найдено клиентов: " . count($clients) . "\n\n";
foreach ($clients as $client) {
    echo "ID: {$client->id}\n";
    echo "Название: {$client->name}\n";
    echo "Категория: {$client->category_id}\n";
    echo "Скважина: " . ($client->has_well ? 'да' : 'нет') . "\n";
    echo "Река: " . ($client->has_river ? 'да' : 'нет') . "\n";
    echo "Побочный продукт: " . ($client->has_byproduct ? 'да' : 'нет') . "\n";
    
    $reqCount = \common\models\Requirement::find()->where(['client_id' => $client->id])->count();
    echo "Требований в БД: $reqCount\n";
    
    $expectedBaseCounts = [1 => 18, 2 => 18, 3 => 16, 4 => 8];
    $expectedBase = $expectedBaseCounts[$client->category_id] ?? 0;
    $expectedAdditional = 0;
    if ($client->has_well) $expectedAdditional++;
    if ($client->has_river) $expectedAdditional += 2;
    if ($client->has_byproduct) $expectedAdditional++;
    $expectedTotal = $expectedBase + $expectedAdditional;
    
    echo "Ожидается: $expectedTotal\n";
    
    if ($reqCount != $expectedTotal) {
        echo "❌ НЕСООТВЕТСТВИЕ!\n";
    } else {
        echo "✅ Правильно\n";
    }
    echo "\n";
    
    // Пересчитываем требования для первого найденного клиента
    if ($client === reset($clients)) {
        echo "Пересчет требований для клиента ID {$client->id}...\n";
        try {
            $transaction = Yii::$app->db->beginTransaction();
            
            // Удаляем все старые требования
            $deleted = \common\models\Requirement::deleteAll(['client_id' => $client->id]);
            echo "Удалено старых требований: $deleted\n";
            
            // Удаляем риски
            Yii::$app->db->createCommand("DELETE FROM risks WHERE requirement_id IN (SELECT id FROM requirements WHERE client_id = :client_id)", [':client_id' => $client->id])->execute();
            
            // Генерируем новые
            $requirements = \common\services\RequirementGeneratorService::generateRequirements($client);
            
            $transaction->commit();
            
            echo "✅ Создано новых требований: " . count($requirements) . "\n";
            echo "\nСПИСОК СОЗДАННЫХ ТРЕБОВАНИЙ:\n";
            foreach ($requirements as $idx => $req) {
                echo sprintf("%2d. %s\n", $idx + 1, $req->title);
            }
        } catch (\Exception $e) {
            $transaction->rollBack();
            echo "❌ ОШИБКА: {$e->getMessage()}\n";
            exit(1);
        }
    }
}
PHPSCRIPT

php "$TMP_SCRIPT" "$SEARCH_NAME"
EXIT_CODE=$?
rm -f "$TMP_SCRIPT"

exit $EXIT_CODE


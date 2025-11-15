#!/bin/bash
# ==========================================
# ПРОВЕРКА ПАРАМЕТРОВ КЛИЕНТА В БД
# ==========================================

if [ -z "$1" ]; then
    echo "❌ Ошибка: не указан ID клиента"
    echo ""
    echo "Использование: $0 <ID_КЛИЕНТА>"
    echo ""
    echo "Примеры:"
    echo "  $0 1    - проверить клиента с ID=1"
    echo "  $0 2    - проверить клиента с ID=2"
    echo ""
    echo "Чтобы узнать ID клиента, выполните:"
    echo "  cd /opt/eco-project/backend && php yii client/list"
    exit 1
fi

CLIENT_ID=$1
BACKEND_DIR="/opt/eco-project/backend"

cd "$BACKEND_DIR" || exit 1

# Создаем временный PHP скрипт для проверки
TMP_SCRIPT=$(mktemp /tmp/check_client_XXXXXX.php)
cat > "$TMP_SCRIPT" << 'PHPSCRIPT'
<?php
require __DIR__ . '/vendor/autoload.php';
require __DIR__ . '/vendor/yiisoft/yii2/Yii.php';

$config = yii\helpers\ArrayHelper::merge(
    require __DIR__ . '/common/config/main.php',
    require __DIR__ . '/api/config/main.php'
);

new yii\web\Application($config);

$clientId = $argv[1] ?? null;
if (!$clientId) {
    echo "❌ Укажите ID клиента\n";
    exit(1);
}

$client = \common\models\Client::findOne($clientId);
if (!$client) {
    echo "❌ Клиент с ID $clientId не найден\n";
    exit(1);
}

echo "📋 ПАРАМЕТРЫ КЛИЕНТА:\n";
echo "==========================================\n";
echo "ID: {$client->id}\n";
echo "Название: {$client->name}\n";
echo "Категория: {$client->category_id}\n";
echo "has_well (тип: " . gettype($client->has_well) . "): " . var_export($client->has_well, true) . "\n";
echo "has_river (тип: " . gettype($client->has_river) . "): " . var_export($client->has_river, true) . "\n";
echo "has_byproduct (тип: " . gettype($client->has_byproduct) . "): " . var_export($client->has_byproduct, true) . "\n";
echo "Ответственный: {$client->responsible_person}\n";
echo "\n";

// Проверяем требования
$reqCount = \common\models\Requirement::find()->where(['client_id' => $client->id])->count();
echo "📊 ТРЕБОВАНИЯ:\n";
echo "==========================================\n";
echo "Всего требований: $reqCount\n";
echo "\n";

// Ожидаемое количество
$expectedCounts = [
    1 => 18 + ($client->has_well ? 1 : 0) + ($client->has_river ? 2 : 0) + ($client->has_byproduct ? 1 : 0),
    2 => 18 + ($client->has_well ? 1 : 0) + ($client->has_river ? 2 : 0) + ($client->has_byproduct ? 1 : 0),
    3 => 16 + ($client->has_well ? 1 : 0) + ($client->has_river ? 2 : 0) + ($client->has_byproduct ? 1 : 0),
    4 => 8 + ($client->has_well ? 1 : 0) + ($client->has_river ? 2 : 0) + ($client->has_byproduct ? 1 : 0),
];
$expected = $expectedCounts[$client->category_id] ?? 0;
echo "Ожидается требований: $expected\n";
echo "\n";

if ($reqCount != $expected) {
    echo "❌ НЕСООТВЕТСТВИЕ! Ожидалось $expected, но найдено $reqCount\n";
} else {
    echo "✅ Количество требований правильное\n";
}

echo "\n";
echo "📝 СПИСОК ВСЕХ ТРЕБОВАНИЙ:\n";
echo "==========================================\n";
$requirements = \common\models\Requirement::find()->where(['client_id' => $client->id])->orderBy('id')->all();
foreach ($requirements as $idx => $req) {
    echo sprintf("%2d. [ID: %d] %s\n", $idx + 1, $req->id, $req->title);
}
PHPSCRIPT

php "$TMP_SCRIPT" "$CLIENT_ID"
rm -f "$TMP_SCRIPT"


#!/bin/bash
# ==========================================
# ПРОВЕРКА ПАРАМЕТРОВ КЛИЕНТА В БД
# ==========================================

if [ -z "$1" ]; then
    echo "Использование: $0 <ID_КЛИЕНТА>"
    echo "Пример: $0 1"
    exit 1
fi

CLIENT_ID=$1

cd /opt/eco-project/backend

echo "Проверка параметров клиента ID: $CLIENT_ID"
echo ""

php yii shell << EOF
\$client = \common\models\Client::findOne($CLIENT_ID);
if (!\$client) {
    echo "❌ Клиент с ID $CLIENT_ID не найден\n";
    exit(1);
}

echo "📋 ПАРАМЕТРЫ КЛИЕНТА:\n";
echo "==========================================\n";
echo "ID: {\$client->id}\n";
echo "Название: {\$client->name}\n";
echo "Категория: {\$client->category_id}\n";
echo "has_well (тип: " . gettype(\$client->has_well) . "): " . var_export(\$client->has_well, true) . "\n";
echo "has_river (тип: " . gettype(\$client->has_river) . "): " . var_export(\$client->has_river, true) . "\n";
echo "has_byproduct (тип: " . gettype(\$client->has_byproduct) . "): " . var_export(\$client->has_byproduct, true) . "\n";
echo "Ответственный: {\$client->responsible_person}\n";
echo "\n";

// Проверяем требования
\$reqCount = \common\models\Requirement::find()->where(['client_id' => \$client->id])->count();
echo "📊 ТРЕБОВАНИЯ:\n";
echo "==========================================\n";
echo "Всего требований: \$reqCount\n";
echo "\n";

// Ожидаемое количество
\$expectedCounts = [
    1 => 18 + (\$client->has_well ? 1 : 0) + (\$client->has_river ? 2 : 0) + (\$client->has_byproduct ? 1 : 0),
    2 => 18 + (\$client->has_well ? 1 : 0) + (\$client->has_river ? 2 : 0) + (\$client->has_byproduct ? 1 : 0),
    3 => 16 + (\$client->has_well ? 1 : 0) + (\$client->has_river ? 2 : 0) + (\$client->has_byproduct ? 1 : 0),
    4 => 8 + (\$client->has_well ? 1 : 0) + (\$client->has_river ? 2 : 0) + (\$client->has_byproduct ? 1 : 0),
];
\$expected = \$expectedCounts[\$client->category_id] ?? 0;
echo "Ожидается требований: \$expected\n";
echo "\n";

if (\$reqCount != \$expected) {
    echo "❌ НЕСООТВЕТСТВИЕ! Ожидалось \$expected, но найдено \$reqCount\n";
} else {
    echo "✅ Количество требований правильное\n";
}

echo "\n";
echo "📝 СПИСОК ВСЕХ ТРЕБОВАНИЙ:\n";
echo "==========================================\n";
\$requirements = \common\models\Requirement::find()->where(['client_id' => \$client->id])->orderBy('id')->all();
foreach (\$requirements as \$idx => \$req) {
    echo sprintf("%2d. [ID: %d] %s\n", \$idx + 1, \$req->id, \$req->title);
}
EOF


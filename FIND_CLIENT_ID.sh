#!/bin/bash
# ==========================================
# НАЙТИ ID КЛИЕНТА ПО НАЗВАНИЮ
# ==========================================

if [ -z "$1" ]; then
    echo "Использование: $0 <ЧАСТЬ_НАЗВАНИЯ>"
    echo "Пример: $0 'IV категории'"
    exit 1
fi

SEARCH_NAME="$1"
BACKEND_DIR="/opt/eco-project/backend"

cd "$BACKEND_DIR" || exit 1

php yii shell << EOF
\$searchName = '$SEARCH_NAME';
\$clients = \common\models\Client::find()
    ->where(['like', 'name', \$searchName])
    ->all();

if (empty(\$clients)) {
    echo "❌ Клиенты с названием содержащим '\$searchName' не найдены\n";
    exit(1);
}

echo "Найдено клиентов: " . count(\$clients) . "\n\n";
foreach (\$clients as \$client) {
    echo "ID: {\$client->id}\n";
    echo "Название: {\$client->name}\n";
    echo "Категория: {\$client->category_id}\n";
    echo "Скважина: " . (\$client->has_well ? 'да' : 'нет') . "\n";
    echo "Река: " . (\$client->has_river ? 'да' : 'нет') . "\n";
    echo "Побочный продукт: " . (\$client->has_byproduct ? 'да' : 'нет') . "\n";
    
    \$reqCount = \common\models\Requirement::find()->where(['client_id' => \$client->id])->count();
    echo "Требований в БД: \$reqCount\n";
    
    \$expectedBaseCounts = [1 => 18, 2 => 18, 3 => 16, 4 => 8];
    \$expectedBase = \$expectedBaseCounts[\$client->category_id] ?? 0;
    \$expectedAdditional = 0;
    if (\$client->has_well) \$expectedAdditional++;
    if (\$client->has_river) \$expectedAdditional += 2;
    if (\$client->has_byproduct) \$expectedAdditional++;
    \$expectedTotal = \$expectedBase + \$expectedAdditional;
    
    echo "Ожидается: \$expectedTotal\n";
    echo "\n";
}
EOF


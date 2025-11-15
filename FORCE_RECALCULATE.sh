#!/bin/bash
# ==========================================
# ПРИНУДИТЕЛЬНЫЙ ПЕРЕСЧЕТ ТРЕБОВАНИЙ
# ==========================================
# Удаляет ВСЕ требования для клиента и создает новые

if [ -z "$1" ]; then
    echo "Использование: $0 <ID_КЛИЕНТА>"
    echo "Пример: $0 1"
    exit 1
fi

CLIENT_ID=$1

cd /opt/eco-project/backend

echo "Удаление всех требований для клиента ID: $CLIENT_ID"
php yii shell << EOF
\$clientId = $CLIENT_ID;
echo "Удаление требований для client_id=\$clientId\n";
\$deleted = \common\models\Requirement::deleteAll(['client_id' => \$clientId]);
echo "Удалено требований: \$deleted\n";
\$riskDeleted = \Yii::\$app->db->createCommand("DELETE FROM risks WHERE requirement_id IN (SELECT id FROM requirements WHERE client_id = :id)", [':id' => \$clientId])->execute();
echo "Удалено рисков: \$riskDeleted\n";
EOF

echo ""
echo "Пересчет требований через консольную команду..."
php yii recalculate-all/client $CLIENT_ID

echo ""
echo "Готово! Проверьте результат."


#!/bin/bash
# ==========================================
# ПРИНУДИТЕЛЬНЫЙ ПЕРЕСЧЕТ ТРЕБОВАНИЙ ДЛЯ КЛИЕНТА
# ==========================================

if [ -z "$1" ]; then
    echo "❌ Ошибка: не указан ID клиента"
    echo ""
    echo "Использование: $0 <ID_КЛИЕНТА>"
    echo ""
    echo "Пример:"
    echo "  $0 4    - пересчитать требования для клиента с ID=4"
    echo ""
    echo "Чтобы узнать ID клиента, выполните:"
    echo "  cd /opt/eco-project/backend && php yii client/list"
    exit 1
fi

CLIENT_ID=$1
BACKEND_DIR="/opt/eco-project/backend"
API_URL="http://localhost:8082"

cd "$BACKEND_DIR" || exit 1

echo "🔄 ПРИНУДИТЕЛЬНЫЙ ПЕРЕСЧЕТ ТРЕБОВАНИЙ ДЛЯ КЛИЕНТА ID: $CLIENT_ID"
echo "=========================================="
echo ""

# Сначала получаем токен админа
echo "[1/3] Получение токена администратора..."
ADMIN_EMAIL="admin@eco.local"
ADMIN_PASSWORD="admin"  # Замените на реальный пароль админа

LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "❌ Ошибка: не удалось получить токен"
    echo "Ответ сервера: $LOGIN_RESPONSE"
    exit 1
fi

echo "✅ Токен получен"
echo ""

# Получаем информацию о клиенте
echo "[2/3] Получение информации о клиенте..."
CLIENT_INFO=$(curl -s -X GET "$API_URL/client/$CLIENT_ID" \
  -H "Authorization: Bearer $TOKEN")

CLIENT_NAME=$(echo "$CLIENT_INFO" | grep -o '"name":"[^"]*' | cut -d'"' -f4)
CATEGORY_ID=$(echo "$CLIENT_INFO" | grep -o '"category_id":[0-9]*' | cut -d':' -f2)
HAS_WELL=$(echo "$CLIENT_INFO" | grep -o '"has_well":[^,}]*' | cut -d':' -f2 | tr -d ' ')
HAS_RIVER=$(echo "$CLIENT_INFO" | grep -o '"has_river":[^,}]*' | cut -d':' -f2 | tr -d ' ')
HAS_BYPRODUCT=$(echo "$CLIENT_INFO" | grep -o '"has_byproduct":[^,}]*' | cut -d':' -f2 | tr -d ' ')

echo "Клиент: $CLIENT_NAME"
echo "Категория: $CATEGORY_ID"
echo "Скважина: $HAS_WELL"
echo "Река: $HAS_RIVER"
echo "Побочный продукт: $HAS_BYPRODUCT"
echo ""

# Пересчитываем требования
echo "[3/3] Пересчет требований..."
RECALC_RESPONSE=$(curl -s -X POST "$API_URL/requirement/recalculate" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"client_id\": $CLIENT_ID,
    \"category_id\": $CATEGORY_ID,
    \"has_well\": $HAS_WELL,
    \"has_river\": $HAS_RIVER,
    \"has_byproduct\": $HAS_BYPRODUCT
  }")

if echo "$RECALC_RESPONSE" | grep -q '"success":true'; then
    echo "✅ Требования успешно пересчитаны"
    echo ""
    echo "Ответ сервера:"
    echo "$RECALC_RESPONSE" | head -20
else
    echo "❌ Ошибка при пересчете требований"
    echo "Ответ сервера: $RECALC_RESPONSE"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ ГОТОВО!"
echo ""
echo "Проверьте требования в админ-панели или выполните:"
echo "  cd /opt/eco-project && bash CHECK_CLIENT.sh $CLIENT_ID"


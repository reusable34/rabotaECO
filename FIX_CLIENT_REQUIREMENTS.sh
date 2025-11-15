#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ ТРЕБОВАНИЙ ДЛЯ КЛИЕНТА - ВСЕ В ОДНОЙ КОМАНДЕ
# ==========================================

if [ -z "$1" ]; then
    echo "❌ Ошибка: не указан ID клиента"
    echo ""
    echo "Использование: $0 <ID_КЛИЕНТА>"
    echo ""
    echo "Пример:"
    echo "  $0 4    - исправить требования для клиента с ID=4"
    exit 1
fi

CLIENT_ID=$1
PROJECT_DIR="/opt/eco-project"
BACKEND_DIR="$PROJECT_DIR/backend"
API_URL="http://localhost:8082"

cd "$PROJECT_DIR" || exit 1

echo "=========================================="
echo "🔧 ИСПРАВЛЕНИЕ ТРЕБОВАНИЙ ДЛЯ КЛИЕНТА ID: $CLIENT_ID"
echo "=========================================="
echo ""

# 1. Обновление кода
echo "[1/4] Обновление кода из репозитория..."
git pull > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Код обновлен"
else
    echo "⚠️ Предупреждение: не удалось обновить код (возможно, уже актуальный)"
fi
echo ""

# 2. Пересборка фронтенда
echo "[2/4] Пересборка фронтенда..."
cd "$PROJECT_DIR/frontend" || exit 1
npm run build > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Фронтенд пересобран"
else
    echo "⚠️ Предупреждение: ошибка при сборке фронтенда"
fi
echo ""

# 3. Перезапуск Next.js
echo "[3/4] Перезапуск Next.js..."
systemctl restart nextjs > /dev/null 2>&1
sleep 2
if systemctl is-active --quiet nextjs; then
    echo "✅ Next.js перезапущен"
else
    echo "⚠️ Предупреждение: Next.js не запустился"
fi
echo ""

# 4. Проверка и пересчет требований
echo "[4/4] Проверка параметров клиента и пересчет требований..."
cd "$BACKEND_DIR" || exit 1

# Получаем токен админа
ADMIN_EMAIL="admin@eco.local"
ADMIN_PASSWORD="admin"  # Замените на реальный пароль, если отличается

LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "❌ Ошибка: не удалось получить токен администратора"
    echo "Проверьте логин и пароль в скрипте"
    exit 1
fi

# Получаем информацию о клиенте
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
    REQ_COUNT=$(echo "$RECALC_RESPONSE" | grep -o '"count":[0-9]*' | cut -d':' -f2)
    echo "✅ Требования успешно пересчитаны! Создано требований: $REQ_COUNT"
else
    echo "❌ Ошибка при пересчете требований"
    echo "Ответ: $RECALC_RESPONSE"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ ГОТОВО!"
echo "=========================================="
echo ""
echo "Проверьте требования в админ-панели или выполните:"
echo "  cd /opt/eco-project && bash CHECK_CLIENT.sh $CLIENT_ID"


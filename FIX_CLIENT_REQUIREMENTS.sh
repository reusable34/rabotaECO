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

# Используем консольную команду Yii для пересчета (не требует токена)
echo "Пересчет требований для клиента ID: $CLIENT_ID..."
php yii recalculate-all/client $CLIENT_ID

if [ $? -eq 0 ]; then
    echo "✅ Требования успешно пересчитаны!"
else
    echo "❌ Ошибка при пересчете требований"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ ГОТОВО!"
echo "=========================================="
echo ""
echo "Проверьте требования в админ-панели или выполните:"
echo "  cd /opt/eco-project && bash CHECK_CLIENT.sh $CLIENT_ID"


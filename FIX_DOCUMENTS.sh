#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ ПРАВ ДОСТУПА ДЛЯ ЗАГРУЗКИ ДОКУМЕНТОВ
# ==========================================

PROJECT_DIR="/opt/eco-project"
BACKEND_DIR="$PROJECT_DIR/backend"

cd "$PROJECT_DIR" || exit 1

echo "=========================================="
echo "🔧 ИСПРАВЛЕНИЕ ПРАВ ДОСТУПА ДЛЯ ДОКУМЕНТОВ"
echo "=========================================="
echo ""

# Определяем владельца (www-data для Debian/Ubuntu, root для других)
if [ -f /etc/debian_version ]; then
    OWNER="www-data"
    GROUP="www-data"
else
    OWNER="root"
    GROUP="root"
fi

echo "[1/3] Проверка и создание директории storage..."
STORAGE_DIR="$BACKEND_DIR/api/storage"

if [ ! -d "$STORAGE_DIR" ]; then
    mkdir -p "$STORAGE_DIR"
    echo "✅ Директория storage создана"
else
    echo "✅ Директория storage существует"
fi

# Устанавливаем права на storage
chmod -R 755 "$STORAGE_DIR"
chown -R $OWNER:$GROUP "$STORAGE_DIR" 2>/dev/null || chown -R root:root "$STORAGE_DIR"
echo "✅ Права доступа к storage установлены"

# Создаем директорию для клиентов
CLIENTS_DIR="$STORAGE_DIR/clients"
if [ ! -d "$CLIENTS_DIR" ]; then
    mkdir -p "$CLIENTS_DIR"
    chmod 755 "$CLIENTS_DIR"
    chown $OWNER:$GROUP "$CLIENTS_DIR" 2>/dev/null || chown root:root "$CLIENTS_DIR"
    echo "✅ Директория clients создана"
fi

echo ""
echo "[2/3] Проверка прав доступа к runtime..."
RUNTIME_DIR="$BACKEND_DIR/api/runtime"

if [ ! -d "$RUNTIME_DIR" ]; then
    mkdir -p "$RUNTIME_DIR"
    echo "✅ Директория runtime создана"
fi

chmod -R 755 "$RUNTIME_DIR"
chown -R $OWNER:$GROUP "$RUNTIME_DIR" 2>/dev/null || chown -R root:root "$RUNTIME_DIR"
echo "✅ Права доступа к runtime установлены"

echo ""
echo "[3/3] Проверка прав на запись..."
if [ -w "$STORAGE_DIR" ]; then
    echo "✅ Директория storage доступна для записи"
else
    echo "❌ Директория storage НЕ доступна для записи"
    echo "Попытка исправления..."
    chmod 755 "$STORAGE_DIR"
    chown $OWNER:$GROUP "$STORAGE_DIR" 2>/dev/null || chown root:root "$STORAGE_DIR"
fi

echo ""
echo "=========================================="
echo "✅ ГОТОВО!"
echo "=========================================="
echo ""
echo "Проверьте загрузку документов в интерфейсе"


#!/bin/bash
# ==========================================
# СКРИПТ ДЛЯ ВЫПОЛНЕНИЯ НА ХОСТЕ PROXMOX
# ==========================================
# Выполните на хосте Proxmox (НЕ в контейнере!)
# Через Shell в веб-интерфейсе: выберите узел "citadel" → ">_ Shell"

CT_ID=102

echo "=========================================="
echo "🔧 НАСТРОЙКА КОНТЕЙНЕРА $CT_ID ДЛЯ DOCKER"
echo "=========================================="
echo ""

# 1. Включить features для Docker
echo "[1/3] Включение features (nesting, keyctl, fuse)..."
pct set $CT_ID -features nesting=1,keyctl=1,fuse=1

# 2. Настроить sysctl на хосте Proxmox
echo "[2/3] Настройка sysctl на хосте..."
if ! grep -q "net.ipv4.ip_unprivileged_port_start=0" /etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv4.ip_unprivileged_port_start=0" >> /etc/sysctl.conf
    sysctl -p
    echo "✅ sysctl настроен"
else
    echo "✅ sysctl уже настроен"
fi

# 3. Перезапустить контейнер
echo "[3/3] Перезапуск контейнера $CT_ID..."
pct reboot $CT_ID

echo ""
echo "=========================================="
echo "✅ ГОТОВО!"
echo "=========================================="
echo ""
echo "Подождите 30 секунд, затем войдите в контейнер 102 и выполните:"
echo "  cd /opt/eco-project && bash GIT_DEPLOY.sh"
echo ""


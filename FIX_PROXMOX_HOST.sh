#!/bin/bash
# ==========================================
# СКРИПТ ДЛЯ ВЫПОЛНЕНИЯ НА ХОСТЕ PROXMOX
# ==========================================
# Выполните на хосте Proxmox (НЕ в контейнере!)

CT_ID=102

echo "Настройка контейнера $CT_ID для работы с Docker..."

# 1. Включить features
pct set $CT_ID -features nesting=1,keyctl=1,fuse=1

# 2. Настроить sysctl на хосте
echo "net.ipv4.ip_unprivileged_port_start=0" >> /etc/sysctl.conf
sysctl -p

# 3. Перезапустить контейнер
echo "Перезапускаю контейнер..."
pct reboot $CT_ID

echo "Готово! Подождите 30 секунд и войдите в контейнер."


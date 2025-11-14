#!/bin/bash
# Проверка контейнера и деплой - выполнить в контейнере

echo "=== ПРОВЕРКА ==="
echo "ОС: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Пользователь: $(whoami)"
echo "IP: $(hostname -I | awk '{print $1}')"
echo ""
echo "Порты:"
ss -tulpn | grep LISTEN | awk '{print $5}' | cut -d: -f2 | sort -u
echo ""
echo "Docker: $(docker --version 2>/dev/null || echo 'НЕТ')"
echo "Docker Compose: $(docker-compose --version 2>/dev/null || docker compose version 2>/dev/null || echo 'НЕТ')"
echo ""
echo "=== ДЕПЛОЙ ==="
echo "Если всё ОК, выполните:"
echo "  cd /opt && mkdir -p eco-project && cd eco-project"
echo "  # Загрузите проект сюда"
echo "  bash DEPLOY_ANY_CONTAINER.sh"


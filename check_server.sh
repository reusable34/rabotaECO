#!/bin/bash
echo "=========================================="
echo "ПРОВЕРКА СЕРВЕРА ДЛЯ ДЕПЛОЯ"
echo "=========================================="
echo ""
echo "1. ИНФОРМАЦИЯ О СИСТЕМЕ:"
echo "----------------------------------------"
echo "ОС: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Ядро: $(uname -r)"
echo "Пользователь: $(whoami)"
echo "Текущая директория: $(pwd)"
echo ""
echo "2. РЕСУРСЫ:"
echo "----------------------------------------"
echo "Диск:"
df -h | grep -E '^/dev|Filesystem'
echo ""
echo "Память:"
free -h
echo ""
echo "3. УСТАНОВЛЕННЫЕ ИНСТРУМЕНТЫ:"
echo "----------------------------------------"
echo -n "Docker: "
if command -v docker &> /dev/null; then
    docker --version
else
    echo "НЕ УСТАНОВЛЕН"
fi
echo -n "Docker Compose: "
if command -v docker-compose &> /dev/null; then
    docker-compose --version
elif docker compose version &> /dev/null; then
    docker compose version
else
    echo "НЕ УСТАНОВЛЕН"
fi
echo -n "Git: "
if command -v git &> /dev/null; then
    git --version
else
    echo "НЕ УСТАНОВЛЕН"
fi
echo -n "Node.js: "
if command -v node &> /dev/null; then
    node --version
else
    echo "НЕ УСТАНОВЛЕН"
fi
echo -n "PHP: "
if command -v php &> /dev/null; then
    php --version | head -n 1
else
    echo "НЕ УСТАНОВЛЕН"
fi
echo ""
echo "4. СЕТЬ:"
echo "----------------------------------------"
echo "IP адреса:"
ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -3
echo ""
echo "Проверка интернета:"
if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    echo "✅ Интернет доступен"
else
    echo "❌ Интернет НЕ доступен"
fi
echo ""
echo "Занятые порты:"
ss -tulpn 2>/dev/null | grep LISTEN | awk '{print $5}' | cut -d: -f2 | sort -u | head -10
echo ""
echo "5. ПРОЕКТ:"
echo "----------------------------------------"
if [ -f "docker-compose.yml" ]; then
    echo "✅ docker-compose.yml найден в текущей директории"
    echo "Директория: $(pwd)"
    ls -la | head -10
elif [ -d "rabotaECO" ]; then
    echo "✅ Директория rabotaECO найдена"
    cd rabotaECO
    if [ -f "docker-compose.yml" ]; then
        echo "✅ docker-compose.yml найден"
    fi
elif find / -name "docker-compose.yml" -path "*/rabotaECO/*" 2>/dev/null | head -1; then
    PROJECT_PATH=$(find / -name "docker-compose.yml" -path "*/rabotaECO/*" 2>/dev/null | head -1 | xargs dirname)
    echo "✅ Проект найден: $PROJECT_PATH"
else
    echo "❌ Проект НЕ найден"
    echo "Поиск docker-compose.yml:"
    find / -name "docker-compose.yml" 2>/dev/null | head -5
fi
echo ""
echo "6. DOCKER (если установлен):"
echo "----------------------------------------"
if command -v docker &> /dev/null; then
    echo "Статус Docker:"
    systemctl is-active docker 2>/dev/null || service docker status 2>/dev/null | head -1 || echo "Не удалось проверить статус"
    echo ""
    echo "Запущенные контейнеры:"
    docker ps 2>/dev/null || echo "Docker не запущен или нет прав"
    echo ""
    echo "Все контейнеры:"
    docker ps -a 2>/dev/null | head -5
else
    echo "Docker не установлен"
fi
echo ""
echo "=========================================="
echo "ПРОВЕРКА ЗАВЕРШЕНА"
echo "=========================================="


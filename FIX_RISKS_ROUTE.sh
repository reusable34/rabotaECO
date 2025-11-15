#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ МАРШРУТА ДЛЯ RISKS"
echo "==========================================${NC}"

cd /opt/eco-project

# 1. Обновление кода
echo -e "${YELLOW}[1/4] Обновление кода...${NC}"
git pull
echo -e "${GREEN}✅ Код обновлен${NC}"

# 2. Создание файла логов
echo -e "${YELLOW}[2/4] Создание файла логов...${NC}"
mkdir -p backend/api/runtime/logs
touch backend/api/runtime/logs/app.log
chmod 666 backend/api/runtime/logs/app.log
chmod 755 backend/api/runtime/logs
chown -R www-data:www-data backend/api/runtime/logs
echo -e "${GREEN}✅ Файл логов создан${NC}"

# 3. Перезапуск PHP-FPM
echo -e "${YELLOW}[3/4] Перезапуск PHP-FPM...${NC}"
systemctl restart php8.2-fpm
echo -e "${GREEN}✅ PHP-FPM перезапущен${NC}"

# 4. Проверка
echo -e "${YELLOW}[4/4] Проверка...${NC}"
sleep 2
if [ -f backend/api/runtime/logs/app.log ]; then
    echo -e "${GREEN}✅ Файл логов существует${NC}"
    echo "Путь: $(pwd)/backend/api/runtime/logs/app.log"
else
    echo -e "${RED}❌ Файл логов не найден${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ВСЁ ГОТОВО!"
echo "==========================================${NC}"
echo ""
echo "Проверьте логи:"
echo "  tail -f /opt/eco-project/backend/api/runtime/logs/app.log | grep -i actionRisks"
echo ""
echo "Откройте страницу с требованиями в браузере и проверьте логи."


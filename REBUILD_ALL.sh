#!/bin/bash
# ==========================================
# ПОЛНАЯ ПЕРЕСБОРКА И ПРИМЕНЕНИЕ ИЗМЕНЕНИЙ
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ПОЛНАЯ ПЕРЕСБОРКА И ПРИМЕНЕНИЕ ИЗМЕНЕНИЙ"
echo "==========================================${NC}"
echo ""

# Определяем порты
NEXTJS_PORT=3002
BACKEND_PORT=8082
NGINX_PORT=3384

# Проверка, что мы в правильной директории
if [ ! -d "/opt/eco-project" ]; then
    echo -e "${RED}❌ Директория /opt/eco-project не найдена${NC}"
    exit 1
fi

cd /opt/eco-project

# 1. Обновление кода из git
echo -e "${YELLOW}[1/6] Обновление кода из git...${NC}"
git pull
echo -e "${GREEN}✅ Код обновлен${NC}"
echo ""

# 2. Остановка Next.js для пересборки
echo -e "${YELLOW}[2/6] Остановка Next.js...${NC}"
systemctl stop nextjs 2>/dev/null || true
sleep 2
echo -e "${GREEN}✅ Next.js остановлен${NC}"
echo ""

# 3. Пересборка фронтенда
echo -e "${YELLOW}[3/6] Пересборка фронтенда...${NC}"
cd /opt/eco-project/frontend

# Проверяем, установлены ли зависимости
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}⚠️  node_modules не найдены, устанавливаем зависимости...${NC}"
    npm install
fi

# Пересобираем
npm run build
echo -e "${GREEN}✅ Фронтенд пересобран${NC}"
echo ""

# 4. Перезапуск Next.js
echo -e "${YELLOW}[4/6] Перезапуск Next.js...${NC}"
systemctl start nextjs
sleep 5

if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен${NC}"
else
    echo -e "${RED}❌ Next.js не запустился${NC}"
    journalctl -u nextjs -n 30 --no-pager
    exit 1
fi
echo ""

# 5. Перезапуск PHP-FPM и проверка backend
echo -e "${YELLOW}[5/6] Перезапуск PHP-FPM...${NC}"
systemctl restart php8.2-fpm
sleep 2
echo -e "${GREEN}✅ PHP-FPM перезапущен${NC}"
echo ""

# Проверка backend
echo -e "${YELLOW}Проверка backend...${NC}"
if curl -s -f "http://127.0.0.1:${BACKEND_PORT}/health" > /dev/null; then
    echo -e "${GREEN}✅ Backend доступен${NC}"
else
    echo -e "${YELLOW}⚠️  Backend может быть недоступен, проверьте вручную${NC}"
fi
echo ""

# 6. Перезапуск Nginx
echo -e "${YELLOW}[6/6] Перезапуск Nginx...${NC}"
nginx -t && systemctl reload nginx
echo -e "${GREEN}✅ Nginx перезапущен${NC}"
echo ""

# Итоговая проверка
echo -e "${BLUE}=========================================="
echo "✅ ПЕРЕСБОРКА ЗАВЕРШЕНА"
echo "==========================================${NC}"
echo ""
echo -e "${GREEN}Проверка сервисов:${NC}"
echo ""

# Проверка Next.js
if systemctl is-active --quiet nextjs; then
    echo -e "  ${GREEN}✅ Next.js: запущен${NC}"
else
    echo -e "  ${RED}❌ Next.js: не запущен${NC}"
fi

# Проверка PHP-FPM
if systemctl is-active --quiet php8.2-fpm; then
    echo -e "  ${GREEN}✅ PHP-FPM: запущен${NC}"
else
    echo -e "  ${RED}❌ PHP-FPM: не запущен${NC}"
fi

# Проверка Nginx
if systemctl is-active --quiet nginx; then
    echo -e "  ${GREEN}✅ Nginx: запущен${NC}"
else
    echo -e "  ${RED}❌ Nginx: не запущен${NC}"
fi

# Проверка доступности
echo ""
echo -e "${YELLOW}Проверка доступности:${NC}"
sleep 2

if curl -s -f "http://127.0.0.1:${NEXTJS_PORT}" > /dev/null; then
    echo -e "  ${GREEN}✅ Frontend доступен на порту ${NEXTJS_PORT}${NC}"
else
    echo -e "  ${YELLOW}⚠️  Frontend может еще запускаться${NC}"
fi

if curl -s -f "http://127.0.0.1:${BACKEND_PORT}/health" > /dev/null; then
    echo -e "  ${GREEN}✅ Backend доступен на порту ${BACKEND_PORT}${NC}"
else
    echo -e "  ${YELLOW}⚠️  Backend недоступен${NC}"
fi

echo ""
echo -e "${BLUE}=========================================="
echo "📝 СЛЕДУЮЩИЕ ШАГИ"
echo "==========================================${NC}"
echo ""
echo "Для пересчета требований для всех клиентов выполните:"
echo -e "  ${YELLOW}cd /opt/eco-project/backend && php yii recalculate-all/all${NC}"
echo ""
echo "Или для конкретного клиента:"
echo -e "  ${YELLOW}cd /opt/eco-project/backend && php yii recalculate-all/client <ID>${NC}"
echo ""
echo -e "${GREEN}Готово!${NC}"


#!/bin/bash
# ==========================================
# ПРОСТОЙ ЗАПУСК NEXT.JS
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🚀 ПРОСТОЙ ЗАПУСК NEXT.JS"
echo "==========================================${NC}"
echo ""

cd /opt/eco-project/frontend

# 1. Остановка старых процессов
echo -e "${YELLOW}[1/3] Остановка старых процессов...${NC}"
pkill -f "next start" 2>/dev/null || true
lsof -ti:3001 | xargs kill -9 2>/dev/null || true
sleep 2
echo -e "${GREEN}✅ Процессы остановлены${NC}"
echo ""

# 2. Обновление package.json для порта 3001
echo -e "${YELLOW}[2/3] Обновление package.json...${NC}"
if ! grep -q '"start": "next start -p 3001"' package.json 2>/dev/null; then
    # Создаем backup
    cp package.json package.json.backup
    
    # Обновляем start скрипт
    if grep -q '"start":' package.json; then
        sed -i 's/"start": "next start"/"start": "next start -p 3001"/g' package.json
    else
        # Добавляем в scripts если нет
        sed -i '/"scripts": {/a\    "start": "next start -p 3001",' package.json
    fi
    echo -e "${GREEN}✅ package.json обновлен${NC}"
else
    echo -e "${GREEN}✅ package.json уже настроен${NC}"
fi
echo ""

# 3. Запуск Next.js в фоне
echo -e "${YELLOW}[3/3] Запуск Next.js на порту 3001...${NC}"
export NODE_ENV=production
export PORT=3001
export NEXT_PUBLIC_API_URL=http://localhost:8080

nohup npm start > /var/log/nextjs.log 2>&1 &
NEXTJS_PID=$!

sleep 5

# Проверка
if ps -p $NEXTJS_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Next.js запущен (PID: $NEXTJS_PID)${NC}"
    echo ""
    echo "Проверьте:"
    echo "  curl http://127.0.0.1:3001"
    echo "  ps aux | grep 'next start' | grep -v grep"
    echo ""
    echo "Логи:"
    echo "  tail -f /var/log/nextjs.log"
    echo ""
    echo "Остановить:"
    echo "  kill $NEXTJS_PID"
else
    echo -e "${RED}❌ Next.js не запустился${NC}"
    echo "Логи:"
    tail -20 /var/log/nextjs.log
    exit 1
fi


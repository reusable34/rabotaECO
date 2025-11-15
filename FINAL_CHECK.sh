#!/bin/bash
# ==========================================
# ФИНАЛЬНАЯ ПРОВЕРКА ВСЕГО
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔍 ФИНАЛЬНАЯ ПРОВЕРКА"
echo "==========================================${NC}"
echo ""

# 1. Проверка Backend локально
echo -e "${YELLOW}[1/4] Проверка Backend (локально)...${NC}"
BACKEND_RESPONSE=$(curl -s http://127.0.0.1:8080/health 2>/dev/null || echo "ERROR")
if echo "$BACKEND_RESPONSE" | grep -q "connected"; then
    echo -e "${GREEN}✅ Backend работает локально${NC}"
    echo "Ответ: $BACKEND_RESPONSE"
else
    echo -e "${RED}❌ Backend не работает локально${NC}"
    echo "Ответ: $BACKEND_RESPONSE"
fi
echo ""

# 2. Проверка Frontend локально
echo -e "${YELLOW}[2/4] Проверка Frontend (локально)...${NC}"
FRONTEND_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3384 2>/dev/null || echo "000")
if [ "$FRONTEND_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Frontend работает локально (HTTP $FRONTEND_CODE)${NC}"
else
    echo -e "${RED}❌ Frontend не работает локально (HTTP $FRONTEND_CODE)${NC}"
fi
echo ""

# 3. Проверка API URL в frontend
echo -e "${YELLOW}[3/4] Проверка API URL в frontend...${NC}"
if [ -f "/opt/eco-project/frontend/.env.local" ]; then
    echo "Содержимое .env.local:"
    cat /opt/eco-project/frontend/.env.local
    API_URL=$(grep NEXT_PUBLIC_API_URL /opt/eco-project/frontend/.env.local | cut -d'=' -f2)
    echo ""
    echo -e "${GREEN}✅ API URL настроен: $API_URL${NC}"
else
    echo -e "${RED}❌ .env.local не найден!${NC}"
fi
echo ""

# 4. Итоговая информация
echo -e "${YELLOW}[4/4] Итоговая информация...${NC}"
echo ""
echo -e "${BLUE}ПОРТЫ ДЛЯ ПРОБРОСА В РОУТЕРЕ:${NC}"
echo "  Backend:  8080 → 192.168.0.32:8080"
echo "  Frontend: 3384 → 192.168.0.32:3384 (уже проброшен)"
echo ""
echo -e "${BLUE}ПРОВЕРКА ИЗ ИНТЕРНЕТА (после проброса порта 8080):${NC}"
echo "  Backend:  http://85.113.129.96:8080/health"
echo "  Frontend: http://85.113.129.96:3384"
echo ""
echo -e "${GREEN}=========================================="
echo "✅ ПРОВЕРКА ЗАВЕРШЕНА"
echo "==========================================${NC}"
echo ""
echo -e "${YELLOW}ЧТО НУЖНО СДЕЛАТЬ:${NC}"
echo "1. Пробросить порт 8080 в роутере:"
echo "   - Порт сервиса: 8080"
echo "   - Внутренний порт: 8080"
echo "   - IP-Адрес: 192.168.0.32"
echo "   - Протокол: TCP"
echo ""
echo "2. После проброса проверьте:"
echo "   curl http://85.113.129.96:8080/health"
echo ""
echo "3. Если backend доступен из интернета, вход на сайте заработает!"
echo ""


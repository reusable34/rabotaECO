#!/bin/bash
# ==========================================
# ПРОВЕРКА И ИСПРАВЛЕНИЕ 502
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ПРОВЕРКА И ИСПРАВЛЕНИЕ 502"
echo "==========================================${NC}"
echo ""

# 1. Проверка активных портов
echo -e "${YELLOW}[1/6] Проверка активных портов...${NC}"
echo "Слушающие порты:"
ss -tuln | grep LISTEN | grep -E ":(300[0-9]|808[0-9]|3384)" || echo "  Нет нужных портов"
echo ""

# 2. Проверка Next.js
echo -e "${YELLOW}[2/6] Проверка Next.js...${NC}"
NEXTJS_PORT=$(ss -tuln | grep LISTEN | grep -oE ":300[0-9]+" | head -1 | cut -d: -f2 || echo "")
if [ -z "$NEXTJS_PORT" ]; then
    echo -e "${RED}❌ Next.js не запущен${NC}"
    echo "Проверяю статус сервиса..."
    systemctl status nextjs --no-pager -l | head -15
    echo ""
    echo "Попытка запуска..."
    systemctl start nextjs
    sleep 5
    NEXTJS_PORT=$(ss -tuln | grep LISTEN | grep -oE ":300[0-9]+" | head -1 | cut -d: -f2 || echo "")
    if [ -z "$NEXTJS_PORT" ]; then
        echo -e "${RED}❌ Next.js не запустился${NC}"
        echo "Логи:"
        journalctl -u nextjs -n 30 --no-pager
    else
        echo -e "${GREEN}✅ Next.js запущен на порту $NEXTJS_PORT${NC}"
    fi
else
    echo -e "${GREEN}✅ Next.js слушает на порту $NEXTJS_PORT${NC}"
    if curl -s http://127.0.0.1:$NEXTJS_PORT > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Next.js отвечает${NC}"
    else
        echo -e "${RED}❌ Next.js не отвечает${NC}"
    fi
fi
echo ""

# 3. Проверка backend
echo -e "${YELLOW}[3/6] Проверка backend...${NC}"
BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "")
if [ -z "$BACKEND_PORT" ]; then
    echo -e "${RED}❌ Backend не запущен${NC}"
    echo "Проверяю PHP-FPM..."
    systemctl status php8.2-fpm --no-pager -l | head -10
    echo ""
    echo "Попытка запуска PHP-FPM..."
    systemctl start php8.2-fpm
    sleep 2
    BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "")
    if [ -z "$BACKEND_PORT" ]; then
        echo -e "${YELLOW}⚠️ Backend может быть на другом порту${NC}"
    else
        echo -e "${GREEN}✅ Backend слушает на порту $BACKEND_PORT${NC}"
    fi
else
    echo -e "${GREEN}✅ Backend слушает на порту $BACKEND_PORT${NC}"
    if curl -s http://127.0.0.1:$BACKEND_PORT/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Backend отвечает${NC}"
    else
        echo -e "${RED}❌ Backend не отвечает${NC}"
    fi
fi
echo ""

# 4. Проверка Nginx конфигурации
echo -e "${YELLOW}[4/6] Проверка Nginx конфигурации...${NC}"
if [ -f /etc/nginx/sites-available/eco-api-proxy.conf ]; then
    echo "Текущая конфигурация:"
    echo "Next.js порт в конфиге:"
    grep -oE "proxy_pass.*300[0-9]+" /etc/nginx/sites-available/eco-api-proxy.conf || echo "  Не найден"
    echo "Backend порт в конфиге:"
    grep -oE "proxy_pass.*808[0-9]+" /etc/nginx/sites-available/eco-api-proxy.conf || echo "  Не найден"
    
    # Обновляем конфигурацию если порты не совпадают
    if [ -n "$NEXTJS_PORT" ]; then
        CURRENT_NEXTJS=$(grep -oE "proxy_pass.*300[0-9]+" /etc/nginx/sites-available/eco-api-proxy.conf | grep -oE "300[0-9]+" || echo "")
        if [ -n "$CURRENT_NEXTJS" ] && [ "$CURRENT_NEXTJS" != "$NEXTJS_PORT" ]; then
            echo -e "${YELLOW}⚠️ Обновляю порт Next.js в конфигурации: $CURRENT_NEXTJS → $NEXTJS_PORT${NC}"
            sed -i "s/proxy_pass http:\/\/127.0.0.1:$CURRENT_NEXTJS/proxy_pass http:\/\/127.0.0.1:$NEXTJS_PORT/" /etc/nginx/sites-available/eco-api-proxy.conf
        fi
    fi
    
    if [ -n "$BACKEND_PORT" ]; then
        CURRENT_BACKEND=$(grep -oE "proxy_pass.*808[0-9]+" /etc/nginx/sites-available/eco-api-proxy.conf | grep -oE "808[0-9]+" || echo "")
        if [ -n "$CURRENT_BACKEND" ] && [ "$CURRENT_BACKEND" != "$BACKEND_PORT" ]; then
            echo -e "${YELLOW}⚠️ Обновляю порт backend в конфигурации: $CURRENT_BACKEND → $BACKEND_PORT${NC}"
            sed -i "s/proxy_pass http:\/\/127.0.0.1:$CURRENT_BACKEND/proxy_pass http:\/\/127.0.0.1:$BACKEND_PORT/" /etc/nginx/sites-available/eco-api-proxy.conf
        fi
    fi
else
    echo -e "${RED}❌ Конфигурация не найдена${NC}"
    exit 1
fi
echo ""

# 5. Проверка синтаксиса и перезапуск Nginx
echo -e "${YELLOW}[5/6] Проверка синтаксиса Nginx...${NC}"
if nginx -t; then
    echo -e "${GREEN}✅ Синтаксис корректен${NC}"
    echo "Перезапуск Nginx..."
    systemctl reload nginx || systemctl restart nginx
    sleep 2
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✅ Nginx перезапущен${NC}"
    else
        echo -e "${RED}❌ Nginx не запустился${NC}"
        systemctl status nginx --no-pager -l | head -20
        exit 1
    fi
else
    echo -e "${RED}❌ Ошибка в синтаксисе${NC}"
    nginx -t
    exit 1
fi
echo ""

# 6. Тестирование
echo -e "${YELLOW}[6/6] Тестирование...${NC}"
echo "1. Frontend напрямую:"
if [ -n "$NEXTJS_PORT" ]; then
    if curl -s http://127.0.0.1:$NEXTJS_PORT | head -3 | grep -q "html\|Личный кабинет"; then
        echo -e "${GREEN}✅ Frontend работает${NC}"
    else
        echo -e "${RED}❌ Frontend не отвечает${NC}"
    fi
else
    echo -e "${RED}❌ Frontend не запущен${NC}"
fi
echo ""

echo "2. Frontend через Nginx:"
if curl -s http://127.0.0.1:3384 | head -3 | grep -q "html\|Личный кабинет"; then
    echo -e "${GREEN}✅ Frontend через Nginx работает${NC}"
else
    echo -e "${RED}❌ Frontend через Nginx не работает${NC}"
    echo "Ответ:"
    curl -s http://127.0.0.1:3384 | head -5
fi
echo ""

echo "3. Backend API через Nginx:"
API_RESPONSE=$(curl -s http://127.0.0.1:3384/api/health)
if echo "$API_RESPONSE" | grep -q "status\|ok"; then
    echo -e "${GREEN}✅ Backend API работает${NC}"
    echo "$API_RESPONSE" | head -3
else
    echo -e "${RED}❌ Backend API не работает${NC}"
    echo "Ответ: $API_RESPONSE"
fi
echo ""

echo -e "${GREEN}=========================================="
echo "✅ ПРОВЕРКА ЗАВЕРШЕНА"
echo "==========================================${NC}"
echo ""
echo "Используемые порты:"
[ -n "$NEXTJS_PORT" ] && echo "  - Next.js: $NEXTJS_PORT" || echo "  - Next.js: ❌ Не запущен"
[ -n "$BACKEND_PORT" ] && echo "  - Backend: $BACKEND_PORT" || echo "  - Backend: ❌ Не запущен"
echo "  - Nginx: 3384"
echo ""
echo "Проверьте доступность:"
echo "  http://85.113.129.96:3384/login"
echo ""


#!/bin/bash
# ==========================================
# ДИАГНОСТИКА CORS ПРОБЛЕМЫ
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔍 ДИАГНОСТИКА CORS ПРОБЛЕМЫ"
echo "==========================================${NC}"
echo ""

# 1. Проверка бекенда
echo -e "${YELLOW}[1/6] Проверка бекенда...${NC}"
BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "")
if [ -z "$BACKEND_PORT" ]; then
    echo -e "${RED}❌ Backend не запущен${NC}"
    echo "Проверяю PHP-FPM..."
    systemctl status php8.2-fpm --no-pager -l | head -10
else
    echo "Backend на порту: $BACKEND_PORT"
    echo ""
    echo "Тест /health:"
    HEALTH_RESPONSE=$(curl -s http://127.0.0.1:$BACKEND_PORT/health 2>&1)
    if echo "$HEALTH_RESPONSE" | grep -q "status\|ok"; then
        echo -e "${GREEN}   ✅ Backend отвечает${NC}"
        echo "$HEALTH_RESPONSE" | head -3
    else
        echo -e "${RED}   ❌ Backend не отвечает или путь неправильный${NC}"
        echo "   Ответ: $HEALTH_RESPONSE"
    fi
fi
echo ""

# 2. Проверка CORS заголовков
echo -e "${YELLOW}[2/6] Проверка CORS заголовков...${NC}"
if [ -n "$BACKEND_PORT" ]; then
    echo "Тест с Origin: http://85.113.129.96:3384"
    CORS_HEADERS=$(curl -s -I -H "Origin: http://85.113.129.96:3384" http://127.0.0.1:$BACKEND_PORT/health 2>&1)
    
    if echo "$CORS_HEADERS" | grep -qi "access-control-allow-origin"; then
        echo -e "${GREEN}   ✅ CORS заголовки установлены${NC}"
        echo "$CORS_HEADERS" | grep -i "access-control" | sed 's/^/      /'
    else
        echo -e "${RED}   ❌ CORS заголовки НЕ установлены${NC}"
        echo "   Полный ответ:"
        echo "$CORS_HEADERS" | head -15 | sed 's/^/      /'
    fi
    
    echo ""
    echo "Тест с Origin: http://localhost:3002"
    CORS_HEADERS2=$(curl -s -I -H "Origin: http://localhost:3002" http://127.0.0.1:$BACKEND_PORT/health 2>&1)
    if echo "$CORS_HEADERS2" | grep -qi "access-control-allow-origin"; then
        echo -e "${GREEN}   ✅ CORS заголовки установлены для localhost:3002${NC}"
        echo "$CORS_HEADERS2" | grep -i "access-control" | sed 's/^/      /'
    else
        echo -e "${RED}   ❌ CORS заголовки НЕ установлены для localhost:3002${NC}"
    fi
else
    echo -e "${RED}   ❌ Backend не запущен, проверка невозможна${NC}"
fi
echo ""

# 3. Проверка CorsFilter.php
echo -e "${YELLOW}[3/6] Проверка CorsFilter.php...${NC}"
if [ -f /opt/eco-project/backend/api/components/CorsFilter.php ]; then
    echo -e "${GREEN}   ✅ Файл существует${NC}"
    echo ""
    echo "Содержимое (первые 50 строк):"
    head -50 /opt/eco-project/backend/api/components/CorsFilter.php | sed 's/^/      /'
    echo ""
    echo "Проверка разрешенных origins:"
    if grep -q "85.113.129.96" /opt/eco-project/backend/api/components/CorsFilter.php; then
        echo -e "${GREEN}   ✅ Содержит 85.113.129.96${NC}"
    else
        echo -e "${RED}   ❌ НЕ содержит 85.113.129.96${NC}"
    fi
    if grep -q "localhost:3002" /opt/eco-project/backend/api/components/CorsFilter.php; then
        echo -e "${GREEN}   ✅ Содержит localhost:3002${NC}"
    else
        echo -e "${YELLOW}   ⚠️ НЕ содержит localhost:3002${NC}"
    fi
else
    echo -e "${RED}   ❌ Файл не найден!${NC}"
fi
echo ""

# 4. Проверка конфигурации Yii2
echo -e "${YELLOW}[4/6] Проверка конфигурации Yii2...${NC}"
if [ -f /opt/eco-project/backend/api/config/main.php ]; then
    echo -e "${GREEN}   ✅ main.php существует${NC}"
    if grep -q "CorsFilter\|cors" /opt/eco-project/backend/api/config/main.php; then
        echo -e "${GREEN}   ✅ CORS фильтр подключен${NC}"
        echo "   Конфигурация:"
        grep -A 3 -B 3 "CorsFilter\|cors" /opt/eco-project/backend/api/config/main.php | sed 's/^/      /'
    else
        echo -e "${RED}   ❌ CORS фильтр НЕ подключен в main.php${NC}"
    fi
else
    echo -e "${RED}   ❌ main.php не найден${NC}"
fi
echo ""

# 5. Проверка логов бекенда
echo -e "${YELLOW}[5/6] Проверка логов бекенда...${NC}"
LOG_FILE="/opt/eco-project/backend/runtime/logs/app.log"
if [ -f "$LOG_FILE" ]; then
    echo -e "${GREEN}   ✅ Лог файл существует${NC}"
    echo "   Последние 20 строк с CORS:"
    grep -i "cors\|origin" "$LOG_FILE" | tail -20 | sed 's/^/      /' || echo "      Нет записей о CORS"
else
    echo -e "${YELLOW}   ⚠️ Лог файл не найден (может быть нормально)${NC}"
fi
echo ""

# 6. Тест через Nginx
echo -e "${YELLOW}[6/6] Тест через Nginx...${NC}"
echo "Тест /api/health через Nginx:"
NGINX_RESPONSE=$(curl -s -H "Origin: http://85.113.129.96:3384" http://127.0.0.1:3384/api/health 2>&1)
if echo "$NGINX_RESPONSE" | grep -q "status\|ok"; then
    echo -e "${GREEN}   ✅ API работает через Nginx${NC}"
    echo "$NGINX_RESPONSE" | head -3 | sed 's/^/      /'
else
    echo -e "${RED}   ❌ API не работает через Nginx${NC}"
    echo "   Ответ: $NGINX_RESPONSE" | head -5 | sed 's/^/      /'
fi

echo ""
echo "Проверка CORS заголовков через Nginx:"
NGINX_CORS=$(curl -s -I -H "Origin: http://85.113.129.96:3384" http://127.0.0.1:3384/api/health 2>&1)
if echo "$NGINX_CORS" | grep -qi "access-control-allow-origin"; then
    echo -e "${GREEN}   ✅ CORS заголовки установлены${NC}"
    echo "$NGINX_CORS" | grep -i "access-control" | sed 's/^/      /'
else
    echo -e "${RED}   ❌ CORS заголовки НЕ установлены${NC}"
    echo "   Полный ответ:"
    echo "$NGINX_CORS" | head -15 | sed 's/^/      /'
fi
echo ""

echo -e "${GREEN}=========================================="
echo "✅ ДИАГНОСТИКА ЗАВЕРШЕНА"
echo "==========================================${NC}"
echo ""
echo "Следующие шаги:"
echo "  1. Если CORS заголовки не установлены - проверьте CorsFilter.php"
echo "  2. Если CorsFilter не подключен - добавьте в main.php"
echo "  3. Если backend не отвечает - проверьте PHP-FPM и Nginx"
echo ""


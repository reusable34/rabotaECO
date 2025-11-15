#!/bin/bash
# ==========================================
# ДИАГНОСТИКА ОШИБКИ 500
# ==========================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔍 ДИАГНОСТИКА ОШИБКИ 500${NC}"
echo ""

cd /opt/eco-project || exit 1

# 1. Проверка логов PHP
echo -e "${YELLOW}[1/5] Проверка логов PHP...${NC}"
PHP_LOG=$(find /var/log -name "*php*error*" -o -name "*php*fpm*" 2>/dev/null | head -1)
if [ -n "$PHP_LOG" ] && [ -f "$PHP_LOG" ]; then
    echo "Последние ошибки PHP:"
    tail -20 "$PHP_LOG" | grep -i error || echo "Ошибок не найдено"
else
    echo "Лог файл PHP не найден"
fi
echo ""

# 2. Проверка логов Yii2
echo -e "${YELLOW}[2/5] Проверка логов Yii2...${NC}"
YII_LOG=$(find backend/runtime/logs -name "*.log" 2>/dev/null | head -1)
if [ -n "$YII_LOG" ] && [ -f "$YII_LOG" ]; then
    echo "Последние ошибки Yii2:"
    tail -30 "$YII_LOG" | grep -A 5 -i "error\|exception" || echo "Ошибок не найдено"
else
    echo "Лог файл Yii2 не найден"
    echo "Ищем в: backend/runtime/logs/"
    ls -la backend/runtime/logs/ 2>/dev/null || echo "Директория не существует"
fi
echo ""

# 3. Тест API напрямую
echo -e "${YELLOW}[3/5] Тест API напрямую...${NC}"
BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "8082")
echo "Тестируем POST /auth/login на порту $BACKEND_PORT:"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "Origin: http://85.113.129.96:3384" \
    -d '{"email":"client@demo.local","password":"client123"}' \
    "http://127.0.0.1:$BACKEND_PORT/auth/login" 2>&1)

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE")

echo "HTTP код: $HTTP_CODE"
echo "Ответ:"
echo "$BODY" | head -20
echo ""

# 4. Проверка через Nginx
echo -e "${YELLOW}[4/5] Тест через Nginx...${NC}"
echo "Тестируем POST /api/auth/login через Nginx:"
NGINX_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "Origin: http://85.113.129.96:3384" \
    -d '{"email":"client@demo.local","password":"client123"}' \
    "http://127.0.0.1:3384/api/auth/login" 2>&1)

NGINX_HTTP_CODE=$(echo "$NGINX_RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
NGINX_BODY=$(echo "$NGINX_RESPONSE" | grep -v "HTTP_CODE")

echo "HTTP код: $NGINX_HTTP_CODE"
echo "Ответ:"
echo "$NGINX_BODY" | head -20
echo ""

# 5. Проверка конфигурации
echo -e "${YELLOW}[5/5] Проверка конфигурации...${NC}"
echo "Проверяем CorsFilter:"
if [ -f "backend/api/components/CorsFilter.php" ]; then
    echo "✅ CorsFilter.php существует"
    grep -q "try {" backend/api/components/CorsFilter.php && echo "✅ Есть обработка ошибок" || echo "❌ Нет обработки ошибок"
else
    echo "❌ CorsFilter.php не найден"
fi

echo ""
echo "Проверяем AuthController:"
if [ -f "backend/api/controllers/AuthController.php" ]; then
    echo "✅ AuthController.php существует"
    if grep -q "yii\\filters\\Cors" backend/api/controllers/AuthController.php; then
        echo "⚠️  В AuthController есть CORS фильтр (может конфликтовать)"
    else
        echo "✅ Нет дублирующего CORS фильтра"
    fi
else
    echo "❌ AuthController.php не найден"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo "Диагностика завершена"
echo ""
echo "Если видите ошибку 500, проверьте:"
echo "  1. Логи PHP: tail -f $PHP_LOG"
echo "  2. Логи Yii2: tail -f $YII_LOG"
echo "  3. Логи Nginx: journalctl -u nginx -f"
echo ""


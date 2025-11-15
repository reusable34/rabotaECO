#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ ОШИБКИ 502 BAD GATEWAY
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ДИАГНОСТИКА И ИСПРАВЛЕНИЕ 502"
echo "==========================================${NC}"
echo ""

# 1. Проверка активных портов
echo -e "${YELLOW}[1/7] Проверка активных портов...${NC}"
echo "Все слушающие порты:"
ss -tuln | grep LISTEN | grep -E ":(300[0-9]|808[0-9]|3384)" || echo "  Нет нужных портов"
echo ""

# 2. Проверка Next.js
echo -e "${YELLOW}[2/7] Проверка Next.js...${NC}"
NEXTJS_PORT=$(ss -tuln | grep LISTEN | grep -oE ":300[0-9]+" | head -1 | cut -d: -f2 || echo "")
if [ -z "$NEXTJS_PORT" ]; then
    echo -e "${RED}❌ Next.js не слушает ни на одном порту 300x${NC}"
    echo "Проверяю статус сервиса..."
    systemctl status nextjs --no-pager -l | head -15
    echo ""
    echo "Попытка запуска Next.js..."
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
echo -e "${YELLOW}[3/7] Проверка backend...${NC}"
BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "")
if [ -z "$BACKEND_PORT" ]; then
    echo -e "${RED}❌ Backend не слушает ни на одном порту 808x${NC}"
    echo "Проверяю PHP-FPM и Nginx..."
    systemctl status php8.2-fpm --no-pager -l | head -10
    systemctl status nginx --no-pager -l | head -10
    echo ""
    echo "Попытка запуска PHP-FPM..."
    systemctl start php8.2-fpm
    sleep 2
    BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "")
    if [ -z "$BACKEND_PORT" ]; then
        echo -e "${YELLOW}⚠️ Backend может быть на другом порту или не настроен${NC}"
        echo "Проверяю конфигурацию Nginx для backend..."
        ls -la /etc/nginx/sites-enabled/ | grep -E "(backend|eco)" || echo "  Нет конфигурации"
    else
        echo -e "${GREEN}✅ Backend слушает на порту $BACKEND_PORT${NC}"
    fi
else
    echo -e "${GREEN}✅ Backend слушает на порту $BACKEND_PORT${NC}"
    if curl -s http://127.0.0.1:$BACKEND_PORT/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Backend отвечает${NC}"
        curl -s http://127.0.0.1:$BACKEND_PORT/health | head -3
    else
        echo -e "${RED}❌ Backend не отвечает на /health${NC}"
        echo "Проверяю корневой путь..."
        curl -s http://127.0.0.1:$BACKEND_PORT | head -5 || echo "  Не отвечает"
    fi
fi
echo ""

# 4. Проверка Nginx конфигурации
echo -e "${YELLOW}[4/7] Проверка Nginx конфигурации...${NC}"
if [ -f /etc/nginx/sites-available/eco-api-proxy.conf ]; then
    echo "Конфигурация eco-api-proxy.conf:"
    cat /etc/nginx/sites-available/eco-api-proxy.conf | grep -A 5 "proxy_pass"
    
    # Проверяем, правильные ли порты в конфигурации
    CONFIG_NEXTJS=$(grep -oE "proxy_pass.*300[0-9]+" /etc/nginx/sites-available/eco-api-proxy.conf | grep -oE "300[0-9]+" || echo "")
    CONFIG_BACKEND=$(grep -oE "proxy_pass.*808[0-9]+" /etc/nginx/sites-available/eco-api-proxy.conf | grep -oE "808[0-9]+" || echo "")
    
    if [ -n "$NEXTJS_PORT" ] && [ -n "$CONFIG_NEXTJS" ] && [ "$NEXTJS_PORT" != "$CONFIG_NEXTJS" ]; then
        echo -e "${YELLOW}⚠️ Порт Next.js в конфигурации ($CONFIG_NEXTJS) не совпадает с реальным ($NEXTJS_PORT)${NC}"
        echo "Обновляю конфигурацию..."
        sed -i "s/proxy_pass http:\/\/127.0.0.1:$CONFIG_NEXTJS/proxy_pass http:\/\/127.0.0.1:$NEXTJS_PORT/" /etc/nginx/sites-available/eco-api-proxy.conf
        echo -e "${GREEN}✅ Конфигурация обновлена${NC}"
    fi
    
    if [ -n "$BACKEND_PORT" ] && [ -n "$CONFIG_BACKEND" ] && [ "$BACKEND_PORT" != "$CONFIG_BACKEND" ]; then
        echo -e "${YELLOW}⚠️ Порт backend в конфигурации ($CONFIG_BACKEND) не совпадает с реальным ($BACKEND_PORT)${NC}"
        echo "Обновляю конфигурацию..."
        sed -i "s/proxy_pass http:\/\/127.0.0.1:$CONFIG_BACKEND/proxy_pass http:\/\/127.0.0.1:$BACKEND_PORT/" /etc/nginx/sites-available/eco-api-proxy.conf
        echo -e "${GREEN}✅ Конфигурация обновлена${NC}"
    fi
else
    echo -e "${RED}❌ Конфигурация eco-api-proxy.conf не найдена${NC}"
    echo "Создаю конфигурацию..."
    
    # Используем найденные порты или дефолтные
    NEXTJS_PORT=${NEXTJS_PORT:-3001}
    BACKEND_PORT=${BACKEND_PORT:-8080}
    
    cat > /etc/nginx/sites-available/eco-api-proxy.conf << EOF
server {
    listen 3384;
    server_name _;

    # Frontend (Next.js)
    location / {
        proxy_pass http://127.0.0.1:$NEXTJS_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Backend API
    location /api {
        proxy_pass http://127.0.0.1:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/eco-api-proxy.conf /etc/nginx/sites-enabled/eco-api-proxy.conf
    echo -e "${GREEN}✅ Конфигурация создана${NC}"
fi
echo ""

# 5. Проверка синтаксиса Nginx
echo -e "${YELLOW}[5/7] Проверка синтаксиса Nginx...${NC}"
if nginx -t; then
    echo -e "${GREEN}✅ Синтаксис корректен${NC}"
else
    echo -e "${RED}❌ Ошибка в синтаксисе${NC}"
    nginx -t
    exit 1
fi
echo ""

# 6. Перезапуск Nginx
echo -e "${YELLOW}[6/7] Перезапуск Nginx...${NC}"
systemctl reload nginx || systemctl restart nginx
sleep 2

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Nginx запущен${NC}"
else
    echo -e "${RED}❌ Nginx не запустился${NC}"
    systemctl status nginx --no-pager -l | head -20
    exit 1
fi
echo ""

# 7. Тестирование
echo -e "${YELLOW}[7/7] Тестирование...${NC}"
echo "1. Frontend через Nginx:"
if curl -s http://127.0.0.1:3384 | head -5 | grep -q "html\|Личный кабинет"; then
    echo -e "${GREEN}✅ Frontend работает${NC}"
else
    echo -e "${RED}❌ Frontend не отвечает${NC}"
    curl -s http://127.0.0.1:3384 | head -5
fi
echo ""

echo "2. Backend API через Nginx:"
if curl -s http://127.0.0.1:3384/api/health | grep -q "status\|ok"; then
    echo -e "${GREEN}✅ Backend API работает${NC}"
    curl -s http://127.0.0.1:3384/api/health | head -3
else
    echo -e "${RED}❌ Backend API не отвечает${NC}"
    echo "Ответ:"
    curl -s http://127.0.0.1:3384/api/health | head -5
    echo ""
    echo "Проверяю напрямую backend:"
    if [ -n "$BACKEND_PORT" ]; then
        curl -s http://127.0.0.1:$BACKEND_PORT/health | head -3 || echo "  Не отвечает"
    fi
fi
echo ""

echo -e "${GREEN}=========================================="
echo "✅ ДИАГНОСТИКА ЗАВЕРШЕНА"
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


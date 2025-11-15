#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ ОШИБКИ 404
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ДИАГНОСТИКА И ИСПРАВЛЕНИЕ 404"
echo "==========================================${NC}"
echo ""

# 1. Проверка backend
echo -e "${YELLOW}[1/6] Проверка backend...${NC}"
if curl -s http://127.0.0.1:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend работает на localhost:8080${NC}"
    curl -s http://127.0.0.1:8080/health | head -5
else
    echo -e "${RED}❌ Backend НЕ отвечает на localhost:8080${NC}"
    echo "Проверяю статус PHP-FPM и Nginx..."
    systemctl status php8.2-fpm --no-pager -l | head -10
    systemctl status nginx --no-pager -l | head -10
fi
echo ""

# 2. Проверка Next.js
echo -e "${YELLOW}[2/6] Проверка Next.js...${NC}"
if curl -s http://127.0.0.1:3001 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Next.js работает на localhost:3001${NC}"
else
    echo -e "${RED}❌ Next.js НЕ отвечает на localhost:3001${NC}"
    systemctl status nextjs --no-pager -l | head -10
fi
echo ""

# 3. Проверка Nginx конфигурации
echo -e "${YELLOW}[3/6] Проверка Nginx конфигурации...${NC}"
if [ -f /etc/nginx/sites-available/eco-api-proxy.conf ]; then
    echo -e "${GREEN}✅ Конфигурация eco-api-proxy.conf найдена${NC}"
    echo "Содержимое:"
    cat /etc/nginx/sites-available/eco-api-proxy.conf | grep -A 10 "location /api"
else
    echo -e "${YELLOW}⚠️ Конфигурация eco-api-proxy.conf не найдена${NC}"
    echo "Создаю конфигурацию..."
    
    cat > /etc/nginx/sites-available/eco-api-proxy.conf << 'EOF'
server {
    listen 3384;
    server_name _;

    # Frontend (Next.js)
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Backend API
    location /api {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/eco-api-proxy.conf /etc/nginx/sites-enabled/eco-api-proxy.conf
    echo -e "${GREEN}✅ Конфигурация создана${NC}"
fi
echo ""

# 4. Проверка активных портов
echo -e "${YELLOW}[4/6] Проверка активных портов...${NC}"
echo "Порт 8080 (backend):"
ss -tulpn | grep :8080 || echo "  ❌ Не слушает"
echo "Порт 3001 (frontend):"
ss -tulpn | grep :3001 || echo "  ❌ Не слушает"
echo "Порт 3384 (nginx):"
ss -tulpn | grep :3384 || echo "  ❌ Не слушает"
echo ""

# 5. Тест проксирования
echo -e "${YELLOW}[5/6] Тест проксирования через Nginx...${NC}"
if curl -s http://127.0.0.1:3384/api/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Nginx проксирует /api на backend${NC}"
    curl -s http://127.0.0.1:3384/api/health
else
    echo -e "${RED}❌ Nginx НЕ проксирует /api${NC}"
    echo "Проверяю конфигурацию..."
    nginx -t
fi
echo ""

# 6. Настройка frontend .env.local
echo -e "${YELLOW}[6/6] Настройка frontend...${NC}"
cd /opt/eco-project/frontend

# Проверяем текущий .env.local
if [ -f .env.local ]; then
    echo "Текущий .env.local:"
    cat .env.local
    echo ""
fi

# Создаем правильный .env.local
cat > .env.local << 'EOF'
NEXT_PUBLIC_API_URL=/api
NEXT_PUBLIC_ENV=production
EOF

echo -e "${GREEN}✅ .env.local обновлен${NC}"
echo ""

# 7. Перезапуск сервисов
echo -e "${YELLOW}[7/7] Перезапуск сервисов...${NC}"

# Перезапуск Nginx
if nginx -t; then
    systemctl reload nginx
    echo -e "${GREEN}✅ Nginx перезапущен${NC}"
else
    echo -e "${RED}❌ Ошибка в конфигурации Nginx${NC}"
    nginx -t
    exit 1
fi

# Перезапуск Next.js
systemctl restart nextjs
sleep 3

if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js перезапущен${NC}"
else
    echo -e "${RED}❌ Next.js не запустился${NC}"
    journalctl -u nextjs -n 20 --no-pager
fi

# Пересборка frontend (если нужно)
echo "Пересборка frontend..."
cd /opt/eco-project/frontend
npm run build
echo -e "${GREEN}✅ Frontend пересобран${NC}"

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ИСПРАВЛЕНО!"
echo "==========================================${NC}"
echo ""
echo "Проверьте:"
echo "  1. Backend: curl http://127.0.0.1:8080/health"
echo "  2. Frontend: curl http://127.0.0.1:3001"
echo "  3. API через Nginx: curl http://127.0.0.1:3384/api/health"
echo ""
echo "Если всё работает, попробуйте войти снова:"
echo "  http://85.113.129.96:3384/login"
echo ""


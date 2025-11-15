#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ ВСЕХ ПРОБЛЕМ С МАРШРУТИЗАЦИЕЙ
# ==========================================
# Исправляет:
# 1. GET /api/requirement/{id}/risks - 404
# 2. GET /api/document/{id}/download - 404
# 3. POST /api/document/upload - 403
# 4. CSP violation в консоли

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ИСПРАВЛЕНИЕ ПРОБЛЕМ С МАРШРУТИЗАЦИЕЙ"
echo "==========================================${NC}"
echo ""

# Определяем порты
NEXTJS_PORT=3002
BACKEND_PORT=8082
NGINX_PORT=3384

# 1. Проверка, что мы в правильной директории
if [ ! -d "/opt/eco-project" ]; then
    echo -e "${RED}❌ Директория /opt/eco-project не найдена${NC}"
    echo -e "${YELLOW}Выполните скрипт из корня проекта или установите правильный путь${NC}"
    exit 1
fi

cd /opt/eco-project

echo -e "${YELLOW}[1/7] Обновление кода из git...${NC}"
git pull || echo -e "${YELLOW}⚠️  Git pull не выполнен (возможно, нет изменений)${NC}"
echo ""

# 2. Проверка и исправление конфигурации Nginx
echo -e "${YELLOW}[2/7] Проверка конфигурации Nginx...${NC}"
cat > /etc/nginx/sites-available/eco-api-proxy.conf << EOF
server {
    listen ${NGINX_PORT};
    server_name _;

    # Увеличиваем размер загружаемых файлов для upload
    client_max_body_size 100M;

    # Frontend (Next.js)
    location / {
        proxy_pass http://127.0.0.1:${NEXTJS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Таймауты
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Backend API - используем rewrite для правильной обработки пути
    location /api/ {
        rewrite ^/api/(.*)$ /\$1 break;
        proxy_pass http://127.0.0.1:${BACKEND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Таймауты
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Для загрузки файлов
        client_max_body_size 100M;
    }
    
    # Обработка /api без завершающего слэша
    location = /api {
        return 301 /api/;
    }
}
EOF

ln -sf /etc/nginx/sites-available/eco-api-proxy.conf /etc/nginx/sites-enabled/eco-api-proxy.conf
echo -e "${GREEN}✅ Nginx конфигурация обновлена${NC}"
echo ""

# 3. Проверка синтаксиса Nginx
echo -e "${YELLOW}[3/7] Проверка синтаксиса Nginx...${NC}"
if nginx -t; then
    echo -e "${GREEN}✅ Синтаксис Nginx корректен${NC}"
else
    echo -e "${RED}❌ Ошибка в синтаксисе Nginx${NC}"
    nginx -t
    exit 1
fi
echo ""

# 4. Проверка прав доступа к директориям
echo -e "${YELLOW}[4/7] Проверка прав доступа...${NC}"
# Убеждаемся, что директория storage существует и доступна для записи
if [ -d "backend/api/storage" ]; then
    chmod -R 755 backend/api/storage
    chown -R www-data:www-data backend/api/storage 2>/dev/null || chown -R root:root backend/api/storage
    echo -e "${GREEN}✅ Права доступа к storage обновлены${NC}"
else
    mkdir -p backend/api/storage
    chmod -R 755 backend/api/storage
    chown -R www-data:www-data backend/api/storage 2>/dev/null || chown -R root:root backend/api/storage
    echo -e "${GREEN}✅ Директория storage создана${NC}"
fi

# Исправляем права доступа к runtime директории
if [ -d "backend/api/runtime" ]; then
    chmod -R 755 backend/api/runtime
    chown -R www-data:www-data backend/api/runtime 2>/dev/null || chown -R root:root backend/api/runtime
    echo -e "${GREEN}✅ Права доступа к runtime обновлены${NC}"
else
    mkdir -p backend/api/runtime
    chmod -R 755 backend/api/runtime
    chown -R www-data:www-data backend/api/runtime 2>/dev/null || chown -R root:root backend/api/runtime
    echo -e "${GREEN}✅ Директория runtime создана${NC}"
fi
echo ""

# 5. Перезапуск PHP-FPM для применения изменений в контроллерах
echo -e "${YELLOW}[5/7] Перезапуск PHP-FPM...${NC}"
systemctl restart php8.2-fpm
if systemctl is-active --quiet php8.2-fpm; then
    echo -e "${GREEN}✅ PHP-FPM перезапущен${NC}"
else
    echo -e "${RED}❌ Ошибка при перезапуске PHP-FPM${NC}"
    systemctl status php8.2-fpm --no-pager
    exit 1
fi
echo ""

# 6. Перезапуск Nginx
echo -e "${YELLOW}[6/7] Перезапуск Nginx...${NC}"
systemctl restart nginx
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Nginx перезапущен${NC}"
else
    echo -e "${RED}❌ Ошибка при перезапуске Nginx${NC}"
    systemctl status nginx --no-pager
    exit 1
fi
echo ""

# 7. Перезапуск Next.js (для применения CSP изменений)
echo -e "${YELLOW}[7/7] Перезапуск Next.js...${NC}"
if systemctl is-active --quiet nextjs; then
    systemctl restart nextjs
    sleep 5
    if systemctl is-active --quiet nextjs; then
        echo -e "${GREEN}✅ Next.js перезапущен${NC}"
    else
        echo -e "${YELLOW}⚠️  Next.js не запустился автоматически, проверьте вручную${NC}"
        journalctl -u nextjs -n 20 --no-pager
    fi
else
    echo -e "${YELLOW}⚠️  Next.js не запущен, запускаем...${NC}"
    systemctl start nextjs
    sleep 5
    if systemctl is-active --quiet nextjs; then
        echo -e "${GREEN}✅ Next.js запущен${NC}"
    else
        echo -e "${YELLOW}⚠️  Next.js не запустился, проверьте вручную${NC}"
        journalctl -u nextjs -n 20 --no-pager
    fi
fi
echo ""

# 8. Финальная проверка
echo -e "${BLUE}=========================================="
echo "✅ ВСЕ ИСПРАВЛЕНИЯ ПРИМЕНЕНЫ"
echo "==========================================${NC}"
echo ""
echo -e "${GREEN}Проверьте работу следующих эндпоинтов:${NC}"
echo "  - GET  /api/requirement/{id}/risks"
echo "  - GET  /api/document/{id}/download"
echo "  - POST /api/document/upload"
echo ""
echo -e "${YELLOW}Если проблемы остались, проверьте логи:${NC}"
echo "  - Backend: tail -f /opt/eco-project/backend/api/runtime/logs/app.log"
echo "  - Nginx:   tail -f /var/log/nginx/error.log"
echo "  - PHP-FPM: journalctl -u php8.2-fpm -f"
echo ""


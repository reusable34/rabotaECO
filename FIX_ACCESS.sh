#!/bin/bash
# ==========================================
# ИСПРАВЛЕНИЕ ДОСТУПА К САЙТУ
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ПРОВЕРКА И НАСТРОЙКА ДОСТУПА"
echo "==========================================${NC}"
echo ""

# 1. Проверка сервисов
echo -e "${YELLOW}[1/4] Проверка сервисов...${NC}"
systemctl status nginx --no-pager | head -3 || echo "Nginx не запущен"
systemctl status php8.2-fpm --no-pager | head -3 || echo "PHP-FPM не запущен"

# 2. Проверка портов
echo -e "${YELLOW}[2/4] Проверка портов...${NC}"
netstat -tuln | grep -E ":(80|3000|3001|8080)" || echo "Порты не слушаются"

# 3. Запуск Next.js если нужно
echo -e "${YELLOW}[3/4] Проверка Frontend...${NC}"
if ! netstat -tuln | grep -q ":3001"; then
    echo "Frontend не запущен, запускаю..."
    cd /opt/eco-project/frontend
    nohup npm start > /tmp/nextjs.log 2>&1 &
    sleep 3
    echo "Frontend запущен"
else
    echo "Frontend уже работает"
fi

# 4. Настройка через Nginx Proxy Manager (инструкция)
echo -e "${YELLOW}[4/4] Инструкция для Nginx Proxy Manager...${NC}"
echo ""
echo -e "${GREEN}Настройте через Nginx Proxy Manager:${NC}"
echo "1. Откройте: http://85.113.129.96:81"
echo "2. Войдите в админ-панель"
echo "3. Hosts -> Proxy Hosts -> Add Proxy Host"
echo "4. Заполните:"
echo "   - Domain Names: 85.113.129.96 (или ваш домен)"
echo "   - Scheme: http"
echo "   - Forward Hostname/IP: 127.0.0.1"
echo "   - Forward Port: 3000"
echo "   - Cache Assets: включить"
echo "   - Block Common Exploits: включить"
echo "5. Save"
echo ""
echo -e "${BLUE}Или используйте прямой доступ:${NC}"
echo "http://85.113.129.96:3000 (если порт открыт на роутере)"
echo ""


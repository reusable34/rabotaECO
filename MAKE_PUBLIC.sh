#!/bin/bash
# ==========================================
# СДЕЛАТЬ САЙТ ДОСТУПНЫМ В ИНТЕРНЕТЕ
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

IP=$(hostname -I | awk '{print $1}')

echo -e "${BLUE}=========================================="
echo "🌐 НАСТРОЙКА ДОСТУПА В ИНТЕРНЕТ"
echo "==========================================${NC}"
echo ""

# 1. Настройка Nginx на порту 80
echo -e "${YELLOW}[1/3] Настройка Nginx...${NC}"

cat > /etc/nginx/sites-available/eco-public << NGINX
server {
    listen 80;
    server_name _;

    # Frontend
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Backend API
    location /api {
        rewrite ^/api(.*) \$1 break;
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Backend напрямую (для совместимости)
    location ~ ^/(auth|client|requirement|document|contract|event|category|risk|user|npa) {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX

# Активация
ln -sf /etc/nginx/sites-available/eco-public /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/eco-backend
rm -f /etc/nginx/sites-enabled/eco-frontend
rm -f /etc/nginx/sites-enabled/default

# Проверка конфигурации
nginx -t

# 2. Настройка firewall (если установлен)
echo -e "${YELLOW}[2/3] Настройка firewall...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    echo "UFW настроен"
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    echo "Firewalld настроен"
else
    echo "Firewall не найден, пропускаю"
fi

# 3. Перезапуск Nginx
echo -e "${YELLOW}[3/3] Перезапуск Nginx...${NC}"
systemctl restart nginx

# Итог
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "ВАШ_IP")

echo ""
echo -e "${GREEN}=========================================="
echo "✅ САЙТ ДОСТУПЕН В ИНТЕРНЕТЕ!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}🌐 Доступ:${NC}"
echo "  Локально:  http://${IP}"
echo "  Интернет:  http://${EXTERNAL_IP}"
echo ""
echo -e "${YELLOW}📝 Примечания:${NC}"
echo "  - Frontend доступен на главной странице"
echo "  - Backend API доступен по /api/*"
echo "  - Для HTTPS настройте SSL сертификат (Let's Encrypt)"
echo ""


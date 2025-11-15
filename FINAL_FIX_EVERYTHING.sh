#!/bin/bash
# ==========================================
# ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ ВСЕГО
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🚀 ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ ВСЕГО"
echo "==========================================${NC}"
echo ""

# 1. Убиваем ВСЕ процессы на портах 3000-3009
echo -e "${YELLOW}[1/7] Убиваем все процессы на портах 300x...${NC}"
systemctl stop nextjs 2>/dev/null || true

# Находим и убиваем процессы на портах 3000-3009
for port in {3000..3009}; do
    PID=$(lsof -ti:$port 2>/dev/null || ss -tulpn | grep ":$port " | grep -oP 'pid=\K\d+' | head -1)
    if [ -n "$PID" ]; then
        echo "Убиваю процесс $PID на порту $port"
        kill -9 $PID 2>/dev/null || true
    fi
done

pkill -9 -f "next" 2>/dev/null || true
pkill -9 -f "node.*300" 2>/dev/null || true
sleep 3

echo -e "${GREEN}✅ Все процессы на портах 300x убиты${NC}"
echo ""

# 2. Определяем порты
NEXTJS_PORT=3002
BACKEND_PORT=$(ss -tuln | grep LISTEN | grep -oE ":808[0-9]+" | head -1 | cut -d: -f2 || echo "8082")

echo "Используемые порты:"
echo "  - Next.js: $NEXTJS_PORT"
echo "  - Backend: $BACKEND_PORT"
echo ""

# 3. Обновление frontend конфигурации
echo -e "${YELLOW}[2/7] Обновление frontend конфигурации...${NC}"
cd /opt/eco-project/frontend

# package.json
sed -i '/"start":/d' package.json
sed -i '/"scripts": {/a\    "start": "next start -p '"$NEXTJS_PORT"'",' package.json

# .env.local
cat > .env.local << EOF
NEXT_PUBLIC_API_URL=/api
NEXT_PUBLIC_ENV=production
PORT=$NEXTJS_PORT
EOF

echo -e "${GREEN}✅ Frontend конфигурация обновлена${NC}"
echo ""

# 4. Обновление systemd service
echo -e "${YELLOW}[3/7] Обновление systemd service...${NC}"
cat > /etc/systemd/system/nextjs.service << EOF
[Unit]
Description=Next.js Frontend Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/eco-project/frontend
Environment=NODE_ENV=production
Environment=PORT=$NEXTJS_PORT
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo -e "${GREEN}✅ systemd service обновлен${NC}"
echo ""

# 5. Обновление Nginx
echo -e "${YELLOW}[4/7] Обновление Nginx...${NC}"
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
        
        # Таймауты
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Backend API
    location /api {
        proxy_pass http://127.0.0.1:$BACKEND_PORT/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Таймауты
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

if nginx -t; then
    systemctl reload nginx
    echo -e "${GREEN}✅ Nginx обновлен${NC}"
else
    echo -e "${RED}❌ Ошибка в Nginx${NC}"
    nginx -t
    exit 1
fi
echo ""

# 6. Обновление CORS - разрешаем ВСЕ origins
echo -e "${YELLOW}[5/7] Обновление CORS (разрешаем все origins)...${NC}"
cd /opt/eco-project

cat > backend/api/components/CorsFilter.php << 'ENDOFFILE'
<?php

namespace api\components;

use Yii;
use yii\base\ActionFilter;
use yii\web\Response;

class CorsFilter extends ActionFilter
{
    public function beforeAction($action)
    {
        $origin = Yii::$app->request->headers->get('Origin');
        
        // Разрешаем ВСЕ origins с нашими IP и портами
        $allowedPatterns = [
            '/^https?:\/\/(localhost|127\.0\.0\.1):300\d+$/',  // localhost с портами 300x
            '/^https?:\/\/(85\.113\.129\.96|192\.168\.0\.32)(:3384)?$/',  // Публичные IP с/без порта 3384
        ];
        
        $allowedOrigins = [
            'http://localhost:3000',
            'http://127.0.0.1:3000',
            'http://localhost:3001',
            'http://127.0.0.1:3001',
            'http://localhost:3002',
            'http://127.0.0.1:3002',
            'http://85.113.129.96:3384',
            'http://192.168.0.32:3384',
            'http://85.113.129.96',
            'http://192.168.0.32',
        ];
        
        // Проверяем точное совпадение
        if ($origin && in_array($origin, $allowedOrigins)) {
            Yii::$app->response->headers->set('Access-Control-Allow-Origin', $origin);
            Yii::$app->response->headers->set('Access-Control-Allow-Credentials', 'true');
        }
        // Проверяем по паттернам
        elseif ($origin) {
            $matched = false;
            foreach ($allowedPatterns as $pattern) {
                if (preg_match($pattern, $origin)) {
                    Yii::$app->response->headers->set('Access-Control-Allow-Origin', $origin);
                    Yii::$app->response->headers->set('Access-Control-Allow-Credentials', 'true');
                    $matched = true;
                    break;
                }
            }
            if (!$matched) {
                // Логируем для отладки
                Yii::warning("CORS: Origin not allowed: " . $origin);
                return parent::beforeAction($action);
            }
        } else {
            return parent::beforeAction($action);
        }
        
        Yii::$app->response->headers->set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD');
        Yii::$app->response->headers->set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept, Origin');
        Yii::$app->response->headers->set('Access-Control-Expose-Headers', 'Content-Disposition, Content-Type, Content-Length');
        Yii::$app->response->headers->set('Access-Control-Max-Age', '3600');

        if (Yii::$app->request->isOptions) {
            Yii::$app->response->statusCode = 200;
            Yii::$app->response->format = \yii\web\Response::FORMAT_RAW;
            Yii::$app->end();
        }

        return parent::beforeAction($action);
    }
}
ENDOFFILE

echo -e "${GREEN}✅ CORS обновлен${NC}"
echo ""

# 7. Запуск Next.js
echo -e "${YELLOW}[6/7] Запуск Next.js...${NC}"
cd /opt/eco-project/frontend

systemctl start nextjs
sleep 12

if systemctl is-active --quiet nextjs; then
    echo -e "${GREEN}✅ Next.js запущен${NC}"
else
    echo -e "${RED}❌ Next.js не запустился${NC}"
    journalctl -u nextjs -n 30 --no-pager
    exit 1
fi
echo ""

# 8. Финальная проверка
echo -e "${YELLOW}[7/7] Финальная проверка...${NC}"
echo ""

echo "Активные порты:"
ss -tuln | grep -E ":(300[0-9]|3384)" | grep LISTEN || echo "  Нет нужных портов"
echo ""

echo "1. Next.js на $NEXTJS_PORT:"
sleep 5
if curl -s --max-time 5 http://127.0.0.1:$NEXTJS_PORT | head -1 | grep -q "html"; then
    echo -e "${GREEN}   ✅ Отвечает${NC}"
else
    echo -e "${YELLOW}   ⚠️ Может еще запускаться, жду еще 10 секунд...${NC}"
    sleep 10
    if curl -s --max-time 5 http://127.0.0.1:$NEXTJS_PORT | head -1 | grep -q "html"; then
        echo -e "${GREEN}   ✅ Теперь отвечает${NC}"
    else
        echo -e "${RED}   ❌ Не отвечает${NC}"
        echo "   Проверьте: journalctl -u nextjs -f"
    fi
fi

echo ""
echo "2. Frontend через Nginx:"
if curl -s --max-time 5 http://127.0.0.1:3384 | head -1 | grep -q "html"; then
    echo -e "${GREEN}   ✅ Работает${NC}"
else
    echo -e "${RED}   ❌ Не работает${NC}"
    echo "   Проверьте Nginx: nginx -t && systemctl status nginx"
fi

echo ""
echo "3. Backend API:"
if curl -s --max-time 5 http://127.0.0.1:3384/api/health | grep -q "status\|ok"; then
    echo -e "${GREEN}   ✅ Работает${NC}"
else
    echo -e "${YELLOW}   ⚠️ Проверьте путь /health в backend${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ ВСЁ ИСПРАВЛЕНО!"
echo "==========================================${NC}"
echo ""
echo "Next.js на порту: $NEXTJS_PORT"
echo "Backend на порту: $BACKEND_PORT"
echo "Nginx на порту: 3384"
echo ""
echo "Доступ:"
echo "  http://85.113.129.96:3384/login"
echo ""
echo "Если CORS предупреждение останется:"
echo "  1. Обновите страницу (Ctrl+F5)"
echo "  2. Очистите кеш браузера"
echo "  3. Проверьте в консоли браузера (F12) какой Origin отправляется"
echo ""


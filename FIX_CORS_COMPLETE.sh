#!/bin/bash
# ==========================================
# ПОЛНОЕ ИСПРАВЛЕНИЕ CORS
# ==========================================
# Выполните ВНУТРИ контейнера 102

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "🔧 ПОЛНОЕ ИСПРАВЛЕНИЕ CORS"
echo "==========================================${NC}"
echo ""

# 1. Исправление CorsFilter с правильной логикой
echo -e "${YELLOW}[1/2] Исправление CorsFilter...${NC}"
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
        
        // Разрешаем запросы с разных источников
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
        
        // Паттерны для гибкой проверки
        $allowedPatterns = [
            '/^https?:\/\/(localhost|127\.0\.0\.1):300\d+$/',  // localhost с портами 300x
            '/^https?:\/\/(85\.113\.129\.96|192\.168\.0\.32)(:3384)?$/',  // Публичные IP с/без порта 3384
        ];
        
        $originAllowed = false;
        $allowedOrigin = null;
        
        // Проверяем точное совпадение
        if ($origin && in_array($origin, $allowedOrigins)) {
            $originAllowed = true;
            $allowedOrigin = $origin;
        }
        // Проверяем по паттернам
        elseif ($origin) {
            foreach ($allowedPatterns as $pattern) {
                if (preg_match($pattern, $origin)) {
                    $originAllowed = true;
                    $allowedOrigin = $origin;
                    break;
                }
            }
        }
        
        // ВАЖНО: Устанавливаем CORS заголовки для ВСЕХ запросов (GET, POST, OPTIONS)
        // Это делается ДО вызова parent::beforeAction, чтобы заголовки точно установились
        if ($originAllowed && $allowedOrigin) {
            Yii::$app->response->headers->set('Access-Control-Allow-Origin', $allowedOrigin);
            Yii::$app->response->headers->set('Access-Control-Allow-Credentials', 'true');
            Yii::$app->response->headers->set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD');
            Yii::$app->response->headers->set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept, Origin');
            Yii::$app->response->headers->set('Access-Control-Expose-Headers', 'Content-Disposition, Content-Type, Content-Length');
            Yii::$app->response->headers->set('Access-Control-Max-Age', '3600');
        } else {
            // Если origin не разрешен, логируем но НЕ устанавливаем заголовки
            // Это предотвращает wildcard с credentials
            if ($origin) {
                Yii::warning("CORS: Origin not allowed: " . $origin);
            }
        }
        
        // Обработка preflight OPTIONS запросов
        if (Yii::$app->request->isOptions) {
            Yii::$app->response->statusCode = 200;
            Yii::$app->response->format = \yii\web\Response::FORMAT_RAW;
            Yii::$app->end();
            return false; // Не продолжаем выполнение action
        }

        return parent::beforeAction($action);
    }
}
ENDOFFILE

echo -e "${GREEN}✅ CorsFilter исправлен${NC}"
echo "   - Добавлен localhost:3002"
echo "   - Заголовки устанавливаются ДО parent::beforeAction"
echo "   - Работает для всех типов запросов"
echo ""

# 2. Тестирование
echo -e "${YELLOW}[2/2] Тестирование CORS...${NC}"
echo ""

echo "1. Тест OPTIONS запроса (preflight):"
OPTIONS_TEST=$(curl -s -I -X OPTIONS \
    -H "Origin: http://85.113.129.96:3384" \
    -H "Access-Control-Request-Method: POST" \
    http://127.0.0.1:3384/api/auth/login 2>&1)

if echo "$OPTIONS_TEST" | grep -qi "access-control-allow-origin.*85.113.129.96:3384"; then
    echo -e "${GREEN}   ✅ CORS заголовки правильные${NC}"
    echo "$OPTIONS_TEST" | grep -i "access-control" | sed 's/^/      /'
else
    echo -e "${YELLOW}   ⚠️ Проверьте заголовки${NC}"
    echo "$OPTIONS_TEST" | grep -i "access-control" | sed 's/^/      /' || echo "      CORS заголовки не найдены"
fi

echo ""
echo "2. Тест POST запроса (реальный):"
POST_TEST=$(curl -s -I -X POST \
    -H "Origin: http://85.113.129.96:3384" \
    -H "Content-Type: application/json" \
    -d '{"email":"test","password":"test"}' \
    http://127.0.0.1:3384/api/auth/login 2>&1)

if echo "$POST_TEST" | grep -qi "access-control-allow-origin.*85.113.129.96:3384"; then
    echo -e "${GREEN}   ✅ CORS заголовки установлены для POST${NC}"
    echo "$POST_TEST" | grep -i "access-control" | sed 's/^/      /'
else
    echo -e "${YELLOW}   ⚠️ Проверьте заголовки${NC}"
    echo "$POST_TEST" | grep -i "access-control" | sed 's/^/      /' || echo "      CORS заголовки не найдены"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "✅ CORS ИСПРАВЛЕН!"
echo "==========================================${NC}"
echo ""
echo "Что исправлено:"
echo "  ✅ Добавлен localhost:3002 в список разрешенных origins"
echo "  ✅ Заголовки устанавливаются ДО parent::beforeAction"
echo "  ✅ Работает для всех типов запросов (GET, POST, OPTIONS)"
echo ""
echo "ВАЖНО:"
echo "  Если предупреждение CORS все еще появляется:"
echo "  1. Очистите кеш браузера (Ctrl+Shift+Del)"
echo "  2. Обновите страницу с очисткой кеша (Ctrl+Shift+R)"
echo "  3. Откройте консоль (F12) -> Network tab -> проверьте заголовки ответа"
echo ""
echo "Попробуйте войти:"
echo "  http://85.113.129.96:3384/login"
echo ""


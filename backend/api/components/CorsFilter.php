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
        
        // Разрешаем запросы с разных источников (БЕЗ wildcard для безопасности)
        $allowedOrigins = [
            // Локальные разработка
            'http://localhost:3000',
            'http://127.0.0.1:3000',
            'http://localhost:3001',
            'http://127.0.0.1:3001',
            'http://localhost:3002',
            'http://127.0.0.1:3002',
            // Публичные с портом 3384
            'http://85.113.129.96:3384',
            'http://192.168.0.32:3384',
            // Публичные без порта (если через Nginx Proxy Manager)
            'http://85.113.129.96',
            'http://192.168.0.32',
            // HTTPS варианты (на будущее)
            'https://85.113.129.96:3384',
            'https://85.113.129.96',
        ];
        
        // ВАЖНО: Устанавливаем CORS заголовки ДО любой другой логики
        if ($origin && in_array($origin, $allowedOrigins)) {
            Yii::$app->response->headers->set('Access-Control-Allow-Origin', $origin);
            Yii::$app->response->headers->set('Access-Control-Allow-Credentials', 'true');
            Yii::$app->response->headers->set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD');
            Yii::$app->response->headers->set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept, Origin');
            Yii::$app->response->headers->set('Access-Control-Expose-Headers', 'Content-Disposition, Content-Type, Content-Length');
            Yii::$app->response->headers->set('Access-Control-Max-Age', '3600');
        }
        
        // Обработка preflight OPTIONS запросов
        if (Yii::$app->request->isOptions) {
            Yii::$app->response->statusCode = 200;
            Yii::$app->response->format = \yii\web\Response::FORMAT_RAW;
            Yii::$app->response->data = '';
            Yii::$app->end();
            return false;
        }

        return parent::beforeAction($action);
    }
}


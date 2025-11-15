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
            'http://85.113.129.96:3384',
            'http://192.168.0.32:3384',
        ];
        
        // Если origin в списке разрешенных, используем его
        if ($origin && in_array($origin, $allowedOrigins)) {
            Yii::$app->response->headers->set('Access-Control-Allow-Origin', $origin);
            Yii::$app->response->headers->set('Access-Control-Allow-Credentials', 'true');
        } else {
            // Если origin не указан или не в списке, не устанавливаем заголовки
            // Это предотвращает использование wildcard с credentials
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


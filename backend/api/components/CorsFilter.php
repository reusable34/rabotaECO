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
        
        // Разрешаем запросы с любых источников (для продакшн)
        // Можно ограничить конкретными доменами если нужно
        $allowedOrigins = [
            'http://localhost:3000',
            'http://127.0.0.1:3000',
            'http://85.113.129.96:3384',
            'http://85.113.129.96',
        ];
        
        // Если origin в списке разрешенных - используем его, иначе разрешаем все (для разработки)
        if ($origin) {
            if (in_array($origin, $allowedOrigins)) {
                Yii::$app->response->headers->set('Access-Control-Allow-Origin', $origin);
            } else {
                // Для продакшн разрешаем запросы с любого origin
                Yii::$app->response->headers->set('Access-Control-Allow-Origin', $origin);
            }
        } else {
            // Если нет Origin заголовка, разрешаем все
            Yii::$app->response->headers->set('Access-Control-Allow-Origin', '*');
        }
        
        Yii::$app->response->headers->set('Access-Control-Allow-Credentials', 'true');
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


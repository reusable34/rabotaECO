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
        
        // Разрешаем запросы с localhost:3000
        $allowedOrigins = ['http://localhost:3000', 'http://127.0.0.1:3000'];
        
        if ($origin && in_array($origin, $allowedOrigins)) {
            Yii::$app->response->headers->set('Access-Control-Allow-Origin', $origin);
        } else {
            // Для других источников используем первый разрешённый
            Yii::$app->response->headers->set('Access-Control-Allow-Origin', $allowedOrigins[0]);
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


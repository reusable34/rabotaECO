<?php

namespace api\controllers;

use common\models\Npa;
use Yii;
use api\components\JwtHttpBearerAuth;
use yii\filters\AccessControl;
use yii\rest\ActiveController;

class NpaController extends ActiveController
{
    public $modelClass = 'common\models\Npa';

    public function behaviors()
    {
        $behaviors = parent::behaviors();
        
        // CORS настройки
        $behaviors['cors'] = [
            'class' => \yii\filters\Cors::class,
            'cors' => [
                'Origin' => ['http://localhost:3000'],
                'Access-Control-Request-Method' => ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
                'Access-Control-Request-Headers' => ['Authorization', 'Content-Type'],
                'Access-Control-Allow-Credentials' => true,
                'Access-Control-Max-Age' => 3600,
            ],
        ];
        
        $behaviors['authenticator'] = [
            'class' => JwtHttpBearerAuth::class,
            'except' => ['options'],
        ];
        
        $behaviors['access'] = [
            'class' => AccessControl::class,
            'rules' => [
                [
                    'allow' => true,
                    'actions' => ['index', 'view'],
                    'roles' => ['@'],
                ],
                [
                    'allow' => true,
                    'actions' => ['create', 'update', 'delete'],
                    'matchCallback' => function ($rule, $action) {
                        $user = Yii::$app->user->identity;
                        return $user && $user->role === \common\models\User::ROLE_ADMIN;
                    },
                ],
                [
                    'allow' => true,
                    'actions' => ['options'],
                ],
            ],
        ];
        
        return $behaviors;
    }

    public function actionOptions()
    {
        Yii::$app->response->statusCode = 200;
        Yii::$app->response->format = \yii\web\Response::FORMAT_RAW;
        return '';
    }
}


<?php

namespace api\controllers;

use common\models\Event;
use common\models\User;
use Yii;
use api\components\JwtHttpBearerAuth;
use yii\filters\AccessControl;
use yii\rest\ActiveController;

class EventController extends ActiveController
{
    public $modelClass = 'common\models\Event';

    public function behaviors()
    {
        $behaviors = parent::behaviors();
        
        // CORS обрабатывается глобально через CorsFilter в main.php
        // Не нужно дублировать здесь
        
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
                        return $user && $user->role === User::ROLE_ADMIN;
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

    public function actions()
    {
        $actions = parent::actions();
        
        // Переопределяем actionIndex для фильтрации по client_id
        $actions['index']['prepareDataProvider'] = function() {
            $user = Yii::$app->user->identity;
            
            // Админ видит все события
            if ($user->role === User::ROLE_ADMIN) {
                return new \yii\data\ActiveDataProvider([
                    'query' => Event::find(),
                ]);
            }

            // Клиенты и менеджеры видят только события своих клиентов
            if ($user->client_id) {
                return new \yii\data\ActiveDataProvider([
                    'query' => Event::find()->where(['client_id' => $user->client_id]),
                ]);
            }

            return new \yii\data\ActiveDataProvider([
                'query' => Event::find()->where(['client_id' => 0]), // Пустой результат
            ]);
        };
        
        // Настраиваем стандартные create, update, delete с проверкой прав
        $actions['create']['checkAccess'] = function($action, $model = null, $params = []) {
            $user = Yii::$app->user->identity;
            if (!$user || $user->role !== User::ROLE_ADMIN) {
                throw new \yii\web\ForbiddenHttpException('Only admins can create events');
            }
            return true;
        };
        
        $actions['update']['checkAccess'] = function($action, $model = null, $params = []) {
            $user = Yii::$app->user->identity;
            if (!$user || $user->role !== User::ROLE_ADMIN) {
                throw new \yii\web\ForbiddenHttpException('Only admins can update events');
            }
            return true;
        };
        
        $actions['delete']['checkAccess'] = function($action, $model = null, $params = []) {
            $user = Yii::$app->user->identity;
            if (!$user || $user->role !== User::ROLE_ADMIN) {
                throw new \yii\web\ForbiddenHttpException('Only admins can delete events');
            }
            return true;
        };
        
        return $actions;
    }
}


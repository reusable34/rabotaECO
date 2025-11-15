<?php

namespace api\controllers;

use common\models\Client;
use common\models\User;
use common\services\RequirementGeneratorService;
use Yii;
use api\components\JwtHttpBearerAuth;
use yii\filters\AccessControl;
use yii\rest\ActiveController;
use yii\web\ForbiddenHttpException;
use yii\web\NotFoundHttpException;

class ClientController extends ActiveController
{
    public $modelClass = 'common\models\Client';

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
                        return $user && in_array($user->role, [User::ROLE_ADMIN, User::ROLE_MANAGER]);
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
        unset($actions['create']);
        
        // Переопределяем actionIndex для фильтрации по client_id
        $actions['index']['prepareDataProvider'] = function() {
            $user = Yii::$app->user->identity;
            
            // Админ видит всех клиентов
            if ($user->role === User::ROLE_ADMIN) {
                return new \yii\data\ActiveDataProvider([
                    'query' => Client::find(),
                ]);
            }

            // Клиенты и менеджеры видят только своих клиентов
            if ($user->client_id) {
                return new \yii\data\ActiveDataProvider([
                    'query' => Client::find()->where(['id' => $user->client_id]),
                ]);
            }

            return new \yii\data\ActiveDataProvider([
                'query' => Client::find()->where(['id' => 0]), // Пустой результат
            ]);
        };
        
        return $actions;
    }

    public function actionCreate()
    {
        $model = new Client();
        $model->load(Yii::$app->request->post(), '');

        if ($model->save()) {
            // Автоматическое формирование требований
            RequirementGeneratorService::generateRequirements($model);
            return $model;
        }

        return $model->errors;
    }

    public function checkAccess($action, $model = null, $params = [])
    {
        $user = Yii::$app->user->identity;

        if ($user->role === User::ROLE_CLIENT && $model && $model->id !== $user->client_id) {
            throw new ForbiddenHttpException('You do not have permission to access this resource');
        }

        if ($user->role === User::ROLE_MANAGER && $model && $model->id !== $user->client_id) {
            throw new ForbiddenHttpException('You do not have permission to access this resource');
        }
    }
}


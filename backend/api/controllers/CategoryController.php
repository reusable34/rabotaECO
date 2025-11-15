<?php

namespace api\controllers;

use common\models\Category;
use common\models\User;
use common\models\Client;
use Yii;
use yii\filters\AccessControl;
use api\components\JwtHttpBearerAuth;
use yii\rest\ActiveController;

class CategoryController extends ActiveController
{
    public $modelClass = 'common\models\Category';

    public function behaviors()
    {
        $behaviors = parent::behaviors();
        $behaviors['authenticator'] = [
            'class' => JwtHttpBearerAuth::class,
        ];
        $behaviors['access'] = [
            'class' => AccessControl::class,
            'rules' => [
                [
                    'allow' => true,
                    'roles' => ['@'],
                ],
            ],
        ];
        return $behaviors;
    }

    public function actions()
    {
        $actions = parent::actions();
        
        // Переопределяем actionIndex для фильтрации по клиенту пользователя
        $actions['index']['prepareDataProvider'] = function() {
            $user = Yii::$app->user->identity;
            
            // Админ видит все категории
            if ($user->role === User::ROLE_ADMIN) {
                return new \yii\data\ActiveDataProvider([
                    'query' => Category::find(),
                ]);
            }

            // Если у пользователя есть привязанный клиент, показываем только категорию этого клиента
            if ($user->client_id) {
                $client = Client::findOne($user->client_id);
                if ($client && $client->category_id) {
                    return new \yii\data\ActiveDataProvider([
                        'query' => Category::find()->where(['id' => $client->category_id]),
                    ]);
                }
            }

            // Для остальных пользователей (специалисты без клиента) возвращаем пустой результат
            return new \yii\data\ActiveDataProvider([
                'query' => Category::find()->where('1=0'), // Пустой результат
            ]);
        };
        
        return $actions;
    }
}


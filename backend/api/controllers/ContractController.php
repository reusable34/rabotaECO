<?php

namespace api\controllers;

use common\models\Contract;
use common\models\User;
use Yii;
use api\components\JwtHttpBearerAuth;
use yii\filters\AccessControl;
use yii\rest\ActiveController;

class ContractController extends ActiveController
{
    public $modelClass = 'common\models\Contract';

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
        
        // Переопределяем actionIndex для фильтрации по client_id
        $actions['index']['prepareDataProvider'] = function() {
            $user = Yii::$app->user->identity;
            
            // Админ видит все договоры
            if ($user->role === User::ROLE_ADMIN) {
                return new \yii\data\ActiveDataProvider([
                    'query' => Contract::find(),
                    'pagination' => false, // ОТКЛЮЧАЕМ ПАГИНАЦИЮ
                ]);
            }

            // Клиенты и менеджеры видят только договоры своих клиентов
            if ($user->client_id) {
                return new \yii\data\ActiveDataProvider([
                    'query' => Contract::find()->where(['client_id' => $user->client_id]),
                    'pagination' => false, // ОТКЛЮЧАЕМ ПАГИНАЦИЮ
                ]);
            }

            return new \yii\data\ActiveDataProvider([
                'query' => Contract::find()->where(['client_id' => 0]), // Пустой результат
                'pagination' => false,
            ]);
        };
        
        return $actions;
    }
}


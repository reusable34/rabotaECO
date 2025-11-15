<?php

namespace api\controllers;

use common\models\User;
use Yii;
use api\components\JwtHttpBearerAuth;
use yii\filters\AccessControl;
use yii\rest\ActiveController;
use yii\web\BadRequestHttpException;
use yii\web\ForbiddenHttpException;

class UserController extends ActiveController
{
    public $modelClass = 'common\models\User';

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
        
        // Переопределяем actionIndex - только админы видят всех пользователей
        $actions['index']['prepareDataProvider'] = function() {
            $user = Yii::$app->user->identity;
            
            if ($user->role !== User::ROLE_ADMIN) {
                throw new ForbiddenHttpException('Only admins can view users');
            }
            
            return new \yii\data\ActiveDataProvider([
                'query' => User::find(),
            ]);
        };
        
        // Отключаем стандартные create, update, delete - используем свои
        unset($actions['create'], $actions['update'], $actions['delete']);
        
        return $actions;
    }

    public function actionCreate()
    {
        $user = Yii::$app->user->identity;
        if ($user->role !== User::ROLE_ADMIN) {
            throw new ForbiddenHttpException('Only admins can create users');
        }

        $model = new User();
        $data = Yii::$app->request->post();
        
        $model->name = $data['name'] ?? '';
        $model->email = $data['email'] ?? '';
        $model->role = $data['role'] ?? User::ROLE_CLIENT;
        $model->client_id = $data['client_id'] ?? null;
        
        $password = $data['password'] ?? '';
        if (empty($password)) {
            throw new BadRequestHttpException('Password is required');
        }

        if (!$model->validate(['name', 'email', 'role'])) {
            return $model->errors;
        }

        $model->setPassword($password);
        $model->generateAuthKey();

        if (!$model->save()) {
            return $model->errors;
        }

        return [
            'success' => true,
            'user' => [
                'id' => $model->id,
                'name' => $model->name,
                'email' => $model->email,
                'role' => $model->role,
                'client_id' => $model->client_id,
            ],
        ];
    }

    public function actionUpdate($id)
    {
        $currentUser = Yii::$app->user->identity;
        if ($currentUser->role !== User::ROLE_ADMIN) {
            throw new ForbiddenHttpException('Only admins can update users');
        }

        $model = User::findOne($id);
        if (!$model) {
            throw new \yii\web\NotFoundHttpException('User not found');
        }

        // Поддержка как POST, так и PATCH
        $data = Yii::$app->request->post();
        if (empty($data)) {
            $data = Yii::$app->request->getBodyParams();
        }
        
        if (isset($data['name'])) {
            $model->name = $data['name'];
        }
        if (isset($data['email'])) {
            $model->email = $data['email'];
        }
        if (isset($data['role'])) {
            $model->role = $data['role'];
        }
        if (isset($data['client_id'])) {
            $model->client_id = $data['client_id'] ? (int)$data['client_id'] : null;
        }
        
        if (isset($data['password']) && !empty($data['password'])) {
            $model->setPassword($data['password']);
        }

        if (!$model->save()) {
            Yii::$app->response->statusCode = 422;
            return $model->errors;
        }

        return [
            'success' => true,
            'user' => [
                'id' => $model->id,
                'name' => $model->name,
                'email' => $model->email,
                'role' => $model->role,
                'client_id' => $model->client_id,
            ],
        ];
    }

    /**
     * Удаление пользователя
     * DELETE /user/{id}
     */
    public function actionDelete($id)
    {
        $currentUser = Yii::$app->user->identity;
        if ($currentUser->role !== User::ROLE_ADMIN) {
            throw new ForbiddenHttpException('Only admins can delete users');
        }

        $model = User::findOne($id);
        if (!$model) {
            throw new \yii\web\NotFoundHttpException('User not found');
        }

        if ($model->id === $currentUser->id) {
            throw new \yii\web\BadRequestHttpException('Cannot delete yourself');
        }

        if ($model->delete()) {
            Yii::$app->response->statusCode = 204;
            return null;
        }

        throw new \yii\web\ServerErrorHttpException('Failed to delete user');
    }
}


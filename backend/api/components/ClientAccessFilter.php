<?php

namespace api\components;

use common\models\User;
use Yii;
use yii\base\ActionFilter;
use yii\web\ForbiddenHttpException;

class ClientAccessFilter extends ActionFilter
{
    public function beforeAction($action)
    {
        $user = Yii::$app->user->identity;
        
        if (!$user) {
            return parent::beforeAction($action);
        }

        // Админ имеет доступ ко всем данным
        if ($user->role === User::ROLE_ADMIN) {
            return parent::beforeAction($action);
        }

        // Для клиентов и менеджеров применяем фильтрацию
        if (in_array($user->role, [User::ROLE_CLIENT, User::ROLE_MANAGER])) {
            // Фильтрация будет применяться в prepareDataProvider
            return parent::beforeAction($action);
        }

        return parent::beforeAction($action);
    }
}


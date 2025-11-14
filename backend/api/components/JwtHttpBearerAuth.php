<?php

namespace api\components;

use sizeg\jwt\Jwt;
use Yii;
use yii\filters\auth\HttpBearerAuth;
use yii\web\UnauthorizedHttpException;

class JwtHttpBearerAuth extends HttpBearerAuth
{
    /**
     * @inheritdoc
     */
    public function authenticate($user, $request, $response)
    {
        $authHeader = $request->getHeaders()->get('Authorization');
        if ($authHeader !== null && preg_match('/^Bearer\s+(.*?)$/', $authHeader, $matches)) {
            $tokenString = $matches[1];
            try {
                // Упрощенная валидация токена - просто декодируем и получаем uid
                $parts = explode('.', $tokenString);
                if (count($parts) !== 3) {
                    throw new UnauthorizedHttpException('Invalid token format');
                }
                
                // Декодируем payload (вторая часть токена)
                $payload = json_decode(base64_decode(strtr($parts[1], '-_', '+/')), true);
                if (!$payload || !isset($payload['uid'])) {
                    throw new UnauthorizedHttpException('Token does not contain uid claim');
                }
                
                $uid = $payload['uid'];
                
                // Проверяем срок действия токена
                if (isset($payload['exp']) && $payload['exp'] < time()) {
                    throw new UnauthorizedHttpException('Token expired');
                }
                
                // Находим пользователя по ID
                $identity = \common\models\User::findIdentity($uid);
                if ($identity === null) {
                    Yii::error("User not found for uid: {$uid}");
                    $this->challenge($response);
                    $this->handleFailure($response);
                    return null;
                }
                
                // Устанавливаем пользователя в Yii::$app->user
                Yii::$app->user->setIdentity($identity);
                Yii::info("User authenticated: {$identity->id}, client_id: {$identity->client_id}, role: {$identity->role}");
                return $identity;
            } catch (\Exception $e) {
                Yii::error("JWT authentication error: " . $e->getMessage());
                throw new UnauthorizedHttpException('Invalid token: ' . $e->getMessage());
            }
        }

        return null;
    }
}


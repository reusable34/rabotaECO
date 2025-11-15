<?php

namespace api\controllers;

use common\models\User;
use sizeg\jwt\Jwt;
use Yii;
use yii\rest\Controller;
use yii\web\BadRequestHttpException;
use yii\web\UnauthorizedHttpException;

class AuthController extends Controller
{
    public function behaviors()
    {
        $behaviors = parent::behaviors();
        
        // Для actionMe нужна авторизация
        $behaviors['authenticator'] = [
            'class' => \api\components\JwtHttpBearerAuth::class,
            'except' => ['login', 'register', 'options'],
        ];
        
        // CORS обрабатывается глобально через CorsFilter в main.php
        // Не нужно дублировать здесь
        
        return $behaviors;
    }
    
    public function actionOptions()
    {
        return '';
    }

    /**
     * @return array
     * @throws BadRequestHttpException
     */
    public function actionLogin()
    {
        $email = Yii::$app->request->post('email');
        $password = Yii::$app->request->post('password');

        if (!$email || !$password) {
            throw new BadRequestHttpException('Email and password are required');
        }

        $user = User::findByEmail($email);
        if (!$user || !$user->validatePassword($password)) {
            throw new UnauthorizedHttpException('Invalid credentials');
        }

        /** @var Jwt $jwt */
        $jwt = Yii::$app->jwt;
        $signer = $jwt->getSigner('HS256');
        $key = $jwt->getKey();
        $now = new \DateTimeImmutable();

        $token = $jwt->getBuilder()
            ->issuedBy(getenv('BACKEND_URL') ?: 'http://localhost:8080')
            ->permittedFor(getenv('BACKEND_URL') ?: 'http://localhost:8080')
            ->identifiedBy('eco-client-cabinet-' . $user->id, false)
            ->issuedAt($now)
            ->expiresAt($now->modify('+24 hours'))
            ->withClaim('uid', $user->id)
            ->getToken($signer, $key);

        return [
            'token' => $token->toString(),
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
                'client_id' => $user->client_id,
            ],
        ];
    }

    /**
     * @return array
     * @throws BadRequestHttpException
     */
    public function actionRegister()
    {
        $data = Yii::$app->request->post();
        
        // Проверяем обязательные поля
        if (empty($data['name'])) {
            Yii::$app->response->statusCode = 422;
            return ['message' => 'Имя обязательно для заполнения', 'name' => ['Имя обязательно для заполнения']];
        }
        
        if (empty($data['email'])) {
            Yii::$app->response->statusCode = 422;
            return ['message' => 'Email обязателен для заполнения', 'email' => ['Email обязателен для заполнения']];
        }
        
        if (empty($data['password'])) {
            Yii::$app->response->statusCode = 422;
            return ['message' => 'Пароль обязателен для заполнения', 'password' => ['Пароль обязателен для заполнения']];
        }
        
        // Проверяем длину пароля
        if (strlen($data['password']) < 6) {
            Yii::$app->response->statusCode = 422;
            return ['message' => 'Пароль должен быть не менее 6 символов', 'password' => ['Пароль должен быть не менее 6 символов']];
        }
        
        // Проверяем, не существует ли уже пользователь с таким email
        $existingUser = User::findByEmail($data['email']);
        if ($existingUser) {
            Yii::$app->response->statusCode = 422;
            return ['message' => 'Пользователь с таким email уже зарегистрирован', 'email' => ['Пользователь с таким email уже зарегистрирован']];
        }
        
        $user = new User();
        $user->name = trim($data['name']);
        $user->email = trim(strtolower($data['email']));
        $password = $data['password'];

        // Валидация модели
        if (!$user->validate(['name', 'email'])) {
            Yii::$app->response->statusCode = 422;
            $errors = $user->errors;
            // Форматируем ошибки для фронтенда
            $message = 'Ошибка валидации данных';
            if (isset($errors['email'])) {
                $message = is_array($errors['email']) ? $errors['email'][0] : $errors['email'];
            } elseif (isset($errors['name'])) {
                $message = is_array($errors['name']) ? $errors['name'][0] : $errors['name'];
            }
            return ['message' => $message, ...$errors];
        }

        $user->setPassword($password);
        $user->generateAuthKey();
        $user->role = User::ROLE_CLIENT;

        if (!$user->save()) {
            Yii::$app->response->statusCode = 500;
            Yii::error("Failed to create user: " . json_encode($user->errors));
            return ['message' => 'Ошибка при создании пользователя. Попробуйте позже.'];
        }

        Yii::info("User registered successfully: ID={$user->id}, email={$user->email}");

        return [
            'success' => true,
            'message' => 'Регистрация успешна',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => $user->role,
            ],
        ];
    }

    /**
     * Получить текущего пользователя
     * @return array
     */
    public function actionMe()
    {
        $user = Yii::$app->user->identity;
        if (!$user) {
            throw new UnauthorizedHttpException('Not authenticated');
        }

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'client_id' => $user->client_id,
        ];
    }
}


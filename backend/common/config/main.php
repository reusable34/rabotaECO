<?php

return [
    'id' => 'eco-client-cabinet',
    'basePath' => dirname(__DIR__),
    'bootstrap' => ['log'],
    'aliases' => [
        '@bower' => '@vendor/bower-asset',
        '@npm' => '@vendor/npm-asset',
    ],
    'components' => [
        'cache' => [
            'class' => 'yii\caching\FileCache',
        ],
        'log' => [
            'traceLevel' => YII_DEBUG ? 3 : 0,
            'targets' => [
                [
                    'class' => 'yii\log\FileTarget',
                    'levels' => ['error', 'warning'],
                ],
            ],
        ],
        'db' => [
            'class' => 'yii\db\Connection',
            'dsn' => 'pgsql:host=' . (getenv('DB_HOST') ?: 'localhost') . ';dbname=' . (getenv('DB_NAME') ?: 'eco_client'),
            'username' => getenv('DB_USER') ?: 'eco_admin',
            'password' => getenv('DB_PASSWORD') ?: 'eco_pass',
            'charset' => 'utf8',
        ],
        'jwt' => [
            'class' => 'sizeg\jwt\Jwt',
            'key' => getenv('JWT_SECRET') ?: 'supersecretkey',
            'jwtValidationData' => 'common\components\JwtValidationData',
        ],
    ],
];


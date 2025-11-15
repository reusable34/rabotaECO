<?php

$params = array_merge(
    require __DIR__ . '/../../common/config/params.php',
    require __DIR__ . '/params.php'
);

return [
    'id' => 'eco-api',
    'basePath' => dirname(__DIR__),
    'bootstrap' => ['log'],
    'controllerNamespace' => 'api\controllers',
    'as cors' => [
        'class' => 'api\components\CorsFilter',
    ],
    'components' => [
        'request' => [
            'parsers' => [
                'application/json' => 'yii\web\JsonParser',
            ],
            'enableCsrfValidation' => false,
            'cookieValidationKey' => getenv('COOKIE_VALIDATION_KEY') ?: 'eco-api-cookie-key-' . md5(__DIR__),
        ],
        'response' => [
            'format' => yii\web\Response::FORMAT_JSON,
            'charset' => 'UTF-8',
        ],
        'user' => [
            'identityClass' => 'common\models\User',
            'enableAutoLogin' => false,
            'enableSession' => false,
            'loginUrl' => null,
        ],
        'log' => [
            'traceLevel' => YII_DEBUG ? 3 : 0,
            'targets' => [
                [
                    'class' => 'yii\log\FileTarget',
                    'levels' => ['error', 'warning', 'info'],
                    'logFile' => '@runtime/logs/app.log',
                ],
            ],
        ],
        'jwt' => [
            'class' => 'sizeg\jwt\Jwt',
            'key' => getenv('JWT_SECRET') ?: 'supersecretkey',
            'jwtValidationData' => 'common\components\JwtValidationData',
        ],
        'urlManager' => [
            'enablePrettyUrl' => true,
            'enableStrictParsing' => false,
            'showScriptName' => false,
            'rules' => [
                'GET health' => 'health/index',
                'OPTIONS health' => 'health/options',
                'POST auth/login' => 'auth/login',
                'POST auth/register' => 'auth/register',
                'GET auth/me' => 'auth/me',
                'OPTIONS <action>' => 'auth/options',
                // Явные маршруты для кастомных действий (перед REST правилами для приоритета)
                'GET requirement/<id:\d+>/risks' => 'requirement/risks',
                'OPTIONS requirement/<id:\d+>/risks' => 'requirement/options',
                'POST document/upload' => 'document/upload',
                'OPTIONS document/upload' => 'document/options',
                'GET document/<id:\d+>/download' => 'document/download',
                'OPTIONS document/<id:\d+>/download' => 'document/options',
                [
                    'class' => 'yii\rest\UrlRule',
                    'controller' => 'client',
                    'pluralize' => false,
                ],
                [
                    'class' => 'yii\rest\UrlRule',
                    'controller' => 'requirement',
                    'pluralize' => false,
                    'extraPatterns' => [
                        'GET {id}/risks' => 'risks',
                        'OPTIONS {id}/risks' => 'options',
                        'POST recalculate' => 'recalculate',
                        'OPTIONS recalculate' => 'options',
                    ],
                    'tokens' => [
                        '{id}' => '<id:\\d+>',
                    ],
                ],
                [
                    'class' => 'yii\rest\UrlRule',
                    'controller' => 'document',
                    'pluralize' => false,
                    'extraPatterns' => [
                        'POST upload' => 'upload',
                        'OPTIONS upload' => 'options',
                        'GET {id}/download' => 'download',
                        'OPTIONS {id}/download' => 'options',
                    ],
                    'tokens' => [
                        '{id}' => '<id:\\d+>',
                    ],
                ],
                [
                    'class' => 'yii\rest\UrlRule',
                    'controller' => 'contract',
                ],
                [
                    'class' => 'yii\rest\UrlRule',
                    'controller' => 'event',
                    'pluralize' => false,
                ],
                [
                    'class' => 'yii\rest\UrlRule',
                    'controller' => 'category',
                ],
                [
                    'class' => 'yii\rest\UrlRule',
                    'controller' => 'risk',
                ],
                [
                    'class' => 'yii\rest\UrlRule',
                    'controller' => 'user',
                    'pluralize' => false,
                    'extraPatterns' => [
                        'POST create' => 'create',
                        'PATCH {id}' => 'update',
                        'PUT {id}' => 'update',
                        'POST {id}' => 'update', // Добавляем POST для надежности
                        'DELETE {id}' => 'delete',
                    ],
                    'tokens' => [
                        '{id}' => '<id:\\d+>',
                    ],
                ],
                // Явный маршрут для обновления пользователя (на случай проблем с REST)
                'PUT user/<id:\d+>' => 'user/update',
                'PATCH user/<id:\d+>' => 'user/update',
                'POST user/<id:\d+>/update' => 'user/update',
                [
                    'class' => 'yii\rest\UrlRule',
                    'controller' => 'npa',
                    'pluralize' => false,
                ],
            ],
        ],
    ],
    'params' => $params,
];


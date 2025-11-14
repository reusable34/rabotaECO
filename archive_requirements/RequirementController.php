<?php

namespace api\controllers;

use common\models\Requirement;
use common\models\Risk;
use common\models\User;
use common\models\Client;
use common\services\RequirementGeneratorService;
use Yii;
use api\components\JwtHttpBearerAuth;
use yii\filters\AccessControl;
use yii\rest\ActiveController;

class RequirementController extends ActiveController
{
    public $modelClass = 'common\models\Requirement';

    public function behaviors()
    {
        $behaviors = parent::behaviors();
        
        // CORS настройки
        $behaviors['cors'] = [
            'class' => \yii\filters\Cors::class,
            'cors' => [
                'Origin' => ['http://localhost:3000'],
                'Access-Control-Request-Method' => ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
                'Access-Control-Request-Headers' => ['Authorization', 'Content-Type'],
                'Access-Control-Allow-Credentials' => true,
                'Access-Control-Max-Age' => 3600,
            ],
        ];
        
        $behaviors['authenticator'] = [
            'class' => JwtHttpBearerAuth::class,
            'except' => ['options'],
        ];
        
        $behaviors['access'] = [
            'class' => AccessControl::class,
            'rules' => [
                [
                    'allow' => true,
                    'roles' => ['@'],
                ],
                [
                    'allow' => true,
                    'actions' => ['options'],
                ],
            ],
        ];
        
        return $behaviors;
    }
    
    /**
     * Обработка preflight OPTIONS запросов
     */
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
            
            if (!$user) {
                Yii::error('User identity is null in RequirementController');
                return new \yii\data\ActiveDataProvider([
                    'query' => Requirement::find()->where('1=0'), // Пустой результат
                ]);
            }
            
            Yii::info("RequirementController: User ID={$user->id}, client_id={$user->client_id}, role={$user->role}");
            
            // Получаем client_id из query параметров (если передан)
            $request = Yii::$app->request;
            $filterClientId = $request->get('client_id');
            
            // Админ видит все требования, но может фильтровать по client_id
            if ($user->role === User::ROLE_ADMIN) {
                $query = Requirement::find();
                if ($filterClientId) {
                    $query->where(['client_id' => $filterClientId]);
                }
                return new \yii\data\ActiveDataProvider([
                    'query' => $query,
                ]);
            }

            // Клиенты и менеджеры видят только требования своих клиентов
            if ($user->client_id) {
                $query = Requirement::find()->where(['client_id' => $user->client_id]);
                $count = $query->count();
                Yii::info("Filtering requirements for client_id: {$user->client_id}, found: {$count}");
                return new \yii\data\ActiveDataProvider([
                    'query' => $query,
                ]);
            }

            Yii::warning("User {$user->id} has no client_id");
            return new \yii\data\ActiveDataProvider([
                'query' => Requirement::find()->where('1=0'), // Пустой результат
            ]);
        };
        
        // Отключаем стандартный create, используем свой
        unset($actions['create']);
        
        // Настраиваем стандартные update и delete с проверкой прав
        $actions['update']['checkAccess'] = function($action, $model = null, $params = []) {
            $user = Yii::$app->user->identity;
            if (!$user) {
                throw new \yii\web\UnauthorizedHttpException('Not authenticated');
            }
            // Админ может обновлять все, остальные - только свои
            if ($user->role === User::ROLE_ADMIN) {
                return true;
            }
            if ($model && $model->client_id === $user->client_id) {
                return true;
            }
            throw new \yii\web\ForbiddenHttpException('Access denied');
        };
        
        $actions['delete']['checkAccess'] = function($action, $model = null, $params = []) {
            $user = Yii::$app->user->identity;
            if (!$user) {
                throw new \yii\web\UnauthorizedHttpException('Not authenticated');
            }
            // Только админ может удалять
            if ($user->role !== User::ROLE_ADMIN) {
                throw new \yii\web\ForbiddenHttpException('Only admins can delete requirements');
            }
            return true;
        };
        
        return $actions;
    }

    /**
     * Создание нового требования
     * POST /requirement
     */
    public function actionCreate()
    {
        $user = Yii::$app->user->identity;
        if (!$user) {
            throw new \yii\web\UnauthorizedHttpException('Not authenticated');
        }
        
        $request = Yii::$app->request;
        $model = new Requirement();
        $model->load($request->post(), '');
        
        // Проверка прав доступа
        if ($user->role === User::ROLE_ADMIN) {
            // Админ может создавать требования для любого клиента
        } elseif ($user->role === User::ROLE_MANAGER) {
            // Менеджер может создавать требования только для своего клиента
            if ($model->client_id && $model->client_id !== $user->client_id) {
                throw new \yii\web\ForbiddenHttpException('You can only create requirements for your client');
            }
            if (!$model->client_id) {
                $model->client_id = $user->client_id;
            }
        } else {
            // Клиент может создавать требования только для себя
            if (!$model->client_id) {
                $model->client_id = $user->client_id;
            } elseif ($model->client_id !== $user->client_id) {
                throw new \yii\web\ForbiddenHttpException('You can only create requirements for your client');
            }
        }
        
        if ($model->save()) {
            return $model;
        }
        
        Yii::$app->response->statusCode = 422;
        return $model->errors;
    }

    public function actionRisks($id)
    {
        $requirement = Requirement::findOne($id);
        if (!$requirement) {
            throw new \yii\web\NotFoundHttpException('Requirement not found');
        }

        // Проверка доступа
        $user = Yii::$app->user->identity;
        if ($user->role !== User::ROLE_ADMIN && $requirement->client_id !== $user->client_id) {
            throw new \yii\web\ForbiddenHttpException('Access denied');
        }

        return Risk::findAll(['requirement_id' => $id]);
    }

    /**
     * Пересчет требований на основе параметров клиента
     * POST /requirement/recalculate
     */
    public function actionRecalculate()
    {
        $user = Yii::$app->user->identity;
        $request = Yii::$app->request;
        
        // Получаем параметры из запроса
        $categoryId = $request->post('category_id');
        $hasWell = $request->post('has_well', false);
        $hasRiver = $request->post('has_river', false);
        $hasByproduct = $request->post('has_byproduct', false);
        $responsiblePerson = $request->post('responsible_person');
        
        // Определяем клиента
        $client = null;
        if ($user->role === User::ROLE_ADMIN) {
            $clientId = $request->post('client_id');
            if (!$clientId) {
                throw new \yii\web\BadRequestHttpException('client_id is required for admin');
            }
            $client = Client::findOne($clientId);
        } else {
            // Для клиента используем client_id из запроса, если передан, иначе из user
            $clientId = $request->post('client_id');
            if ($clientId) {
                // Проверяем, что клиент может работать только со своим client_id
                if ($clientId != $user->client_id) {
                    throw new \yii\web\ForbiddenHttpException('You can only recalculate requirements for your client');
                }
                $client = Client::findOne($clientId);
            } else {
                $client = Client::findOne($user->client_id);
            }
        }
        
        if (!$client) {
            throw new \yii\web\NotFoundHttpException('Client not found');
        }
        
        // Обновляем параметры клиента ПЕРЕД генерацией требований
        // Важно: обновляем ВСЕ параметры, даже если они не изменились, чтобы гарантировать правильную генерацию
        if ($categoryId !== null) {
            $client->category_id = (int)$categoryId;
        }
        // Явно устанавливаем булевы значения - если не передано, значит false
        $client->has_well = $request->post('has_well') === true || $request->post('has_well') === 'true' || $request->post('has_well') === 1 || $request->post('has_well') === '1';
        $client->has_river = $request->post('has_river') === true || $request->post('has_river') === 'true' || $request->post('has_river') === 1 || $request->post('has_river') === '1';
        $client->has_byproduct = $request->post('has_byproduct') === true || $request->post('has_byproduct') === 'true' || $request->post('has_byproduct') === 1 || $request->post('has_byproduct') === '1';
        
        if ($responsiblePerson !== null) {
            $client->responsible_person = $responsiblePerson;
        }
        
        // Сохраняем параметры клиента
        if (!$client->save()) {
            Yii::$app->response->statusCode = 422;
            return ['success' => false, 'errors' => $client->errors];
        }
        
        Yii::info("Updated client params: category_id={$client->category_id}, has_well=" . ($client->has_well ? 'true' : 'false') . ", has_river=" . ($client->has_river ? 'true' : 'false') . ", has_byproduct=" . ($client->has_byproduct ? 'true' : 'false'));
        
        // Удаляем старые требования (с транзакцией для надежности)
        $transaction = Yii::$app->db->beginTransaction();
        try {
            // Удаляем ВСЕ требования для этого клиента, включая связанные риски
            // Используем прямой SQL запрос для гарантированного удаления
            $clientId = $client->id;
            
            // Сначала удаляем все риски для требований этого клиента
            $riskDeleteQuery = "DELETE FROM risks WHERE requirement_id IN (SELECT id FROM requirements WHERE client_id = :client_id)";
            $riskDeleted = Yii::$app->db->createCommand($riskDeleteQuery, [':client_id' => $clientId])->execute();
            Yii::info("Deleted {$riskDeleted} risks for client_id={$clientId}");
            
            // Затем удаляем все требования - ВАЖНО: используем прямой DELETE без проверок
            $reqDeleteQuery = "DELETE FROM requirements WHERE client_id = :client_id";
            $deletedCount = Yii::$app->db->createCommand($reqDeleteQuery, [':client_id' => $clientId])->execute();
            
            // Проверяем, что все требования действительно удалены
            $remainingCount = Requirement::find()->where(['client_id' => $clientId])->count();
            if ($remainingCount > 0) {
                Yii::warning("WARNING: After deletion, {$remainingCount} requirements still exist for client_id={$clientId}. Force deleting...");
                // Принудительно удаляем оставшиеся
                Requirement::deleteAll(['client_id' => $clientId]);
            }
            
            Yii::info("Deleted {$deletedCount} old requirements for client_id={$clientId}, category_id={$client->category_id}, has_well=" . ($client->has_well ? 'true' : 'false') . ", has_river=" . ($client->has_river ? 'true' : 'false') . ", has_byproduct=" . ($client->has_byproduct ? 'true' : 'false'));
            
            // Генерируем новые требования
            $requirements = RequirementGeneratorService::generateRequirements($client);
            Yii::info("Generated " . count($requirements) . " new requirements for client_id={$clientId}, category_id={$client->category_id}");
            
            // Проверяем, что созданы только правильные требования
            $actualRequirements = Requirement::findAll(['client_id' => $clientId]);
            Yii::info("Actual requirements count in DB after generation: " . count($actualRequirements));
            
            // Если создано больше требований, чем должно быть для IV категории - это ошибка
            if ($client->category_id == 4 && count($actualRequirements) > 9) {
                Yii::warning("WARNING: For category IV, expected max 9 requirements (8 base + 1 for well), but got " . count($actualRequirements));
            }
            
            foreach ($actualRequirements as $req) {
                Yii::info("  - Requirement ID {$req->id}: {$req->title}");
            }
            
            $transaction->commit();
        } catch (\Exception $e) {
            $transaction->rollBack();
            Yii::error("Error recalculating requirements: " . $e->getMessage());
            throw $e;
        }
        
        // Обновляем ответственного для всех требований
        if ($responsiblePerson) {
            Requirement::updateAll(
                ['responsible_person' => $responsiblePerson],
                ['client_id' => $client->id]
            );
        }
        
        return [
            'success' => true,
            'client' => $client,
            'requirements_count' => count($requirements),
        ];
    }

}

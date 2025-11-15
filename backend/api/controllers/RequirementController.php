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
        
        // CORS обрабатывается глобально через CorsFilter в main.php
        // Не нужно дублировать здесь
        
        $behaviors['authenticator'] = [
            'class' => JwtHttpBearerAuth::class,
            'except' => ['options'],
        ];
        
        // Добавляем кастомный action для risks
        $behaviors['verbFilter']['actions'] = [
            'risks' => ['GET', 'OPTIONS'],
        ];
        
        // Для OPTIONS запросов к risks не требуется аутентификация
        // (обрабатывается через actionOptions)
        
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
        
        // Регистрируем кастомный action для risks через InlineAction
        // Это нужно для того, чтобы Yii2 REST мог найти метод actionRisks через extraPatterns
        $actions['risks'] = [
            'class' => 'yii\base\InlineAction',
            'controller' => $this,
            'actionMethod' => 'actionRisks',
        ];
        
        // Переопределяем actionIndex для фильтрации по client_id
        $actions['index']['prepareDataProvider'] = function() {
            $user = Yii::$app->user->identity;
            
            if (!$user) {
                Yii::error('User identity is null in RequirementController');
                return new \yii\data\ActiveDataProvider([
                    'query' => Requirement::find()->where('1=0'), // Пустой результат
                    'pagination' => false,
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
                $count = $query->count();
                Yii::info("API: Admin requesting requirements" . ($filterClientId ? " for client_id={$filterClientId}" : "") . ", found: {$count}");
                if ($filterClientId) {
                    // Логируем все требования для этого клиента
                    $allReqs = $query->all();
                    Yii::info("API: Requirements for client_id={$filterClientId}:");
                    foreach ($allReqs as $req) {
                        Yii::info("  - ID {$req->id}: {$req->title}");
                    }
                }
                return new \yii\data\ActiveDataProvider([
                    'query' => $query,
                    'pagination' => false, // ОТКЛЮЧАЕМ ПАГИНАЦИЮ - нужны ВСЕ требования
                ]);
            }

            // Клиенты и менеджеры видят только требования своих клиентов
            if ($user->client_id) {
                $query = Requirement::find()->where(['client_id' => $user->client_id]);
                $count = $query->count();
                Yii::info("API: Filtering requirements for client_id: {$user->client_id}, found: {$count}");
                // Логируем все требования
                $allReqs = $query->all();
                Yii::info("API: Requirements for client_id={$user->client_id}:");
                foreach ($allReqs as $req) {
                    Yii::info("  - ID {$req->id}: {$req->title}");
                }
                return new \yii\data\ActiveDataProvider([
                    'query' => $query,
                    'pagination' => false, // ОТКЛЮЧАЕМ ПАГИНАЦИЮ - нужны ВСЕ требования
                ]);
            }

            Yii::warning("User {$user->id} has no client_id");
            return new \yii\data\ActiveDataProvider([
                'query' => Requirement::find()->where('1=0'), // Пустой результат
                'pagination' => false,
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
            // Автоматически создаем риски на основе статей КоАП из basis (как в RequirementGeneratorService)
            RequirementGeneratorService::createRisksForRequirement($model, $model->basis);
            return $model;
        }
        
        Yii::$app->response->statusCode = 422;
        return $model->errors;
    }

    public function actionRisks($id)
    {
        // КРИТИЧЕСКИЙ ЛОГ для отладки
        Yii::error("=== actionRisks CALLED with id={$id} ===");
        Yii::error("Request URI: " . Yii::$app->request->url);
        Yii::error("Request Method: " . Yii::$app->request->method);
        
        Yii::$app->response->format = \yii\web\Response::FORMAT_JSON;
        
        try {
            Yii::info("actionRisks called with id={$id}");
            
            $requirement = Requirement::findOne($id);
            if (!$requirement) {
                Yii::warning("Requirement with id={$id} not found");
                // Возвращаем пустой массив вместо исключения, чтобы фронтенд не падал
                return [];
            }

            // Проверка доступа
            $user = Yii::$app->user->identity;
            if (!$user) {
                Yii::warning('User not authenticated in actionRisks');
                return [];
            }
            
            if ($user->role !== User::ROLE_ADMIN && $requirement->client_id !== $user->client_id) {
                Yii::warning("Access denied: user client_id={$user->client_id}, requirement client_id={$requirement->client_id}");
                // Возвращаем пустой массив вместо исключения
                return [];
            }

            $risks = Risk::findAll(['requirement_id' => $id]);
            Yii::info("Found " . count($risks) . " risks for requirement id={$id}");
            return $risks ?: []; // Гарантируем, что возвращаем массив
        } catch (\Exception $e) {
            Yii::error('Error loading risks: ' . $e->getMessage() . "\n" . $e->getTraceAsString());
            return []; // Возвращаем пустой массив при любой ошибке
        }
    }

    /**
     * Пересчет требований на основе параметров клиента
     * POST /requirement/recalculate
     */
    public function actionRecalculate()
    {
        $user = Yii::$app->user->identity;
        $request = Yii::$app->request;
        
        // Только админ и менеджер могут пересчитывать требования
        if ($user->role !== User::ROLE_ADMIN && $user->role !== User::ROLE_MANAGER) {
            throw new \yii\web\ForbiddenHttpException('Только администратор и менеджер могут пересчитывать требования');
        }
        
        // Получаем параметры из запроса
        $categoryId = $request->post('category_id');
        $hasWell = $request->post('has_well', false);
        $hasRiver = $request->post('has_river', false);
        $hasByproduct = $request->post('has_byproduct', false);
        $responsiblePerson = $request->post('responsible_person');
        
        // Определяем клиента
        $client = null;
        if ($user->role === User::ROLE_ADMIN) {
            // Админ может пересчитывать для любого клиента
            $clientId = $request->post('client_id');
            if (!$clientId) {
                Yii::error("CRITICAL: Admin tried to recalculate without client_id");
                throw new \yii\web\BadRequestHttpException('client_id is required for admin');
            }
            $client = Client::findOne($clientId);
            if (!$client) {
                Yii::error("CRITICAL: Admin tried to recalculate for non-existent client_id={$clientId}");
                throw new \yii\web\NotFoundHttpException("Client with id={$clientId} not found");
            }
            Yii::info("=== RECALCULATE: Admin recalculating for client_id={$clientId}, client_name={$client->name} ===");
        } else {
            // Менеджер может пересчитывать только для своих клиентов
            $clientId = $request->post('client_id');
            if ($clientId) {
                // Проверяем, что менеджер может работать только со своим client_id
                if ($clientId != $user->client_id) {
                    throw new \yii\web\ForbiddenHttpException('Менеджер может пересчитывать требования только для своих клиентов');
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
        
        // Явно устанавливаем булевы значения
        // ВСЕГДА устанавливаем значения явно, даже если они не переданы
        // Это критически важно для правильной генерации требований
        $hasWellParam = $request->post('has_well');
        $client->has_well = ($hasWellParam === true || $hasWellParam === 'true' || $hasWellParam === 1 || $hasWellParam === '1') ? true : false;
        
        $hasRiverParam = $request->post('has_river');
        $client->has_river = ($hasRiverParam === true || $hasRiverParam === 'true' || $hasRiverParam === 1 || $hasRiverParam === '1') ? true : false;
        
        $hasByproductParam = $request->post('has_byproduct');
        $client->has_byproduct = ($hasByproductParam === true || $hasByproductParam === 'true' || $hasByproductParam === 1 || $hasByproductParam === '1') ? true : false;
        
        if ($responsiblePerson !== null) {
            $client->responsible_person = $responsiblePerson;
        }
        
        // Сохраняем параметры клиента
        if (!$client->save()) {
            Yii::$app->response->statusCode = 422;
            return ['success' => false, 'errors' => $client->errors];
        }
        
        // КРИТИЧЕСКИ ВАЖНО: Перезагружаем клиента из БД, чтобы убедиться, что параметры действительно обновились
        $client->refresh();
        
        Yii::info("Updated client params: category_id={$client->category_id}, has_well=" . ($client->has_well ? 'true' : 'false') . ", has_river=" . ($client->has_river ? 'true' : 'false') . ", has_byproduct=" . ($client->has_byproduct ? 'true' : 'false'));
        Yii::info("Client data from DB after refresh: " . json_encode([
            'id' => $client->id,
            'category_id' => $client->category_id,
            'has_well' => $client->has_well,
            'has_river' => $client->has_river,
            'has_byproduct' => $client->has_byproduct,
        ]));
        
        // Удаляем старые требования (с транзакцией для надежности)
        $transaction = Yii::$app->db->beginTransaction();
        try {
            // Удаляем ВСЕ требования для этого клиента, включая связанные риски
            // Используем прямой SQL запрос для гарантированного удаления
            $clientId = $client->id;
            
            // КРИТИЧЕСКАЯ ПРОВЕРКА: Убеждаемся, что client_id правильный
            Yii::info("=== RECALCULATE: Starting for client_id={$clientId}, category_id={$client->category_id}, client_name={$client->name} ===");
            Yii::info("=== RECALCULATE: User role={$user->role}, user_id={$user->id} ===");
            
            // Проверяем, сколько требований существует ДО удаления
            $beforeDeleteCount = Requirement::find()->where(['client_id' => $clientId])->count();
            Yii::info("=== RECALCULATE: Found {$beforeDeleteCount} existing requirements for client_id={$clientId} BEFORE deletion ===");
            
            // Сначала удаляем все риски для требований этого клиента
            $riskDeleteQuery = "DELETE FROM risks WHERE requirement_id IN (SELECT id FROM requirements WHERE client_id = :client_id)";
            $riskDeleted = Yii::$app->db->createCommand($riskDeleteQuery, [':client_id' => $clientId])->execute();
            Yii::info("Deleted {$riskDeleted} risks for client_id={$clientId}");
            
            // Затем удаляем все требования - ВАЖНО: используем прямой DELETE без проверок
            $reqDeleteQuery = "DELETE FROM requirements WHERE client_id = :client_id";
            $deletedCount = Yii::$app->db->createCommand($reqDeleteQuery, [':client_id' => $clientId])->execute();
            
            // Проверяем, что все требования действительно удалены - ПРИНУДИТЕЛЬНО
            $remainingCount = Requirement::find()->where(['client_id' => $clientId])->count();
            if ($remainingCount > 0) {
                Yii::warning("WARNING: After deletion, {$remainingCount} requirements still exist for client_id={$clientId}. Force deleting...");
                // Принудительно удаляем оставшиеся несколько раз
                for ($i = 0; $i < 3; $i++) {
                    Requirement::deleteAll(['client_id' => $clientId]);
                    $remainingCount = Requirement::find()->where(['client_id' => $clientId])->count();
                    if ($remainingCount == 0) {
                        break;
                    }
                    Yii::warning("Attempt {$i}: {$remainingCount} requirements still remain");
                }
                
                // Последняя попытка - прямой SQL
                if ($remainingCount > 0) {
                    Yii::warning("Final attempt: Using direct SQL DELETE");
                    Yii::$app->db->createCommand("DELETE FROM requirements WHERE client_id = :client_id", [':client_id' => $clientId])->execute();
                    $remainingCount = Requirement::find()->where(['client_id' => $clientId])->count();
                }
                
                if ($remainingCount > 0) {
                    throw new \Exception("CRITICAL: Failed to delete all old requirements. {$remainingCount} still remain after all attempts.");
                }
            }
            
            Yii::info("Deleted {$deletedCount} old requirements for client_id={$clientId}, category_id={$client->category_id}, has_well=" . ($client->has_well ? 'true' : 'false') . ", has_river=" . ($client->has_river ? 'true' : 'false') . ", has_byproduct=" . ($client->has_byproduct ? 'true' : 'false'));
            Yii::info("Confirmed: 0 requirements remain after deletion");
            
            // Дополнительная проверка - убеждаемся что БД пуста
            $finalCheck = Requirement::find()->where(['client_id' => $clientId])->count();
            if ($finalCheck > 0) {
                throw new \Exception("CRITICAL: Database still contains {$finalCheck} requirements after deletion!");
            }
            
            // Генерируем новые требования
            $requirements = RequirementGeneratorService::generateRequirements($client);
            Yii::info("Generated " . count($requirements) . " new requirements for client_id={$clientId}, category_id={$client->category_id}");
            
            // Проверяем, что созданы только правильные требования
            $actualRequirements = Requirement::findAll(['client_id' => $clientId]);
            Yii::info("Actual requirements count in DB after generation: " . count($actualRequirements));
            
            // Детальная проверка для всех категорий
            $expectedCounts = [
                1 => 18 + ($client->has_well ? 1 : 0) + ($client->has_river ? 2 : 0) + ($client->has_byproduct ? 1 : 0),
                2 => 18 + ($client->has_well ? 1 : 0) + ($client->has_river ? 2 : 0) + ($client->has_byproduct ? 1 : 0),
                3 => 16 + ($client->has_well ? 1 : 0) + ($client->has_river ? 2 : 0) + ($client->has_byproduct ? 1 : 0),
                4 => 8 + ($client->has_well ? 1 : 0) + ($client->has_river ? 2 : 0) + ($client->has_byproduct ? 1 : 0),
            ];
            $expectedCount = $expectedCounts[$client->category_id] ?? 0;
            
            if (count($actualRequirements) !== $expectedCount) {
                Yii::error("ERROR: For category {$client->category_id}, expected {$expectedCount} requirements, but got " . count($actualRequirements));
            } else {
                Yii::info("SUCCESS: Category {$client->category_id} - All {$expectedCount} requirements created correctly!");
            }
            
            Yii::info("Created requirements list:");
            foreach ($actualRequirements as $req) {
                Yii::info("  - ID {$req->id}: {$req->title}");
            }
            
            $transaction->commit();
            Yii::info("=== RECALCULATE: Completed successfully ===");
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

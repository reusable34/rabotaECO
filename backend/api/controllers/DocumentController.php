<?php

namespace api\controllers;

use common\models\Document;
use common\models\User;
use Yii;
use api\components\JwtHttpBearerAuth;
use yii\data\ActiveDataProvider;
use yii\filters\AccessControl;
use yii\rest\ActiveController;
use yii\web\ForbiddenHttpException;
use yii\web\NotFoundHttpException;
use yii\web\UploadedFile;

class DocumentController extends ActiveController
{
    public $modelClass = 'common\models\Document';

    public function behaviors()
    {
        $behaviors = parent::behaviors();
        
        // CORS настройки согласно ТЗ
        $behaviors['cors'] = [
            'class' => \yii\filters\Cors::class,
            'cors' => [
                'Origin' => ['http://localhost:3000'],
                'Access-Control-Request-Method' => ['GET', 'POST', 'OPTIONS'],
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
        unset($actions['create'], $actions['update'], $actions['delete'], $actions['view']);
        return $actions;
    }

    /**
     * Проверка доступа к документу
     * @param Document $document
     * @param User $user
     * @return bool
     */
    private function canAccessDocument($document, $user)
    {
        if ($user->role === User::ROLE_ADMIN) {
            return true;
        }
        
        $userClientId = $user->client_id !== null ? (int)$user->client_id : null;
        $docClientId = (int)$document->client_id;
        
        if ($userClientId === null) {
            return false;
        }
        
        return $docClientId === $userClientId;
    }

    /**
     * Список документов с фильтрацией по ролям
     * admin видит все документы
     * manager/client видят только документы client_id = user->client_id
     */
    public function actionIndex()
    {
        $user = Yii::$app->user->identity;
        
        if (!$user) {
            return new ActiveDataProvider([
                'query' => Document::find()->where('1=0'),
            ]);
        }
        
        // Админ видит все документы
        if ($user->role === User::ROLE_ADMIN) {
            $query = Document::find();
        } else {
            // manager/client видят только документы своего client_id
            $userClientId = $user->client_id !== null ? (int)$user->client_id : null;
            
            if ($userClientId === null) {
                return new ActiveDataProvider([
                    'query' => Document::find()->where('1=0'),
                ]);
            }
            
            // Строгая фильтрация с явным приведением типов
            $query = Document::find()
                ->where(['client_id' => $userClientId])
                ->orderBy(['created_at' => SORT_DESC]);
        }
        
        $dataProvider = new ActiveDataProvider([
            'query' => $query,
            'pagination' => [
                'pageSize' => 100,
            ],
        ]);
        
        return $dataProvider;
    }

    /**
     * Загрузка документа
     * Принимает multipart/form-data
     * Обязательное поле: file
     * client_id берется из user->client_id (клиент не должен указывать вручную)
     * type берется из POST запроса
     * status при создании = pending
     */
    public function actionUpload()
    {
        $user = Yii::$app->user->identity;
        
        // client_id берется из user->client_id
        $clientId = $user->client_id;
        
        if (!$clientId) {
            throw new ForbiddenHttpException('Client ID is required');
        }
        
        // Проверка доступа: клиент не может загружать документы для другого клиента
        if ($user->role !== User::ROLE_ADMIN && $clientId != $user->client_id) {
            throw new ForbiddenHttpException('Access denied');
        }
        
        // Получаем файл из запроса
        $file = UploadedFile::getInstanceByName('file');
        
        if (!$file) {
            Yii::$app->response->statusCode = 400;
            return ['error' => 'File is required'];
        }
        
        // Получаем type из POST запроса
        $type = Yii::$app->request->post('type');
        
        if (!$type) {
            Yii::$app->response->statusCode = 400;
            return ['error' => 'Type is required'];
        }
        
        // Путь сохранения файла: backend/api/storage/clients/{client_id}/{originalName}
        $storagePath = Yii::getAlias('@api/storage/clients/' . $clientId);
        
        if (!is_dir($storagePath)) {
            mkdir($storagePath, 0755, true);
        }
        
        // Используем оригинальное имя файла, но проверяем на конфликты
        $originalName = $file->name;
        $fileName = $originalName;
        $filePath = $storagePath . '/' . $fileName;
        
        // Если файл с таким именем уже существует, добавляем суффикс
        $counter = 1;
        while (file_exists($filePath)) {
            $pathInfo = pathinfo($originalName);
            $extension = isset($pathInfo['extension']) ? '.' . $pathInfo['extension'] : '';
            $nameWithoutExt = isset($pathInfo['extension']) 
                ? substr($originalName, 0, -(strlen($extension))) 
                : $originalName;
            $fileName = $nameWithoutExt . '_' . $counter . $extension;
            $filePath = $storagePath . '/' . $fileName;
            $counter++;
        }
        
        // Сохраняем файл
        if (!$file->saveAs($filePath)) {
            Yii::$app->response->statusCode = 500;
            return ['error' => 'Failed to save file'];
        }
        
        // Создаем запись в БД
        $document = new Document();
        $document->client_id = $clientId;
        // file_path в БД должен хранить строку вида: clients/{client_id}/{filename}
        $document->file_path = 'clients/' . $clientId . '/' . $fileName;
        $document->type = $type;
        $document->status = Document::STATUS_PENDING;
        
        if (!$document->save()) {
            // Удаляем файл, если не удалось сохранить в БД
            if (file_exists($filePath)) {
                unlink($filePath);
            }
            Yii::$app->response->statusCode = 500;
            return ['error' => 'Failed to save document', 'errors' => $document->errors];
        }
        
        return $document;
    }

    /**
     * Скачивание документа
     * ВАЖНО: Никакого вывода до sendFile() - иначе файлы будут повреждены!
     */
    public function actionDownload($id)
    {
        $document = Document::findOne($id);
        if (!$document) {
            throw new NotFoundHttpException('Document not found');
        }
        
        $user = Yii::$app->user->identity;
        if (!$user) {
            throw new ForbiddenHttpException('User not authenticated');
        }
        
        // Проверка прав доступа
        if ($user->role !== User::ROLE_ADMIN && (int)$document->client_id !== (int)$user->client_id) {
            throw new ForbiddenHttpException('Access denied');
        }
        
        // Формируем полный путь: file_path в БД = "clients/{client_id}/{filename}"
        $filePath = $document->file_path;
        if (strpos($filePath, 'storage/') === 0) {
            $filePath = substr($filePath, strlen('storage/'));
        }
        
        if (strpos($filePath, 'clients/') === 0) {
            $fullPath = Yii::getAlias('@api/storage/' . $filePath);
        } else {
            $fullPath = Yii::getAlias('@api/storage/clients/' . (int)$document->client_id . '/' . basename($filePath));
        }
        
        if (!file_exists($fullPath)) {
            throw new NotFoundHttpException('File not found on server');
        }
        
        // КРИТИЧНО: Очищаем все output buffers перед отправкой файла
        Yii::$app->response->clearOutputBuffers();
        Yii::$app->response->format = \yii\web\Response::FORMAT_RAW;
        
        $fileName = basename($fullPath);
        // Убираем префикс uniqid если есть
        if (preg_match('/^[a-f0-9]+(?:\.[0-9]+)?_(.+)$/i', $fileName, $matches)) {
            $fileName = $matches[1];
        }
        
        // Определяем MIME-тип через FileHelper
        $mimeType = \yii\helpers\FileHelper::getMimeType($fullPath);
        if (!$mimeType) {
            $ext = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));
            $mimeTypes = [
                'pdf' => 'application/pdf',
                'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                'doc' => 'application/msword',
                'xls' => 'application/vnd.ms-excel',
                'jpg' => 'image/jpeg',
                'jpeg' => 'image/jpeg',
                'png' => 'image/png',
                'txt' => 'text/plain',
            ];
            $mimeType = $mimeTypes[$ext] ?? 'application/octet-stream';
        }
        
        // sendFile() - единственный способ вернуть файл, без дополнительного вывода
        return Yii::$app->response->sendFile($fullPath, $fileName, [
            'mimeType' => $mimeType,
            'inline' => false
        ]);
    }
}

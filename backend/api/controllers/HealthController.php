<?php

namespace api\controllers;

use Yii;
use yii\rest\Controller;
use yii\web\Response;

class HealthController extends Controller
{
    public function behaviors()
    {
        $behaviors = parent::behaviors();
        // CORS настроен глобально через CorsFilter
        return $behaviors;
    }
    
    public function actionIndex()
    {
        Yii::$app->response->format = Response::FORMAT_JSON;
        
        $status = [
            'status' => 'ok',
            'timestamp' => date('c'),
            'service' => 'eco-backend-api',
        ];
        
        // Проверка подключения к БД
        try {
            $db = Yii::$app->db;
            $db->createCommand('SELECT 1')->execute();
            $status['database'] = 'connected';
        } catch (\Exception $e) {
            $status['status'] = 'error';
            $status['database'] = 'disconnected';
            $status['error'] = $e->getMessage();
            Yii::$app->response->statusCode = 503;
        }
        
        return $status;
    }
    
    public function actionOptions()
    {
        Yii::$app->response->statusCode = 200;
        Yii::$app->response->format = Response::FORMAT_RAW;
        return '';
    }
}


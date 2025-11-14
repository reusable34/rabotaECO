<?php

namespace console\controllers;

use common\models\Client;
use common\models\Document;
use common\models\User;
use Yii;
use yii\console\Controller;

class CheckDocumentsController extends Controller
{
    public function actionIndex()
    {
        $client = Client::findOne(['name' => 'Демо-клиент']);
        if ($client) {
            echo "Client ID: {$client->id}\n";
        } else {
            echo "Client not found!\n";
        }

        $user = User::findOne(['email' => 'client@demo.local']);
        if ($user) {
            echo "User ID: {$user->id}, client_id: {$user->client_id}\n";
        }

        $docs = Document::find()->all();
        echo "Total documents: " . count($docs) . "\n";
        foreach ($docs as $doc) {
            echo "Doc {$doc->id}: client_id={$doc->client_id}, file={$doc->file_path}\n";
        }
    }
}


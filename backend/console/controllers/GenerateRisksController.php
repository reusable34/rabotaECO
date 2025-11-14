<?php

namespace console\controllers;

use common\models\Requirement;
use common\models\Risk;
use Yii;
use yii\console\Controller;

/**
 * Контроллер для генерации рисков для существующих требований
 */
class GenerateRisksController extends Controller
{
    /**
     * Генерировать риски для всех требований без рисков
     */
    public function actionAll()
    {
        $this->stdout("=== ГЕНЕРАЦИЯ РИСКОВ ДЛЯ ТРЕБОВАНИЙ ===\n\n");

        $requirements = Requirement::find()->all();
        $total = count($requirements);
        $created = 0;
        $skipped = 0;

        foreach ($requirements as $req) {
            if (!$req->basis) {
                $skipped++;
                continue;
            }

            // Извлекаем статьи КоАП из basis
            preg_match_all('/КоАП\s+РФ\s+(\d+\.?\d*\.?\d*)/u', $req->basis, $matches);
            
            if (empty($matches[1])) {
                $skipped++;
                continue;
            }

            $articles = $matches[1];
            $fineMatrix = [
                '7.3' => ['min' => 30000, 'max' => 500000],
                '7.6' => ['min' => 20000, 'max' => 200000],
                '8.2' => ['min' => 20000, 'max' => 100000],
                '8.21' => ['min' => 40000, 'max' => 200000],
                '8.41' => ['min' => 30000, 'max' => 100000],
                '8.41.1' => ['min' => 30000, 'max' => 100000],
                '8.5' => ['min' => 30000, 'max' => 150000],
                '13.19' => ['min' => 10000, 'max' => 20000],
                '19.7' => ['min' => 10000, 'max' => 20000],
            ];

            foreach ($articles as $article) {
                $articleParts = explode('/', $article);
                
                foreach ($articleParts as $articlePart) {
                    $articlePart = trim($articlePart);
                    
                    // Проверяем, не существует ли уже риск
                    $existingRisk = Risk::findOne([
                        'requirement_id' => $req->id,
                        'article' => $articlePart
                    ]);
                    
                    if ($existingRisk) {
                        continue;
                    }

                    $fines = $fineMatrix[$articlePart] ?? ['min' => 20000, 'max' => 100000];
                    
                    $risk = new Risk();
                    $risk->requirement_id = $req->id;
                    $risk->article = $articlePart;
                    $risk->fine_min = $fines['min'];
                    $risk->fine_max = $fines['max'];
                    
                    if ($risk->save()) {
                        $created++;
                        $this->stdout("✓ Создан риск для требования ID {$req->id}: статья {$articlePart}\n");
                    }
                }
            }
        }

        $this->stdout("\n=== ИТОГИ ===\n");
        $this->stdout("Всего требований: {$total}\n");
        $this->stdout("Создано рисков: {$created}\n");
        $this->stdout("Пропущено: {$skipped}\n");

        return 0;
    }
}


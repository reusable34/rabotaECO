<?php

namespace console\controllers;

use common\models\Requirement;
use Yii;
use yii\console\Controller;

/**
 * Контроллер для обновления basis существующих требований
 */
class UpdateRequirementsBasisController extends Controller
{
    /**
     * Обновить basis для требований ПЭК и ППЭК
     */
    public function actionUpdatePek()
    {
        $this->stdout("=== ОБНОВЛЕНИЕ BASIS ДЛЯ ТРЕБОВАНИЙ ПЭК ===\n\n");

        $updated = 0;

        // Обновляем требования ППЭК
        $ppekReqs = Requirement::find()
            ->where(['like', 'title', '%Программа производственного экологического контроля (ППЭК)%'])
            ->all();

        foreach ($ppekReqs as $req) {
            if (strpos($req->basis, 'КоАП РФ 8.21') === false) {
                $req->basis = 'ФЗ-7, приказы РПН (ПЭК), КоАП РФ 8.21';
                if ($req->save()) {
                    $updated++;
                    $this->stdout("✓ Обновлено требование ID {$req->id}: ППЭК\n");
                }
            }
        }

        // Обновляем требования "Отчет по программе ПЭК"
        $pekReqs = Requirement::find()
            ->where(['like', 'title', '%Отчет по программе производственного экологического контроля (ПЭК)%'])
            ->all();

        foreach ($pekReqs as $req) {
            if (strpos($req->basis, 'КоАП РФ 8.21') === false) {
                $req->basis = 'ФЗ-7, приказы РПН (ПЭК), КоАП РФ 8.21';
                if ($req->save()) {
                    $updated++;
                    $this->stdout("✓ Обновлено требование ID {$req->id}: Отчет по программе ПЭК\n");
                }
            }
        }

        $this->stdout("\n=== ИТОГИ ===\n");
        $this->stdout("Обновлено требований: {$updated}\n");

        return 0;
    }
}


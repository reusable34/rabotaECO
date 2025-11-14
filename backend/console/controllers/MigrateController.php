<?php

namespace console\controllers;

use yii\console\controllers\MigrateController as BaseMigrateController;

class MigrateController extends BaseMigrateController
{
    public $migrationPath = '@console/migrations';
}


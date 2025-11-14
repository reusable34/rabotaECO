<?php

use yii\db\Migration;

/**
 * Добавляет поле ответственного лица в таблицу clients
 */
class m240101_000011_add_responsible_person_to_clients extends Migration
{
    /**
     * {@inheritdoc}
     */
    public function safeUp()
    {
        $this->addColumn('{{%clients}}', 'responsible_person', $this->string(255)->null()->comment('Ответственный (ФИО)'));
    }

    /**
     * {@inheritdoc}
     */
    public function safeDown()
    {
        $this->dropColumn('{{%clients}}', 'responsible_person');
    }
}


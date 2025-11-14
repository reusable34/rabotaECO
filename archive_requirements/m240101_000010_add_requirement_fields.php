<?php

use yii\db\Migration;

/**
 * Добавляет дополнительные поля в таблицу requirements
 */
class m240101_000010_add_requirement_fields extends Migration
{
    /**
     * {@inheritdoc}
     */
    public function safeUp()
    {
        $this->addColumn('{{%requirements}}', 'basis', $this->text()->null()->comment('Основание (КоАП статья)'));
        $this->addColumn('{{%requirements}}', 'artifacts', $this->text()->null()->comment('Артефакты (JSON массив)'));
        $this->addColumn('{{%requirements}}', 'document_year', $this->integer()->null()->comment('Год документа'));
        $this->addColumn('{{%requirements}}', 'responsible_person', $this->string(255)->null()->comment('Ответственный (ФИО)'));
    }

    /**
     * {@inheritdoc}
     */
    public function safeDown()
    {
        $this->dropColumn('{{%requirements}}', 'basis');
        $this->dropColumn('{{%requirements}}', 'artifacts');
        $this->dropColumn('{{%requirements}}', 'document_year');
        $this->dropColumn('{{%requirements}}', 'responsible_person');
    }
}


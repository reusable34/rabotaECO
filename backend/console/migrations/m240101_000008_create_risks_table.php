<?php

use yii\db\Migration;

/**
 * Handles the creation of table `{{%risks}}`.
 */
class m240101_000008_create_risks_table extends Migration
{
    /**
     * {@inheritdoc}
     */
    public function safeUp()
    {
        $this->createTable('{{%risks}}', [
            'id' => $this->primaryKey(),
            'requirement_id' => $this->integer()->notNull(),
            'article' => $this->string(50)->notNull(),
            'fine_min' => $this->integer()->null(),
            'fine_max' => $this->integer()->null(),
        ]);

        $this->addForeignKey(
            'fk-risks-requirement_id',
            '{{%risks}}',
            'requirement_id',
            '{{%requirements}}',
            'id',
            'CASCADE'
        );

        $this->createIndex('idx-risks-requirement_id', '{{%risks}}', 'requirement_id');
    }

    /**
     * {@inheritdoc}
     */
    public function safeDown()
    {
        $this->dropTable('{{%risks}}');
    }
}


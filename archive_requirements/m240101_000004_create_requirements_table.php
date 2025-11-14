<?php

use yii\db\Migration;

/**
 * Handles the creation of table `{{%requirements}}`.
 */
class m240101_000004_create_requirements_table extends Migration
{
    /**
     * {@inheritdoc}
     */
    public function safeUp()
    {
        $this->createTable('{{%requirements}}', [
            'id' => $this->primaryKey(),
            'client_id' => $this->integer()->notNull(),
            'title' => $this->string(255)->notNull(),
            'status' => $this->string(50)->notNull()->defaultValue('pending'),
            'deadline' => $this->date()->null(),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ]);

        $this->addForeignKey(
            'fk-requirements-client_id',
            '{{%requirements}}',
            'client_id',
            '{{%clients}}',
            'id',
            'CASCADE'
        );

        $this->createIndex('idx-requirements-client_id', '{{%requirements}}', 'client_id');
    }

    /**
     * {@inheritdoc}
     */
    public function safeDown()
    {
        $this->dropTable('{{%requirements}}');
    }
}


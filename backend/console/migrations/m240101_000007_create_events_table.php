<?php

use yii\db\Migration;

/**
 * Handles the creation of table `{{%events}}`.
 */
class m240101_000007_create_events_table extends Migration
{
    /**
     * {@inheritdoc}
     */
    public function safeUp()
    {
        $this->createTable('{{%events}}', [
            'id' => $this->primaryKey(),
            'client_id' => $this->integer()->notNull(),
            'title' => $this->string(255)->notNull(),
            'date' => $this->date()->notNull(),
            'completed' => $this->boolean()->defaultValue(false),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ]);

        $this->addForeignKey(
            'fk-events-client_id',
            '{{%events}}',
            'client_id',
            '{{%clients}}',
            'id',
            'CASCADE'
        );

        $this->createIndex('idx-events-client_id', '{{%events}}', 'client_id');
        $this->createIndex('idx-events-date', '{{%events}}', 'date');
    }

    /**
     * {@inheritdoc}
     */
    public function safeDown()
    {
        $this->dropTable('{{%events}}');
    }
}


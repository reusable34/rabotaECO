<?php

use yii\db\Migration;

/**
 * Handles the creation of table `{{%contracts}}`.
 */
class m240101_000006_create_contracts_table extends Migration
{
    /**
     * {@inheritdoc}
     */
    public function safeUp()
    {
        $this->createTable('{{%contracts}}', [
            'id' => $this->primaryKey(),
            'client_id' => $this->integer()->notNull(),
            'number' => $this->string(100)->notNull(),
            'status' => $this->string(50)->notNull()->defaultValue('draft'),
            'date' => $this->date()->null(),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ]);

        $this->addForeignKey(
            'fk-contracts-client_id',
            '{{%contracts}}',
            'client_id',
            '{{%clients}}',
            'id',
            'CASCADE'
        );

        $this->createIndex('idx-contracts-client_id', '{{%contracts}}', 'client_id');
    }

    /**
     * {@inheritdoc}
     */
    public function safeDown()
    {
        $this->dropTable('{{%contracts}}');
    }
}


<?php

use yii\db\Migration;

/**
 * Handles the creation of table `{{%documents}}`.
 */
class m240101_000005_create_documents_table extends Migration
{
    /**
     * {@inheritdoc}
     */
    public function safeUp()
    {
        $this->createTable('{{%documents}}', [
            'id' => $this->primaryKey(),
            'client_id' => $this->integer()->notNull(),
            'file_path' => $this->string(500)->notNull(),
            'type' => $this->string(100)->null(),
            'status' => $this->string(50)->notNull()->defaultValue('pending'),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ]);

        $this->addForeignKey(
            'fk-documents-client_id',
            '{{%documents}}',
            'client_id',
            '{{%clients}}',
            'id',
            'CASCADE'
        );

        $this->createIndex('idx-documents-client_id', '{{%documents}}', 'client_id');
    }

    /**
     * {@inheritdoc}
     */
    public function safeDown()
    {
        $this->dropTable('{{%documents}}');
    }
}


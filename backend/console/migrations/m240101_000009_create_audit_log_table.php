<?php

use yii\db\Migration;

/**
 * Handles the creation of table `{{%audit_log}}`.
 */
class m240101_000009_create_audit_log_table extends Migration
{
    /**
     * {@inheritdoc}
     */
    public function safeUp()
    {
        $this->createTable('{{%audit_log}}', [
            'id' => $this->primaryKey(),
            'user_id' => $this->integer()->notNull(),
            'entity_type' => $this->string(50)->notNull(),
            'entity_id' => $this->integer()->null(),
            'action' => $this->string(50)->notNull(),
            'timestamp' => $this->integer()->notNull(),
        ]);

        $this->addForeignKey(
            'fk-audit_log-user_id',
            '{{%audit_log}}',
            'user_id',
            '{{%users}}',
            'id',
            'CASCADE'
        );

        $this->createIndex('idx-audit_log-user_id', '{{%audit_log}}', 'user_id');
        $this->createIndex('idx-audit_log-entity', '{{%audit_log}}', ['entity_type', 'entity_id']);
    }

    /**
     * {@inheritdoc}
     */
    public function safeDown()
    {
        $this->dropTable('{{%audit_log}}');
    }
}


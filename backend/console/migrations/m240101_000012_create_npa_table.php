<?php

use yii\db\Migration;

/**
 * Создает таблицу для справочника НПА (нормативно-правовые акты)
 */
class m240101_000012_create_npa_table extends Migration
{
    /**
     * {@inheritdoc}
     */
    public function safeUp()
    {
        $this->createTable('{{%npa}}', [
            'id' => $this->primaryKey(),
            'code' => $this->string(100)->notNull()->comment('Код НПА'),
            'title' => $this->string(500)->notNull()->comment('Название'),
            'link' => $this->string(1000)->null()->comment('Ссылка'),
            'block' => $this->string(100)->null()->comment('Блок (раздел)'),
            'created_at' => $this->integer()->notNull(),
            'updated_at' => $this->integer()->notNull(),
        ]);

        $this->createIndex('idx-npa-code', '{{%npa}}', 'code');
        $this->createIndex('idx-npa-block', '{{%npa}}', 'block');
    }

    /**
     * {@inheritdoc}
     */
    public function safeDown()
    {
        $this->dropTable('{{%npa}}');
    }
}


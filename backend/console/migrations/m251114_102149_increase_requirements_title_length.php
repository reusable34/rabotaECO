<?php

use yii\db\Migration;

/**
 * Class m251114_102149_increase_requirements_title_length
 * Увеличивает длину поля title в таблице requirements для поддержки длинных названий требований
 */
class m251114_102149_increase_requirements_title_length extends Migration
{
    /**
     * {@inheritdoc}
     */
    public function safeUp()
    {
        // Изменяем тип поля title с VARCHAR(255) на VARCHAR(1000) для поддержки длинных названий
        $this->alterColumn('{{%requirements}}', 'title', $this->string(1000)->notNull());
    }

    /**
     * {@inheritdoc}
     */
    public function safeDown()
    {
        // Возвращаем обратно к VARCHAR(255)
        $this->alterColumn('{{%requirements}}', 'title', $this->string(255)->notNull());
    }
}

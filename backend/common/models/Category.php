<?php

namespace common\models;

use Yii;
use yii\db\ActiveRecord;

/**
 * Category model
 *
 * @property integer $id
 * @property string $title
 * @property string $description
 */
class Category extends ActiveRecord
{
    /**
     * {@inheritdoc}
     */
    public static function tableName()
    {
        return '{{%categories}}';
    }

    /**
     * {@inheritdoc}
     */
    public function rules()
    {
        return [
            [['title'], 'required'],
            [['title'], 'string', 'max' => 100],
            [['description'], 'string'],
        ];
    }
}


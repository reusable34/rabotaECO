<?php

namespace common\models;

use Yii;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveRecord;

/**
 * NPA model (Нормативно-правовой акт)
 *
 * @property integer $id
 * @property string $code
 * @property string $title
 * @property string $link
 * @property string $block
 * @property integer $created_at
 * @property integer $updated_at
 */
class Npa extends ActiveRecord
{
    /**
     * {@inheritdoc}
     */
    public static function tableName()
    {
        return '{{%npa}}';
    }

    /**
     * {@inheritdoc}
     */
    public function behaviors()
    {
        return [
            TimestampBehavior::class,
        ];
    }

    /**
     * {@inheritdoc}
     */
    public function rules()
    {
        return [
            [['code', 'title'], 'required'],
            [['code'], 'string', 'max' => 100],
            [['title'], 'string', 'max' => 500],
            [['link'], 'string', 'max' => 1000],
            [['block'], 'string', 'max' => 100],
        ];
    }

    /**
     * {@inheritdoc}
     */
    public function attributeLabels()
    {
        return [
            'id' => 'ID',
            'code' => 'Код',
            'title' => 'Название',
            'link' => 'Ссылка',
            'block' => 'Блок',
        ];
    }
}


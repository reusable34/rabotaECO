<?php

namespace common\models;

use Yii;
use yii\db\ActiveRecord;

/**
 * Risk model
 *
 * @property integer $id
 * @property integer $requirement_id
 * @property string $article
 * @property integer $fine_min
 * @property integer $fine_max
 */
class Risk extends ActiveRecord
{
    /**
     * {@inheritdoc}
     */
    public static function tableName()
    {
        return '{{%risks}}';
    }

    /**
     * {@inheritdoc}
     */
    public function rules()
    {
        return [
            [['requirement_id', 'article'], 'required'],
            [['requirement_id', 'fine_min', 'fine_max'], 'integer'],
            [['article'], 'string', 'max' => 50],
        ];
    }

    /**
     * @return \yii\db\ActiveQuery
     */
    public function getRequirement()
    {
        return $this->hasOne(Requirement::class, ['id' => 'requirement_id']);
    }
}


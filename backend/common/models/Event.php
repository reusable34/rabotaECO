<?php

namespace common\models;

use Yii;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveRecord;

/**
 * Event model
 *
 * @property integer $id
 * @property integer $client_id
 * @property string $title
 * @property string $date
 * @property boolean $completed
 * @property integer $created_at
 * @property integer $updated_at
 */
class Event extends ActiveRecord
{
    /**
     * {@inheritdoc}
     */
    public static function tableName()
    {
        return '{{%events}}';
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
            [['client_id', 'title', 'date'], 'required'],
            [['client_id'], 'integer'],
            [['completed'], 'boolean'],
            [['title'], 'string', 'max' => 255],
            [['date'], 'date', 'format' => 'php:Y-m-d'],
        ];
    }

    /**
     * @return \yii\db\ActiveQuery
     */
    public function getClient()
    {
        return $this->hasOne(Client::class, ['id' => 'client_id']);
    }

    /**
     * {@inheritdoc}
     */
    public function fields()
    {
        return [
            'id',
            'client_id',
            'title',
            'date',
            'completed',
            'created_at',
            'updated_at',
        ];
    }
}


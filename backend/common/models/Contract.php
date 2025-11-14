<?php

namespace common\models;

use Yii;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveRecord;

/**
 * Contract model
 *
 * @property integer $id
 * @property integer $client_id
 * @property string $number
 * @property string $status
 * @property string $date
 * @property integer $created_at
 * @property integer $updated_at
 */
class Contract extends ActiveRecord
{
    const STATUS_DRAFT = 'draft';
    const STATUS_ACTIVE = 'active';
    const STATUS_COMPLETED = 'completed';
    const STATUS_CANCELLED = 'cancelled';

    /**
     * {@inheritdoc}
     */
    public static function tableName()
    {
        return '{{%contracts}}';
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
            [['client_id', 'number'], 'required'],
            [['client_id'], 'integer'],
            [['number'], 'string', 'max' => 100],
            [['status'], 'in', 'range' => [self::STATUS_DRAFT, self::STATUS_ACTIVE, self::STATUS_COMPLETED, self::STATUS_CANCELLED]],
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
}


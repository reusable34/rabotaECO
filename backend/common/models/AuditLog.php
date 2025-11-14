<?php

namespace common\models;

use Yii;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveRecord;

/**
 * AuditLog model
 *
 * @property integer $id
 * @property integer $user_id
 * @property string $entity_type
 * @property integer $entity_id
 * @property string $action
 * @property integer $timestamp
 */
class AuditLog extends ActiveRecord
{
    /**
     * {@inheritdoc}
     */
    public static function tableName()
    {
        return '{{%audit_log}}';
    }

    /**
     * {@inheritdoc}
     */
    public function behaviors()
    {
        return [
            [
                'class' => TimestampBehavior::class,
                'createdAtAttribute' => 'timestamp',
                'updatedAtAttribute' => false,
            ],
        ];
    }

    /**
     * {@inheritdoc}
     */
    public function rules()
    {
        return [
            [['user_id', 'entity_type', 'action'], 'required'],
            [['user_id', 'entity_id'], 'integer'],
            [['entity_type'], 'string', 'max' => 50],
            [['action'], 'string', 'max' => 50],
        ];
    }

    /**
     * @return \yii\db\ActiveQuery
     */
    public function getUser()
    {
        return $this->hasOne(User::class, ['id' => 'user_id']);
    }
}


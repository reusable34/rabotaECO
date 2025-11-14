<?php

namespace common\models;

use Yii;
use yii\behaviors\TimestampBehavior;
use yii\db\ActiveRecord;

/**
 * Requirement model
 *
 * @property integer $id
 * @property integer $client_id
 * @property string $title
 * @property string $status
 * @property string $deadline
 * @property string $basis
 * @property string $artifacts
 * @property integer $document_year
 * @property string $responsible_person
 * @property integer $created_at
 * @property integer $updated_at
 */
class Requirement extends ActiveRecord
{
    const STATUS_PENDING = 'pending';
    const STATUS_IN_PROGRESS = 'in_progress';
    const STATUS_COMPLETED = 'completed';
    const STATUS_NOT_COMPLETED = 'not_completed';

    /**
     * {@inheritdoc}
     */
    public static function tableName()
    {
        return '{{%requirements}}';
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
            [['client_id', 'title'], 'required'],
            [['client_id', 'document_year'], 'integer'],
            [['title', 'responsible_person'], 'string', 'max' => 255],
            [['basis', 'artifacts'], 'string'],
            [['status'], 'in', 'range' => [self::STATUS_PENDING, self::STATUS_IN_PROGRESS, self::STATUS_COMPLETED, self::STATUS_NOT_COMPLETED]],
            [['deadline'], 'date', 'format' => 'php:Y-m-d'],
        ];
    }

    /**
     * Получить артефакты как массив
     * @return array
     */
    public function getArtifactsArray()
    {
        if (empty($this->artifacts)) {
            return [];
        }
        $decoded = json_decode($this->artifacts, true);
        return is_array($decoded) ? $decoded : [];
    }

    /**
     * Установить артефакты из массива
     * @param array $artifacts
     */
    public function setArtifactsArray(array $artifacts)
    {
        $this->artifacts = json_encode($artifacts, JSON_UNESCAPED_UNICODE);
    }

    /**
     * @return \yii\db\ActiveQuery
     */
    public function getClient()
    {
        return $this->hasOne(Client::class, ['id' => 'client_id']);
    }

    /**
     * @return \yii\db\ActiveQuery
     */
    public function getRisks()
    {
        return $this->hasMany(Risk::class, ['requirement_id' => 'id']);
    }

    /**
     * @return \yii\db\ActiveQuery
     */
    public function getDocuments()
    {
        return $this->hasMany(Document::class, ['client_id' => 'client_id'])
            ->andWhere(['type' => $this->getArtifactsArray()]);
    }

    /**
     * {@inheritdoc}
     */
    public function fields()
    {
        $fields = parent::fields();
        $fields['artifacts'] = function () {
            return $this->getArtifactsArray();
        };
        return $fields;
    }
}


<?php

namespace common\services;

use common\models\Client;
use common\models\Requirement;
use Yii;

/**
 * @deprecated Используйте RequirementGeneratorService вместо этого класса
 */
class RequirementService
{
    /**
     * Автоматическое формирование требований на основе данных клиента
     *
     * @param Client $client
     * @return void
     */
    public static function generateRequirements(Client $client)
    {
        $categoryId = $client->category_id;
        $requirements = [];

        // Базовые требования по категориям НВОС
        $nvosRequirements = self::getNvosRequirements($categoryId);
        $requirements = array_merge($requirements, $nvosRequirements);

        // Требования по водопользованию
        if ($client->has_well) {
            $requirements[] = [
                'title' => 'Лицензия на пользование недрами',
                'deadline' => date('Y-m-d', strtotime('+90 days')),
            ];
        }

        if ($client->has_river) {
            $requirements[] = [
                'title' => 'Решение на водопользование',
                'deadline' => date('Y-m-d', strtotime('+90 days')),
            ];
            $requirements[] = [
                'title' => 'Договор водопользования',
                'deadline' => date('Y-m-d', strtotime('+90 days')),
            ];
        }

        // Требования по побочной продукции
        if ($client->has_byproduct) {
            $requirements[] = [
                'title' => 'Технические условия "Удобрения органические на основе побочной продукции животноводства"',
                'deadline' => date('Y-m-d', strtotime('+120 days')),
            ];
        }

        // Создание требований в БД
        foreach ($requirements as $req) {
            $requirement = new Requirement();
            $requirement->client_id = $client->id;
            $requirement->title = $req['title'];
            $requirement->deadline = $req['deadline'] ?? null;
            $requirement->status = Requirement::STATUS_PENDING;
            if (!$requirement->save()) {
                Yii::error('Failed to save requirement: ' . json_encode($requirement->errors));
            }
        }
    }

    /**
     * Получить требования по категории НВОС
     *
     * @param int $categoryId (1=I, 2=II, 3=III, 4=IV)
     * @return array
     */
    private static function getNvosRequirements($categoryId)
    {
        $allRequirements = [
            1 => 'Журнал учёта движения отходов',
            2 => 'Журнал учёта источников выбросов',
            3 => '2-ТП (воздух)',
            4 => '2-ТП (отходы)',
            5 => 'Декларация о плате за НВОС',
            6 => 'Отчёт ПЭК',
            8 => 'Инвентаризация выбросов',
            9 => 'Инвентаризация отходов',
            10 => 'Паспорта отходов I–IV класса',
            12 => 'НООЛР',
            13 => 'НДВ',
            15 => 'Экспертное заключение на НДВ',
            16 => 'СЭЗ на проект НДВ (Роспотребнадзор)',
            17 => 'План НМУ',
            18 => 'ППЭК',
            19 => 'ДВОС (II категория)',
            20 => 'КЭР (I категория)',
            21 => 'Проект СЗЗ',
            22 => 'Решение об установлении СЗЗ',
        ];

        // Матрица требований по категориям (из requirements.md)
        $categoryMatrix = [
            1 => [1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 13, 15, 16, 17, 18, 20, 21, 22], // I
            2 => [1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 13, 15, 16, 17, 18, 19, 21, 22], // II
            3 => [1, 2, 3, 4, 5, 6, 8, 9, 10, 15, 16, 17, 18, 21, 22], // III
            4 => [1, 3, 4, 8, 9, 10, 21, 22], // IV
        ];

        $requirements = [];
        $requiredIds = $categoryMatrix[$categoryId] ?? [];

        foreach ($requiredIds as $reqId) {
            if (isset($allRequirements[$reqId])) {
                $requirements[] = [
                    'title' => $allRequirements[$reqId],
                    'deadline' => self::calculateDeadline($reqId),
                ];
            }
        }

        return $requirements;
    }

    /**
     * Рассчитать дедлайн для требования
     *
     * @param int $reqId
     * @return string
     */
    private static function calculateDeadline($reqId)
    {
        // Базовый дедлайн - через 30 дней
        $baseDays = 30;

        // Специальные дедлайны для некоторых требований
        $specialDeadlines = [
            3 => 60,  // 2-ТП (воздух) - обычно до 22 января
            4 => 60,  // 2-ТП (отходы) - обычно до 1 февраля
            5 => 90,  // Декларация о плате за НВОС
        ];

        $days = $specialDeadlines[$reqId] ?? $baseDays;
        return date('Y-m-d', strtotime("+{$days} days"));
    }
}


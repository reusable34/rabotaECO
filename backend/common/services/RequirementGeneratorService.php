<?php

namespace common\services;

use common\models\Client;
use common\models\Requirement;
use common\models\Risk;
use Yii;

/**
 * Сервис для автогенерации требований на основе категории НВОС и параметров клиента
 * Логика основана на файле "Критерии_для_формирования_требований_.md"
 */
class RequirementGeneratorService
{
    /**
     * Автоматическое формирование требований на основе данных клиента
     *
     * @param Client $client
     * @return array Массив созданных требований
     */
    public static function generateRequirements(Client $client): array
    {
        $categoryId = $client->category_id;
        
        Yii::info("RequirementGeneratorService::generateRequirements: client_id={$client->id}, category_id={$categoryId}, has_well=" . ($client->has_well ? 'true' : 'false') . ", has_river=" . ($client->has_river ? 'true' : 'false') . ", has_byproduct=" . ($client->has_byproduct ? 'true' : 'false'));

        // 1. Получаем базовые требования по категории НВОС
        $baseRequirements = self::getBaseRequirementsForCategory($categoryId);
        Yii::info("Got " . count($baseRequirements) . " base requirements for category_id={$categoryId}");

        // 2. Добавляем дополнительные требования (скважина, река, побочный продукт)
        $allRequirements = array_merge($baseRequirements, self::getAdditionalRequirements($client));

        // 3. Создаем требования в БД
        $createdRequirements = [];
        
        // Логируем все требования перед созданием для III и IV категорий
        if ($categoryId == 3 || $categoryId == 4) {
            Yii::info("=== Category {$categoryId}: Requirements to create ===");
            Yii::info("  Base requirements: " . count($baseRequirements));
            Yii::info("  Additional requirements: " . (count($allRequirements) - count($baseRequirements)));
            foreach ($allRequirements as $idx => $reqData) {
                Yii::info("  [{$idx}] {$reqData['title']}");
            }
            Yii::info("=== Total: " . count($allRequirements) . " requirements ===");
        }
        
        foreach ($allRequirements as $reqData) {
            $requirement = new Requirement();
            $requirement->client_id = $client->id;
            $requirement->title = $reqData['title'];
            $requirement->basis = $reqData['basis'] ?? null;
            $requirement->setArtifactsArray($reqData['artifacts'] ?? []);
            $requirement->document_year = $reqData['document_year'] ?? date('Y');
            $requirement->deadline = $reqData['deadline'] ?? null;
            $requirement->status = Requirement::STATUS_PENDING;
            
            if ($requirement->save()) {
                $createdRequirements[] = $requirement;
                Yii::info("SUCCESS: Created requirement ID {$requirement->id}: {$reqData['title']}");
                
                // Автоматически создаем риски на основе статей КоАП из basis
                self::createRisksForRequirement($requirement, $reqData['basis'] ?? null);
            } else {
                Yii::error("FAILED: Could not save requirement '{$reqData['title']}': " . json_encode($requirement->errors));
                Yii::error("Requirement data: " . json_encode([
                    'title' => $reqData['title'],
                    'basis' => $reqData['basis'],
                    'artifacts_count' => count($reqData['artifacts'] ?? []),
                    'document_year' => $reqData['document_year'],
                    'deadline' => $reqData['deadline'],
                ]));
            }
        }
        
        // Финальная проверка для всех категорий
        $expectedBaseCounts = [
            1 => 18, // I категория
            2 => 18, // II категория
            3 => 16, // III категория
            4 => 8,  // IV категория
        ];
        
        $expectedBaseCount = $expectedBaseCounts[$categoryId] ?? 0;
        $expectedTotalCount = $expectedBaseCount;
        if ($client->has_well) $expectedTotalCount++;
        if ($client->has_river) $expectedTotalCount += 2;
        if ($client->has_byproduct) $expectedTotalCount++;
        
        $actualCount = count($createdRequirements);
        
        if ($actualCount != $expectedTotalCount) {
            Yii::error("ERROR: For category {$categoryId}, expected {$expectedTotalCount} requirements ({$expectedBaseCount} base" . 
                ($client->has_well ? " + 1 well" : "") . 
                ($client->has_river ? " + 2 river" : "") . 
                ($client->has_byproduct ? " + 1 byproduct" : "") . 
                "), but created {$actualCount}");
            Yii::error("Created requirements for category {$categoryId}:");
            foreach ($createdRequirements as $req) {
                Yii::error("  - {$req->title}");
            }
            Yii::error("Expected base requirements count: {$expectedBaseCount}, got: " . count($baseRequirements));
        } else {
            Yii::info("SUCCESS: Category {$categoryId} - All {$expectedTotalCount} requirements created correctly!");
        }
        
        // Проверяем, что все базовые требования созданы
        if (count($baseRequirements) != $expectedBaseCount) {
            Yii::error("CRITICAL: For category {$categoryId}, expected {$expectedBaseCount} base requirements, but got " . count($baseRequirements));
            Yii::error("Base requirements titles:");
            foreach ($baseRequirements as $req) {
                Yii::error("  - {$req['title']}");
            }
        }

        Yii::info("RequirementGeneratorService: Created " . count($createdRequirements) . " requirements for client_id={$client->id}, category_id={$categoryId}");

        return $createdRequirements;
    }

    /**
     * Получить базовые требования для категории НВОС
     * Матрица строго по критериям из файла "Критерии_для_формирования_требований_.md"
     *
     * @param int $categoryId (1=I, 2=II, 3=III, 4=IV)
     * @return array
     */
    private static function getBaseRequirementsForCategory(int $categoryId): array
    {
        // Матрица требований по категориям (строго по критериям)
        $categoryMatrix = [
            1 => [1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 13, 15, 16, 17, 18, 20, 21, 22], // I категория: 18 требований
            2 => [1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 13, 15, 16, 17, 18, 19, 21, 22], // II категория: 18 требований
            3 => [1, 2, 3, 4, 5, 6, 8, 9, 10, 14, 15, 16, 17, 18, 21, 22], // III категория: 16 требований
            4 => [1, 3, 4, 8, 9, 10, 21, 22], // IV категория: 8 требований
        ];

        $requiredIds = $categoryMatrix[$categoryId] ?? [];
        
        if (empty($requiredIds)) {
            Yii::error("Unknown category_id: {$categoryId}");
            return [];
        }

        $allRequirements = self::getAllRequirementsDefinitions();
        $requirements = [];
        $currentYear = date('Y');

        Yii::info("getBaseRequirementsForCategory: category_id={$categoryId}, requiredIds=" . json_encode($requiredIds));
        
        foreach ($requiredIds as $reqId) {
            if (!isset($allRequirements[$reqId])) {
                Yii::error("Requirement ID {$reqId} not found in definitions for category_id={$categoryId}");
                continue;
            }

            $reqDef = $allRequirements[$reqId];
            $requirements[] = [
                'title' => $reqDef['title'],
                'basis' => $reqDef['basis'],
                'artifacts' => $reqDef['artifacts'],
                'deadline' => self::calculateDeadline($reqId),
                'document_year' => $currentYear,
            ];
            Yii::info("  Added requirement ID {$reqId}: {$reqDef['title']}");
        }

        // Валидация количества требований
        $expectedCounts = [1 => 18, 2 => 18, 3 => 16, 4 => 8];
        $expectedCount = $expectedCounts[$categoryId] ?? 0;
        if (count($requirements) !== $expectedCount) {
            Yii::error("ERROR: For category {$categoryId}, expected {$expectedCount} requirements, but got " . count($requirements));
        } else {
            Yii::info("SUCCESS: Category {$categoryId} - All {$expectedCount} base requirements are correct");
        }

        return $requirements;
    }

    /**
     * Получить дополнительные требования (скважина, река, побочный продукт)
     *
     * @param Client $client
     * @return array
     */
    private static function getAdditionalRequirements(Client $client): array
    {
        $requirements = [];

        // Скважина
        if ($client->has_well) {
            $requirements[] = [
                'title' => 'Лицензия на право пользования недрами',
                'basis' => 'Закон РФ "О недрах", КоАП РФ 7.3',
                'artifacts' => ['Лицензия на недра'],
                'deadline' => date('Y-m-d', strtotime('+90 days')),
                'document_year' => date('Y'),
            ];
        }

        // Река (два требования)
        if ($client->has_river) {
            $requirements[] = [
                'title' => 'Решение на право пользования водным объектом',
                'basis' => 'Водный кодекс РФ, КоАП РФ 7.6',
                'artifacts' => ['Решение на водопользование'],
                'deadline' => date('Y-m-d', strtotime('+90 days')),
                'document_year' => date('Y'),
            ];
            $requirements[] = [
                'title' => 'Договор водопользования',
                'basis' => 'Водный кодекс РФ, КоАП РФ 7.6',
                'artifacts' => ['Договор водопользования'],
                'deadline' => date('Y-m-d', strtotime('+90 days')),
                'document_year' => date('Y'),
            ];
        }

        // Побочный продукт
        if ($client->has_byproduct) {
            $requirements[] = [
                'title' => 'Технические условия "Удобрения органические на основе побочной продукции животноводства"',
                'basis' => 'ГОСТ, технические регламенты',
                'artifacts' => ['Технические условия на удобрения'],
                'deadline' => date('Y-m-d', strtotime('+120 days')),
                'document_year' => date('Y'),
            ];
        }

        return $requirements;
    }

    /**
     * Получить определения всех требований
     *
     * @return array
     */
    private static function getAllRequirementsDefinitions(): array
    {
        return [
            1 => [
                'title' => 'Журналы учета движения отходов производства и потребления',
                'basis' => 'ФЗ-89 "Об отходах производства и потребления", КоАП РФ 8.2',
                'artifacts' => ['Журнал учета отходов'],
            ],
            2 => [
                'title' => 'Журналы учета стационарных источников выбросов и их характеристик',
                'basis' => 'ФЗ-7 "Об охране окружающей среды", КоАП РФ 8.21',
                'artifacts' => ['Журнал учета источников выбросов'],
            ],
            3 => [
                'title' => 'Статотчетность по форме 2-ТП (воздух), при условии суммарного выброса более 5 тонн/год',
                'basis' => 'Порядки 2-ТП, КоАП РФ 19.7/13.19',
                'artifacts' => ['Отчёт 2-ТП (воздух)'],
            ],
            4 => [
                'title' => 'Статотчетность по форме 2-ТП (отходы), при условии образования отходов более 100 кг',
                'basis' => 'Порядки 2-ТП, КоАП РФ 19.7/13.19',
                'artifacts' => ['Отчёт 2-ТП (отходы)'],
            ],
            5 => [
                'title' => 'Декларация о плате за негативное воздействие на окружающую среду',
                'basis' => 'КоАП РФ 8.41/8.41.1',
                'artifacts' => ['Расчёт платы', 'Платёжное поручение', 'Декларация в ЛК РПН'],
            ],
            6 => [
                'title' => 'Отчет по программе производственного экологического контроля (ПЭК)',
                'basis' => 'ФЗ-7, приказы РПН (ПЭК), КоАП РФ 8.21',
                'artifacts' => ['Программа ПЭК', 'Журналы', 'Отчёт ПЭК'],
            ],
            8 => [
                'title' => 'Отчет инвентаризации выбросов вредных (загрязняющих) веществ в атмосферу',
                'basis' => 'ФЗ-7, КоАП РФ 8.21',
                'artifacts' => ['Отчёт инвентаризации выбросов'],
            ],
            9 => [
                'title' => 'Отчет инвентаризации отходов производства и потребления',
                'basis' => 'ФЗ-89, КоАП РФ 8.2',
                'artifacts' => ['Отчёт инвентаризации отходов'],
            ],
            10 => [
                'title' => 'Паспорта на отходы I-IV класса опасности',
                'basis' => 'ФЗ-89, КоАП РФ 8.2',
                'artifacts' => ['Паспорт отходов I класса', 'Паспорт отходов II класса', 'Паспорт отходов III класса', 'Паспорт отходов IV класса'],
            ],
            12 => [
                'title' => 'Нормативы образования отходов и лимиты на их размещение (НООЛР)',
                'basis' => 'ФЗ-89, КоАП РФ 8.2',
                'artifacts' => ['Проект НООЛР', 'Разрешение на размещение отходов'],
            ],
            13 => [
                'title' => 'Нормативы допустимых выбросов (НДВ)',
                'basis' => 'КоАП РФ 8.21 ч.1',
                'artifacts' => ['Проект ПДВ/НДВ', 'Разрешение/КЭР'],
            ],
            14 => [
                'title' => 'Нормативы допустимых выбросов для радиоактивных, высокотоксичных веществ, веществ, обладающих канцерогенными, мутагенными свойствами (веществ I, II класса опасности)',
                'basis' => 'КоАП РФ 8.21 ч.1',
                'artifacts' => ['Проект НДВ для веществ I-II класса опасности', 'Разрешение'],
            ],
            15 => [
                'title' => 'Экспертное заключение (протокола) санитарно-эпидемиологической экспертизы на проект НДВ',
                'basis' => 'ФЗ-52, КоАП РФ 8.21',
                'artifacts' => ['Экспертное заключение на проект НДВ'],
            ],
            16 => [
                'title' => 'Санитарно-эпидемиологическое заключение на проект НДВ в Управление Федеральной службы по надзору в сфере защиты прав потребителей и благополучия человека (Роспотребнадзоре)',
                'basis' => 'ФЗ-52, КоАП РФ 8.21',
                'artifacts' => ['СЭЗ на проект НДВ (Роспотребнадзор)'],
            ],
            17 => [
                'title' => 'План мероприятий неблагоприятных метеорологических условий (НМУ)',
                'basis' => 'ФЗ-7, КоАП РФ 8.21',
                'artifacts' => ['План НМУ'],
            ],
            18 => [
                'title' => 'Программа производственного экологического контроля (ППЭК)',
                'basis' => 'ФЗ-7, приказы РПН (ПЭК), КоАП РФ 8.21',
                'artifacts' => ['Программа ПЭК'],
            ],
            19 => [
                'title' => 'Декларация о воздействии на окружающую среду (ДВОС) для объектов II категории',
                'basis' => 'ФЗ-7, КоАП РФ 8.5',
                'artifacts' => ['Декларация ДВОС'],
            ],
            20 => [
                'title' => 'Комплексное экологическое разрешение (КЭР) для объектов I категории',
                'basis' => 'КоАП РФ 8.21 ч.1',
                'artifacts' => ['Проект ПДВ/НДВ', 'Разрешение/КЭР'],
            ],
            21 => [
                'title' => 'Проект санитарно-защитной зоны (СЗЗ)',
                'basis' => 'ФЗ-52, СанПиН',
                'artifacts' => ['Проект СЗЗ'],
            ],
            22 => [
                'title' => 'Решение об установлении санитарно-защитной зоны',
                'basis' => 'ФЗ-52, СанПиН',
                'artifacts' => ['Решение об установлении СЗЗ'],
            ],
        ];
    }

    /**
     * Рассчитать дедлайн для требования
     *
     * @param int $reqId
     * @return string
     */
    private static function calculateDeadline(int $reqId): string
    {
        $specialDeadlines = [
            3 => 60,  // 2-ТП (воздух) - обычно до 22 января
            4 => 60,  // 2-ТП (отходы) - обычно до 1 февраля
            5 => 90,  // Декларация о плате за НВОС
            6 => 45,  // Отчёт ПЭК
            12 => 120, // НООЛР
            13 => 120, // НДВ
            15 => 90,  // Экспертное заключение на НДВ
            16 => 90,  // СЭЗ на проект НДВ
            17 => 60,  // План НМУ
            18 => 45,  // ППЭК
            19 => 180, // ДВОС (II категория)
            20 => 180, // КЭР (I категория)
            21 => 150, // Проект СЗЗ
            22 => 120, // Решение об установлении СЗЗ
        ];

        $days = $specialDeadlines[$reqId] ?? 30;
        return date('Y-m-d', strtotime("+{$days} days"));
    }

    /**
     * Автоматически создает риски для требования на основе статей КоАП из basis
     *
     * @param Requirement $requirement
     * @param string|null $basis
     */
    private static function createRisksForRequirement(Requirement $requirement, ?string $basis): void
    {
        if (!$basis) {
            return;
        }

        // Матрица штрафов по статьям КоАП (в рублях)
        $fineMatrix = [
            '7.3' => ['min' => 30000, 'max' => 500000],   // Нарушение требований по охране недр
            '7.6' => ['min' => 20000, 'max' => 200000],   // Нарушение правил водопользования
            '8.2' => ['min' => 20000, 'max' => 100000],   // Несоблюдение требований в области обращения с отходами
            '8.21' => ['min' => 40000, 'max' => 200000],  // Нарушение правил выбросов
            '8.41' => ['min' => 30000, 'max' => 100000],  // Непредставление декларации о плате за НВОС
            '8.41.1' => ['min' => 30000, 'max' => 100000], // Непредставление декларации о плате за НВОС
            '8.5' => ['min' => 30000, 'max' => 150000],   // Сокрытие или искажение экологической информации
            '13.19' => ['min' => 10000, 'max' => 20000],   // Нарушение порядка представления статистической отчетности
            '19.7' => ['min' => 10000, 'max' => 20000],    // Непредставление сведений в органы власти
        ];

        // Извлекаем статьи КоАП из basis (формат: "КоАП РФ 8.2" или "КоАП РФ 8.41/8.41.1")
        preg_match_all('/КоАП\s+РФ\s+(\d+\.?\d*\.?\d*)/u', $basis, $matches);
        
        if (empty($matches[1])) {
            return;
        }

        $articles = $matches[1];
        
        foreach ($articles as $article) {
            // Обрабатываем случаи типа "8.41/8.41.1"
            $articleParts = explode('/', $article);
            
            foreach ($articleParts as $articlePart) {
                $articlePart = trim($articlePart);
                
                // Проверяем, не существует ли уже риск с этой статьей для этого требования
                $existingRisk = Risk::findOne([
                    'requirement_id' => $requirement->id,
                    'article' => $articlePart
                ]);
                
                if ($existingRisk) {
                    continue; // Риск уже существует
                }

                // Определяем штрафы для статьи
                $fines = $fineMatrix[$articlePart] ?? ['min' => 20000, 'max' => 100000]; // Дефолтные значения
                
                $risk = new Risk();
                $risk->requirement_id = $requirement->id;
                $risk->article = $articlePart;
                $risk->fine_min = $fines['min'];
                $risk->fine_max = $fines['max'];
                
                if ($risk->save()) {
                    Yii::info("Created risk for requirement ID {$requirement->id}: article {$articlePart}, fine {$fines['min']}-{$fines['max']} ₽");
                } else {
                    Yii::error("Failed to create risk for requirement ID {$requirement->id}, article {$articlePart}: " . json_encode($risk->errors));
                }
            }
        }
    }
}

<?php

namespace common\services;

use common\models\Client;
use common\models\Requirement;
use Yii;

/**
 * Сервис для автогенерации требований на основе категории НВОС и параметров клиента
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
        $requirements = [];

        Yii::info("RequirementGeneratorService::generateRequirements: client_id={$client->id}, category_id={$categoryId}, has_well=" . ($client->has_well ? 'true' : 'false') . ", has_river=" . ($client->has_river ? 'true' : 'false') . ", has_byproduct=" . ($client->has_byproduct ? 'true' : 'false'));

        // Базовые требования по категориям НВОС
        $nvosRequirements = self::getNvosRequirements($categoryId);
        Yii::info("Got " . count($nvosRequirements) . " base requirements from getNvosRequirements");
        $requirements = array_merge($requirements, $nvosRequirements);

        // Требования по водопользованию
        if ($client->has_well) {
            $requirements[] = [
                'title' => 'Лицензия на право пользования недрами',
                'basis' => 'Закон РФ "О недрах", КоАП РФ 7.3',
                'artifacts' => ['Лицензия на недра'],
                'deadline' => date('Y-m-d', strtotime('+90 days')),
                'document_year' => date('Y'),
            ];
        }

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

        // Требования по побочной продукции
        if ($client->has_byproduct) {
            $requirements[] = [
                'title' => 'Технические условия "Удобрения органические на основе побочной продукции животноводства"',
                'basis' => 'ГОСТ, технические регламенты',
                'artifacts' => ['Технические условия на удобрения'],
                'deadline' => date('Y-m-d', strtotime('+120 days')),
                'document_year' => date('Y'),
            ];
        }

        // Удаляем возможные дубликаты по названию перед созданием
        // ВАЖНО: Проверяем дубликаты, но не удаляем их, если они действительно разные требования
        $uniqueRequirements = [];
        $seenTitles = [];
        foreach ($requirements as $req) {
            $title = $req['title'];
            // Проверяем, не является ли это дубликатом
            if (!isset($seenTitles[$title])) {
                $seenTitles[$title] = true;
                $uniqueRequirements[] = $req;
            } else {
                // Если дубликат найден, логируем это
                Yii::warning("Duplicate requirement title found (skipping): {$title}");
            }
        }
        
        Yii::info("After deduplication: " . count($uniqueRequirements) . " unique requirements out of " . count($requirements) . " total");
        
        // Для отладки: выводим все требования перед созданием
        if ($categoryId == 3) {
            Yii::info("For category III, requirements before DB creation:");
            Yii::info("  Total from getNvosRequirements: " . count($nvosRequirements));
            Yii::info("  After adding well/river/byproduct: " . count($requirements));
            Yii::info("  After deduplication: " . count($uniqueRequirements));
            foreach ($uniqueRequirements as $idx => $req) {
                Yii::info("  [{$idx}] {$req['title']}");
            }
            
            // Проверяем, какие требования должны быть
            $expectedIds = [1, 2, 3, 4, 5, 6, 8, 9, 10, 14, 15, 16, 17, 18, 21, 22];
            $foundTitles = array_column($uniqueRequirements, 'title');
            foreach ($expectedIds as $expectedId) {
                // Проверяем, есть ли это требование в списке (по названию из allRequirements)
                $found = false;
                foreach ($foundTitles as $title) {
                    // Упрощенная проверка - ищем по ключевым словам
                    if ($expectedId == 14 && stripos($title, 'радиоактивных') !== false) $found = true;
                    if ($expectedId == 15 && stripos($title, 'Экспертное заключение') !== false && stripos($title, 'протокола') !== false) $found = true;
                    if ($expectedId == 16 && stripos($title, 'Санитарно-эпидемиологическое заключение') !== false && stripos($title, 'Роспотребнадзор') !== false) $found = true;
                    if ($expectedId == 17 && stripos($title, 'План мероприятий') !== false && stripos($title, 'НМУ') !== false) $found = true;
                    if ($expectedId == 18 && stripos($title, 'Программа производственного экологического контроля') !== false && stripos($title, 'ППЭК') !== false) $found = true;
                }
                if (!$found && in_array($expectedId, [14, 15, 16, 17, 18])) {
                    Yii::warning("MISSING requirement ID {$expectedId} for category III!");
                }
            }
        }

        // Создание требований в БД
        // ВАЖНО: Этот метод вызывается ПОСЛЕ удаления всех старых требований в RequirementController,
        // поэтому мы просто создаем новые требования без проверки на существование
        $createdRequirements = [];
        
        // Для IV категории проверяем, что создаются только правильные требования
        $forbiddenForIV = [2, 5, 6, 12, 13, 15, 16, 17, 18, 19, 20]; // ID требований, которых НЕ должно быть для IV категории
        
        foreach ($uniqueRequirements as $req) {
            // Проверка для IV категории - не создаем запрещенные требования
            if ($categoryId == 4) {
                // Проверяем по названию, не является ли это запрещенным требованием
                $isForbidden = false;
                $forbiddenTitles = [
                    'Журналы учета стационарных источников выбросов',
                    'Декларация о плате за негативное воздействие на окружающую среду',
                    'Отчет по программе производственного экологического контроля',
                    'Нормативы образования отходов и лимиты на их размещение',
                    'Нормативы допустимых выбросов', // НО НЕ для радиоактивных веществ (ID 14)
                    'Экспертное заключение',
                    'Санитарно-эпидемиологическое заключение',
                    // НЕ запрещаем План НМУ (ID 17) и ППЭК (ID 18) для III категории
                    'Декларация о воздействии на окружающую среду',
                    'Комплексное экологическое разрешение',
                ];
                
                foreach ($forbiddenTitles as $forbiddenTitle) {
                    // Специальная проверка: для "Нормативы допустимых выбросов" нужно проверить, не является ли это ID 14 (для радиоактивных веществ)
                    if ($forbiddenTitle === 'Нормативы допустимых выбросов') {
                        // Если это требование про радиоактивные вещества (ID 14), то оно разрешено для III категории
                        if (stripos($req['title'], 'радиоактивных') !== false || stripos($req['title'], 'высокотоксичных') !== false || stripos($req['title'], 'канцерогенными') !== false) {
                            continue; // Пропускаем проверку - это разрешенное требование
                        }
                    }
                    
                    // Для "Экспертное заключение" и "Санитарно-эпидемиологическое заключение" нужно проверить полное название
                    // чтобы не блокировать требования 15 и 16 для III категории
                    if ($forbiddenTitle === 'Экспертное заключение') {
                        // Проверяем, что это именно требование 15 (должно быть для III категории)
                        if (stripos($req['title'], 'Экспертное заключение (протокола) санитарно-эпидемиологической экспертизы на проект НДВ') !== false) {
                            continue; // Это требование 15 - разрешено для III категории
                        }
                    }
                    
                    if ($forbiddenTitle === 'Санитарно-эпидемиологическое заключение') {
                        // Проверяем, что это именно требование 16 (должно быть для III категории)
                        if (stripos($req['title'], 'Санитарно-эпидемиологическое заключение на проект НДВ') !== false) {
                            continue; // Это требование 16 - разрешено для III категории
                        }
                    }
                    
                    if (stripos($req['title'], $forbiddenTitle) !== false) {
                        $isForbidden = true;
                        Yii::warning("SKIPPING forbidden requirement for category IV: {$req['title']}");
                        break;
                    }
                }
                
                if ($isForbidden) {
                    continue; // Пропускаем это требование
                }
            }
            
            $requirement = new Requirement();
            $requirement->client_id = $client->id;
            $requirement->title = $req['title'];
            $requirement->basis = $req['basis'] ?? null;
            $requirement->setArtifactsArray($req['artifacts'] ?? []);
            $requirement->document_year = $req['document_year'] ?? date('Y');
            $requirement->deadline = $req['deadline'] ?? null;
            $requirement->status = Requirement::STATUS_PENDING;
            if ($requirement->save()) {
                $createdRequirements[] = $requirement;
                Yii::info("Created requirement: {$req['title']}");
            } else {
                Yii::error("Failed to save requirement '{$req['title']}': " . json_encode($requirement->errors));
            }
        }

        Yii::info("RequirementGeneratorService: Created " . count($createdRequirements) . " requirements for client_id={$client->id}, category_id={$categoryId}, has_well=" . ($client->has_well ? 'true' : 'false') . ", has_river=" . ($client->has_river ? 'true' : 'false') . ", has_byproduct=" . ($client->has_byproduct ? 'true' : 'false'));

        return $createdRequirements;
    }

    /**
     * Получить требования по категории НВОС на основе матрицы из критериев
     *
     * @param int $categoryId (1=I, 2=II, 3=III, 4=IV)
     * @return array
     */
    private static function getNvosRequirements(int $categoryId): array
    {
        // Полный список требований с названиями, основаниями и артефактами
        $allRequirements = [
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
                'basis' => 'ФЗ-7, приказы РПН (ПЭК)',
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
                'basis' => 'ФЗ-7, приказы РПН (ПЭК)',
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

        // Матрица требований по категориям (из критериев)
        // Для IV категории: только [1, 3, 4, 8, 9, 10, 21, 22] - 8 требований
        // НЕ должны быть: 2, 5, 6, 12, 13, 15, 16, 17, 18, 19, 20
        $categoryMatrix = [
            1 => [1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 13, 15, 16, 17, 18, 20, 21, 22], // I
            2 => [1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 13, 15, 16, 17, 18, 19, 21, 22], // II
            3 => [1, 2, 3, 4, 5, 6, 8, 9, 10, 14, 15, 16, 17, 18, 21, 22], // III
            4 => [1, 3, 4, 8, 9, 10, 21, 22], // IV - только 8 требований!
        ];

        $requirements = [];
        $requiredIds = $categoryMatrix[$categoryId] ?? [];
        $currentYear = date('Y');

        Yii::info("getNvosRequirements: category_id={$categoryId}, requiredIds=" . json_encode($requiredIds));
        Yii::info("getNvosRequirements: allRequirements keys=" . json_encode(array_keys($allRequirements)));

        foreach ($requiredIds as $reqId) {
            if (isset($allRequirements[$reqId])) {
                $req = $allRequirements[$reqId];
                $requirements[] = [
                    'title' => $req['title'],
                    'basis' => $req['basis'] ?? null,
                    'artifacts' => $req['artifacts'] ?? [],
                    'deadline' => self::calculateDeadline($reqId),
                    'document_year' => $currentYear,
                ];
                Yii::info("  Added requirement ID {$reqId}: {$req['title']}");
            } else {
                Yii::error("  Requirement ID {$reqId} not found in allRequirements! Available IDs: " . json_encode(array_keys($allRequirements)));
            }
        }

        Yii::info("getNvosRequirements: returning " . count($requirements) . " requirements for category_id={$categoryId}");
        
        // Проверка для III категории - должно быть 16 требований
        if ($categoryId == 3 && count($requirements) != 16) {
            Yii::warning("WARNING: For category III, expected 16 requirements, but got " . count($requirements));
            Yii::warning("Created requirement titles: " . json_encode(array_column($requirements, 'title')));
        }

        return $requirements;
    }

    /**
     * Рассчитать дедлайн для требования
     *
     * @param int $reqId
     * @return string
     */
    private static function calculateDeadline(int $reqId): string
    {
        // Специальные дедлайны для некоторых требований
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

        $days = $specialDeadlines[$reqId] ?? 30; // Базовый дедлайн - через 30 дней
        return date('Y-m-d', strtotime("+{$days} days"));
    }
}


<?php

namespace console\controllers;

use common\models\Client;
use common\models\Requirement;
use common\services\RequirementGeneratorService;
use Yii;
use yii\console\Controller;
use yii\db\Transaction;

/**
 * Контроллер для тестирования генерации требований
 */
class TestRequirementsController extends Controller
{
    /**
     * Тестирование генерации требований для всех категорий и комбинаций параметров
     */
    public function actionTestAll()
    {
        $this->stdout("=== ТЕСТИРОВАНИЕ ГЕНЕРАЦИИ ТРЕБОВАНИЙ ===\n\n");

        // Ожидаемые количества базовых требований по категориям
        $expectedBaseCounts = [
            1 => 18, // I категория
            2 => 18, // II категория
            3 => 16, // III категория
            4 => 8,  // IV категория
        ];

        // Ожидаемые ID требований по категориям (строго по критериям)
        $expectedRequirementIds = [
            1 => [1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 13, 15, 16, 17, 18, 20, 21, 22],
            2 => [1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 13, 15, 16, 17, 18, 19, 21, 22],
            3 => [1, 2, 3, 4, 5, 6, 8, 9, 10, 14, 15, 16, 17, 18, 21, 22],
            4 => [1, 3, 4, 8, 9, 10, 21, 22],
        ];

        // Все комбинации параметров
        $parameterCombinations = [
            ['has_well' => false, 'has_river' => false, 'has_byproduct' => false],
            ['has_well' => true, 'has_river' => false, 'has_byproduct' => false],
            ['has_well' => false, 'has_river' => true, 'has_byproduct' => false],
            ['has_well' => false, 'has_river' => false, 'has_byproduct' => true],
            ['has_well' => true, 'has_river' => true, 'has_byproduct' => false],
            ['has_well' => true, 'has_river' => false, 'has_byproduct' => true],
            ['has_well' => false, 'has_river' => true, 'has_byproduct' => true],
            ['has_well' => true, 'has_river' => true, 'has_byproduct' => true],
        ];

        $totalTests = 0;
        $passedTests = 0;
        $failedTests = 0;
        $errors = [];

        // Тестируем каждую категорию
        foreach ([1, 2, 3, 4] as $categoryId) {
            $this->stdout("\n--- КАТЕГОРИЯ {$categoryId} ---\n");

            // Тестируем каждую комбинацию параметров
            foreach ($parameterCombinations as $params) {
                $totalTests++;
                
                $expectedBase = $expectedBaseCounts[$categoryId];
                $expectedAdditional = 0;
                if ($params['has_well']) $expectedAdditional++;
                if ($params['has_river']) $expectedAdditional += 2;
                if ($params['has_byproduct']) $expectedAdditional++;
                $expectedTotal = $expectedBase + $expectedAdditional;

                $paramsStr = "well=" . ($params['has_well'] ? 'Y' : 'N') . 
                           ", river=" . ($params['has_river'] ? 'Y' : 'N') . 
                           ", byproduct=" . ($params['has_byproduct'] ? 'Y' : 'N');

                $this->stdout("  Тест: категория {$categoryId}, {$paramsStr}... ");

                try {
                    // Создаем тестового клиента
                    $client = new Client();
                    $client->name = "Тестовый клиент для категории {$categoryId}";
                    $client->category_id = $categoryId;
                    $client->has_well = $params['has_well'];
                    $client->has_river = $params['has_river'];
                    $client->has_byproduct = $params['has_byproduct'];
                    
                    if (!$client->save()) {
                        throw new \Exception("Не удалось создать тестового клиента: " . json_encode($client->errors));
                    }

                    // Генерируем требования
                    $transaction = Yii::$app->db->beginTransaction();
                    try {
                        // Удаляем старые требования
                        Requirement::deleteAll(['client_id' => $client->id]);
                        
                        // Генерируем новые
                        $createdRequirements = RequirementGeneratorService::generateRequirements($client);
                        
                        // Проверяем количество
                        $actualCount = count($createdRequirements);
                        if ($actualCount !== $expectedTotal) {
                            throw new \Exception("Ожидалось {$expectedTotal} требований, создано {$actualCount}");
                        }

                        // Проверяем, что требования действительно сохранены в БД
                        $dbRequirements = Requirement::findAll(['client_id' => $client->id]);
                        if (count($dbRequirements) !== $expectedTotal) {
                            throw new \Exception("В БД сохранено " . count($dbRequirements) . " требований, ожидалось {$expectedTotal}");
                        }

                        // Проверяем базовые требования
                        $allRequirementsDefs = $this->getAllRequirementsDefinitions();
                        $createdTitles = array_column($createdRequirements, 'title');
                        $foundBaseIds = [];
                        
                        foreach ($createdTitles as $title) {
                            foreach ($allRequirementsDefs as $id => $def) {
                                if ($def['title'] === $title) {
                                    $foundBaseIds[] = $id;
                                    break;
                                }
                            }
                        }
                        
                        $expectedBaseIds = $expectedRequirementIds[$categoryId];
                        $missingIds = array_diff($expectedBaseIds, $foundBaseIds);
                        $extraIds = array_diff($foundBaseIds, $expectedBaseIds);
                        
                        if (!empty($missingIds)) {
                            $missingTitles = [];
                            foreach ($missingIds as $id) {
                                $missingTitles[] = $allRequirementsDefs[$id]['title'] ?? "ID {$id}";
                            }
                            throw new \Exception("Отсутствуют требования: " . implode(', ', $missingTitles));
                        }
                        
                        if (!empty($extraIds)) {
                            $extraTitles = [];
                            foreach ($extraIds as $id) {
                                $extraTitles[] = $allRequirementsDefs[$id]['title'] ?? "ID {$id}";
                            }
                            throw new \Exception("Лишние требования: " . implode(', ', $extraTitles));
                        }

                        // Проверяем дополнительные требования
                        $additionalCount = 0;
                        foreach ($createdTitles as $title) {
                            if (stripos($title, 'Лицензия на право пользования недрами') !== false) {
                                if (!$params['has_well']) {
                                    throw new \Exception("Создана лицензия на недра, но has_well=false");
                                }
                                $additionalCount++;
                            }
                            if (stripos($title, 'Решение на право пользования водным объектом') !== false) {
                                if (!$params['has_river']) {
                                    throw new \Exception("Создано решение на водопользование, но has_river=false");
                                }
                                $additionalCount++;
                            }
                            if (stripos($title, 'Договор водопользования') !== false) {
                                if (!$params['has_river']) {
                                    throw new \Exception("Создан договор водопользования, но has_river=false");
                                }
                                $additionalCount++;
                            }
                            if (stripos($title, 'Технические условия') !== false) {
                                if (!$params['has_byproduct']) {
                                    throw new \Exception("Созданы технические условия, но has_byproduct=false");
                                }
                                $additionalCount++;
                            }
                        }
                        
                        if ($additionalCount !== $expectedAdditional) {
                            throw new \Exception("Ожидалось {$expectedAdditional} дополнительных требований, найдено {$additionalCount}");
                        }

                        $transaction->rollBack(); // Откатываем транзакцию, чтобы не засорять БД
                        $client->delete(); // Удаляем тестового клиента
                        
                        $this->stdout("✓ ПРОЙДЕН ({$actualCount} требований)\n");
                        $passedTests++;
                        
                    } catch (\Exception $e) {
                        $transaction->rollBack();
                        $client->delete();
                        throw $e;
                    }
                    
                } catch (\Exception $e) {
                    $this->stdout("✗ ПРОВАЛЕН: {$e->getMessage()}\n");
                    $failedTests++;
                    $errors[] = "Категория {$categoryId}, {$paramsStr}: {$e->getMessage()}";
                }
            }
        }

        // Итоговый отчет
        $this->stdout("\n=== ИТОГОВЫЙ ОТЧЕТ ===\n");
        $this->stdout("Всего тестов: {$totalTests}\n");
        $this->stdout("Пройдено: {$passedTests}\n");
        $this->stdout("Провалено: {$failedTests}\n");
        
        if ($failedTests > 0) {
            $this->stdout("\nОШИБКИ:\n");
            foreach ($errors as $error) {
                $this->stdout("  - {$error}\n");
            }
            return 1;
        } else {
            $this->stdout("\n✓ ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!\n");
            $this->stdout("\nВсе категории (I, II, III, IV) работают правильно со всеми комбинациями параметров.\n");
            return 0;
        }
    }

    /**
     * Детальная проверка одной категории с выводом всех требований
     */
    public function actionTestCategory($categoryId, $hasWell = 0, $hasRiver = 0, $hasByproduct = 0)
    {
        $this->stdout("=== ДЕТАЛЬНАЯ ПРОВЕРКА КАТЕГОРИИ {$categoryId} ===\n");
        $this->stdout("Параметры: well=" . ($hasWell ? 'Y' : 'N') . ", river=" . ($hasRiver ? 'Y' : 'N') . ", byproduct=" . ($hasByproduct ? 'Y' : 'N') . "\n\n");

        $client = new Client();
        $client->name = "Тестовый клиент";
        $client->category_id = (int)$categoryId;
        $client->has_well = (bool)$hasWell;
        $client->has_river = (bool)$hasRiver;
        $client->has_byproduct = (bool)$hasByproduct;
        
        if (!$client->save()) {
            $this->stdout("ОШИБКА: Не удалось создать клиента\n");
            return 1;
        }

        $transaction = Yii::$app->db->beginTransaction();
        try {
            Requirement::deleteAll(['client_id' => $client->id]);
            $requirements = RequirementGeneratorService::generateRequirements($client);
            
            $this->stdout("Создано требований: " . count($requirements) . "\n\n");
            $this->stdout("СПИСОК ТРЕБОВАНИЙ:\n");
            foreach ($requirements as $idx => $req) {
                $this->stdout(sprintf("%2d. %s\n", $idx + 1, $req->title));
            }
            
            $transaction->rollBack();
            $client->delete();
            
        } catch (\Exception $e) {
            $transaction->rollBack();
            $client->delete();
            $this->stdout("ОШИБКА: {$e->getMessage()}\n");
            return 1;
        }

        return 0;
    }

    /**
     * Получить определения всех требований (копия из RequirementGeneratorService)
     */
    private function getAllRequirementsDefinitions(): array
    {
        return [
            1 => ['title' => 'Журналы учета движения отходов производства и потребления'],
            2 => ['title' => 'Журналы учета стационарных источников выбросов и их характеристик'],
            3 => ['title' => 'Статотчетность по форме 2-ТП (воздух), при условии суммарного выброса более 5 тонн/год'],
            4 => ['title' => 'Статотчетность по форме 2-ТП (отходы), при условии образования отходов более 100 кг'],
            5 => ['title' => 'Декларация о плате за негативное воздействие на окружающую среду'],
            6 => ['title' => 'Отчет по программе производственного экологического контроля (ПЭК)'],
            8 => ['title' => 'Отчет инвентаризации выбросов вредных (загрязняющих) веществ в атмосферу'],
            9 => ['title' => 'Отчет инвентаризации отходов производства и потребления'],
            10 => ['title' => 'Паспорта на отходы I-IV класса опасности'],
            12 => ['title' => 'Нормативы образования отходов и лимиты на их размещение (НООЛР)'],
            13 => ['title' => 'Нормативы допустимых выбросов (НДВ)'],
            14 => ['title' => 'Нормативы допустимых выбросов для радиоактивных, высокотоксичных веществ, веществ, обладающих канцерогенными, мутагенными свойствами (веществ I, II класса опасности)'],
            15 => ['title' => 'Экспертное заключение (протокола) санитарно-эпидемиологической экспертизы на проект НДВ'],
            16 => ['title' => 'Санитарно-эпидемиологическое заключение на проект НДВ в Управление Федеральной службы по надзору в сфере защиты прав потребителей и благополучия человека (Роспотребнадзоре)'],
            17 => ['title' => 'План мероприятий неблагоприятных метеорологических условий (НМУ)'],
            18 => ['title' => 'Программа производственного экологического контроля (ППЭК)'],
            19 => ['title' => 'Декларация о воздействии на окружающую среду (ДВОС) для объектов II категории'],
            20 => ['title' => 'Комплексное экологическое разрешение (КЭР) для объектов I категории'],
            21 => ['title' => 'Проект санитарно-защитной зоны (СЗЗ)'],
            22 => ['title' => 'Решение об установлении санитарно-защитной зоны'],
        ];
    }
}

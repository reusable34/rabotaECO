<?php
header('Content-Type: application/json');

$status = [
    'status' => 'ok',
    'timestamp' => date('c'),
    'service' => 'eco-backend-api',
];

// Простая проверка без полной инициализации Yii2
try {
    // Проверка существования файлов конфигурации
    if (!file_exists(__DIR__ . '/../../common/config/main.php')) {
        throw new Exception('Config file not found');
    }
    
    // Проверка подключения к БД через простой PDO
    $dbHost = getenv('DB_HOST') ?: 'db';
    $dbName = getenv('DB_NAME') ?: 'eco_client';
    $dbUser = getenv('DB_USER') ?: 'eco_admin';
    $dbPassword = getenv('DB_PASSWORD') ?: 'eco_pass';
    
    // Используем правильное имя базы данных из переменной окружения
    if (empty($dbName) || $dbName === 'eco_admin') {
        $dbName = 'eco_client'; // Правильное имя БД
    }
    
    $dsn = "pgsql:host={$dbHost};dbname={$dbName}";
    $pdo = new PDO($dsn, $dbUser, $dbPassword);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->query('SELECT 1');
    
    $status['database'] = 'connected';
} catch (\Exception $e) {
    $status['status'] = 'error';
    $status['database'] = 'disconnected';
    $status['error'] = $e->getMessage();
    http_response_code(503);
}

echo json_encode($status, JSON_PRETTY_PRINT);


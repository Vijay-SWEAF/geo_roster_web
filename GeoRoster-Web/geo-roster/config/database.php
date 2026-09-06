<?php

$privateConfig = dirname(__DIR__) . '/../georoster-config/database.php';
if (is_file($privateConfig)) {
    require $privateConfig;
}

$host = $host ?? getenv('GEOROSTER_DB_HOST') ?: 'localhost';
$dbname = $dbname ?? getenv('GEOROSTER_DB_NAME') ?: 'attendance_db';
$username = $username ?? getenv('GEOROSTER_DB_USER') ?: '';
$password = $password ?? getenv('GEOROSTER_DB_PASSWORD') ?: '';

if ($username === '' || $password === '') {
    error_log('GeoRoster database credentials are not configured.');
    http_response_code(503);
    exit('Database service is unavailable.');
}

$conn = new mysqli($host, $username, $password, $dbname);

/* Check connection */
if ($conn->connect_error) {
    error_log("Database connection failed: " . $conn->connect_error);
    exit("Database service is unavailable.");
}

/* Set charset */
$conn->set_charset("utf8mb4");
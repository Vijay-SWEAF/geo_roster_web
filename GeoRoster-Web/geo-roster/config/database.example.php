<?php

// Copy this file outside the public web root or provide these values as environment variables.
$host = getenv('GEOROSTER_DB_HOST') ?: 'localhost';
$dbname = getenv('GEOROSTER_DB_NAME') ?: 'attendance_db';
$username = getenv('GEOROSTER_DB_USER') ?: '';
$password = getenv('GEOROSTER_DB_PASSWORD') ?: '';
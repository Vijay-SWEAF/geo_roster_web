<?php

require_once __DIR__ . '/security.php';
startSecureSession();
applySecurityHeaders();

if (!isset($_SESSION["user_id"])) {
    header("Location: auth/login.php");
    exit;
}
<?php
require_once "includes/security.php";
startSecureSession();
applySecurityHeaders();

/* Unset all session variables */
$_SESSION = [];

/* Destroy session cookie */
if (ini_get("session.use_cookies")) {
    $params = session_get_cookie_params();
    setcookie(
        session_name(),
        '',
        [
            'expires' => time() - 42000,
            'path' => $params['path'] ?? '/',
            'domain' => $params['domain'] ?? '',
            'secure' => $params['secure'] ?? false,
            'httponly' => $params['httponly'] ?? true,
            'samesite' => $params['samesite'] ?? 'Lax'
        ]
    );
}

/* Destroy session */
session_destroy();

/* Redirect to login */
header("Location: auth/login.php");
exit;
?>
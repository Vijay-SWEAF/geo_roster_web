<?php
require_once "../includes/auth_check.php";
require_once "../config/database.php";
requirePostWithCsrf();

$user_role = $_SESSION["role"] ?? "";

if ($user_role !== "Admin") {
    $_SESSION["flash_error"] = "Access denied.";
    header("Location: ../dashboard.php");
    exit;
}

$user_id = isset($_POST["id"]) ? (int)$_POST["id"] : 0;

if ($user_id <= 0) {
    $_SESSION["flash_error"] = "Invalid user.";
    header("Location: ../admin/user_management.php");
    exit;
}

/* Generate a one-time temporary password without predictable randomness. */
$temp_password = rtrim(strtr(base64_encode(random_bytes(12)), '+/', '-_'), '=');

/* Hash password */
$password_hash = password_hash($temp_password, PASSWORD_DEFAULT);

/* Update */
$update_stmt = $conn->prepare("UPDATE users SET password_hash = ? WHERE user_id = ?");
$update_stmt->bind_param("si", $password_hash, $user_id);
$update = $update_stmt->execute();

if ($update) {
    $_SESSION["flash_message"] = "Password reset successfully. Temporary password: " . htmlspecialchars($temp_password, ENT_QUOTES, 'UTF-8');
    auditEvent($conn, "password_reset", "user", $user_id);
} else {
    $_SESSION["flash_error"] = "Failed to reset password.";
}

header("Location: ../admin/user_management.php");
exit;
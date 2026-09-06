<?php

require_once "includes/auth_check.php";
require_once "config/database.php";

requirePostWithCsrf();

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    header("Location: profile.php");
    exit;
}

$user_id = $_SESSION["user_id"];

$current_password = trim($_POST["current_password"] ?? "");
$new_password = trim($_POST["new_password"] ?? "");
$confirm_password = trim($_POST["confirm_password"] ?? "");

if ($current_password === "" || $new_password === "" || $confirm_password === "") {
    $_SESSION["flash_error"] = "All password fields are required.";
    header("Location: change_password.php");
    exit;
}

if ($new_password !== $confirm_password) {
    $_SESSION["flash_error"] = "New passwords do not match.";
    header("Location: change_password.php");
    exit;
}

if (strlen($new_password) < 10) {
    $_SESSION["flash_error"] = "New password must be at least 10 characters.";
    header("Location: change_password.php");
    exit;
}

if ($current_password === $new_password) {
    $_SESSION["flash_error"] = "New password must be different from current password.";
    header("Location: change_password.php");
    exit;
}

/* Fetch stored password */
$stmt = $conn->prepare("SELECT password_hash FROM users WHERE user_id = ? LIMIT 1");
$stmt->bind_param("i", $user_id);
$stmt->execute();
$result = $stmt->get_result();

if (!$result || $result->num_rows === 0) {
    $_SESSION["flash_error"] = "User not found.";
    header("Location: change_password.php");
    exit;
}

$user = $result->fetch_assoc();
$stored_password = $user["password_hash"] ?? "";

/* Support both old plain-text and new hashed passwords */
$is_valid_password = false;

if ($stored_password !== "" && password_verify($current_password, $stored_password)) {
    $is_valid_password = true;
} elseif ($stored_password !== "" && hash_equals($stored_password, $current_password)) {
    $is_valid_password = true;
}

if (!$is_valid_password) {
    $_SESSION["flash_error"] = "Current password is incorrect.";
    header("Location: change_password.php");
    exit;
}

/* Save new password as proper hash */
$new_hash = password_hash($new_password, PASSWORD_DEFAULT);

$update = $conn->prepare("UPDATE users SET password_hash = ? WHERE user_id = ?");
$update->bind_param("si", $new_hash, $user_id);

if ($update->execute()) {
    auditEvent($conn, "password_changed", "user", $user_id);
    $_SESSION["flash_message"] = "Password updated successfully.";
    header("Location: profile.php");
    exit;
} else {
    $_SESSION["flash_error"] = "Unable to update password.";
    header("Location: change_password.php");
    exit;
}
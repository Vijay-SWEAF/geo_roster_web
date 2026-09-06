<?php
require_once "../includes/auth_check.php";
require_once "../config/database.php";
require_once "../includes/security.php";
requirePostWithCsrf();

$user_role = $_SESSION["role"] ?? "";

if ($user_role !== "Admin") {
    $_SESSION["flash_error"] = "Access denied.";
    header("Location: ../dashboard.php");
    exit;
}

$full_name = trim($_POST["full_name"] ?? "");
$username = trim($_POST["username"] ?? "");
$password = trim($_POST["password"] ?? "");
$role_name = trim($_POST["role_name"] ?? "");
$branch_id = trim($_POST["branch_id"] ?? "");
$is_active = isset($_POST["is_active"]) ? (int)$_POST["is_active"] : 1;

if (!in_array($role_name, ["Admin", "HO User", "Branch User"], true) || !in_array($is_active, [0, 1], true)) {
    $_SESSION["flash_error"] = "Invalid user values.";
    header("Location: user_management.php");
    exit;
}

if ($full_name === "" || $username === "" || $password === "" || $role_name === "") {
    $_SESSION["flash_error"] = "All required fields must be filled.";
    header("Location: ../admin/user_management.php");
    exit;
}

if (($role_name === "Branch User" || $role_name === "HO User") && $branch_id === "") {
    $_SESSION["flash_error"] = "Branch is required for selected role.";
    header("Location: user_management.php");
    exit;
}

if ($role_name === "Admin") {
    $branch_id_sql = "NULL";
} else {
    $branch_id_sql = (int)$branch_id;
}

$check_stmt = $conn->prepare("SELECT user_id FROM users WHERE username = ? LIMIT 1");
$check_stmt->bind_param("s", $username);
$check_stmt->execute();
$check = $check_stmt->get_result();

if ($check && $check->num_rows > 0) {
    $_SESSION["flash_error"] = "Username already exists.";
    header("Location: user_management.php");
    exit;
}

$password_hash = password_hash($password, PASSWORD_DEFAULT);

$stmt = $conn->prepare("INSERT INTO users (full_name, username, password_hash, role_name, branch_id, is_active) VALUES (?, ?, ?, ?, ?, ?)");
$branch_id_value = $role_name === "Admin" ? null : (int)$branch_id;
$stmt->bind_param("ssssii", $full_name, $username, $password_hash, $role_name, $branch_id_value, $is_active);
if ($stmt->execute()) {
    $_SESSION["flash_message"] = "User created successfully.";
    auditEvent($conn, "user_created", "user", $stmt->insert_id);
} else {
    $_SESSION["flash_error"] = "Failed to create user.";
}

header("Location: user_management.php");
exit;
?>
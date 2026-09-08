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

$user_id = isset($_POST["id"]) ? (int)$_POST["id"] : 0;
$new_status = isset($_POST["status"]) ? (int)$_POST["status"] : -1;

if ($user_id <= 0 || !in_array($new_status, [0, 1])) {
    $_SESSION["flash_error"] = "Invalid request.";
    header("Location: ../admin/user_management.php");
    exit;
}

/* Prevent deactivating last Admin */
if ($new_status === 0) {

    $check_admin = $conn->query("
        SELECT COUNT(*) AS total_admins
        FROM users
        WHERE role_name = 'Admin' AND is_active = 1
    ");

    $row = $check_admin->fetch_assoc();
    $active_admins = (int)($row["total_admins"] ?? 0);

    $target_user_stmt = $conn->prepare("SELECT role_name FROM users WHERE user_id = ? LIMIT 1");
    $target_user_stmt->bind_param("i", $user_id);
    $target_user_stmt->execute();
    $target_user = $target_user_stmt->get_result();

    if ($target_user && $target_user->num_rows > 0) {
        $user_data = $target_user->fetch_assoc();

        if ($user_data["role_name"] === "Admin" && $active_admins <= 1) {
            $_SESSION["flash_error"] = "Cannot deactivate last Admin user.";
            header("Location: ../admin/user_management.php");
            exit;
        }
    }
}

/* Update status */
$update_stmt = $conn->prepare("UPDATE users SET is_active = ? WHERE user_id = ?");
$update_stmt->bind_param("ii", $new_status, $user_id);
$update = $update_stmt->execute();

if ($update) {
    $_SESSION["flash_message"] = "User status updated.";
    auditEvent($conn, "user_status_changed", "user", $user_id, ["active" => $new_status]);
} else {
    $_SESSION["flash_error"] = "Failed to update user.";
}

header("Location: ../admin/user_management.php");
exit;
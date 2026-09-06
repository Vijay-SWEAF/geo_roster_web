<?php
require_once "../includes/auth_check.php";
require_once "../config/database.php";
require_once "../includes/security.php";
requirePostWithCsrf();

if ($_SESSION["role"] != "Admin" && $_SESSION["role"] != "HO User") {
    $_SESSION["flash_error"] = "Access denied.";
    header("Location: ../dashboard.php");
    exit;
}

$employee_id = isset($_POST["id"]) ? (int)$_POST["id"] : 0;
$action = $_POST["action"] ?? "";

if ($employee_id <= 0 || !in_array($action, ["activate", "deactivate"])) {
    $_SESSION["flash_error"] = "Invalid request.";
    header("Location: employees.php");
    exit;
}

$new_status = ($action === "activate") ? 1 : 0;

$update_stmt = $conn->prepare("UPDATE employees SET is_active = ? WHERE employee_id = ?");
$update_stmt->bind_param("ii", $new_status, $employee_id);
$update = $update_stmt->execute();

if ($update) {
    $_SESSION["flash_message"] = "Employee status updated successfully.";
    auditEvent($conn, "employee_status_changed", "employee", $employee_id, ["active" => $new_status]);
} else {
    $_SESSION["flash_error"] = "Failed to update employee status.";
}

header("Location: employees.php");
exit;
?>
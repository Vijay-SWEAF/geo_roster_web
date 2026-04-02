<?php
require_once "../includes/auth_check.php";
require_once "../config/database.php";

if ($_SESSION["role"] != "Admin" && $_SESSION["role"] != "HO User") {
    $_SESSION["flash_error"] = "Access denied.";
    header("Location: ../dashboard.php");
    exit;
}

$employee_id = isset($_GET["id"]) ? (int)$_GET["id"] : 0;
$action = $_GET["action"] ?? "";

if ($employee_id <= 0 || !in_array($action, ["activate", "deactivate"])) {
    $_SESSION["flash_error"] = "Invalid request.";
    header("Location: employees.php");
    exit;
}

$new_status = ($action === "activate") ? 1 : 0;

$update = $conn->query("
    UPDATE employees
    SET is_active = $new_status
    WHERE employee_id = $employee_id
");

if ($update) {
    $_SESSION["flash_message"] = "Employee status updated successfully.";
} else {
    $_SESSION["flash_error"] = "Failed to update employee status.";
}

header("Location: employees.php");
exit;
?>
<?php
require_once "includes/auth_check.php";

$role = $_SESSION["role"];
$full_name = $_SESSION["full_name"];

define('APP_INCLUDED', true);

$pageTitle = "Dashboard";
$pageSubtitle = "Welcome, " . $full_name . ". Access your modules based on role.";
$basePath = "";

require_once "includes/header.php";
?>

<div class="cards">

<?php if ($role == "Admin") { ?>

    <a class="card" href="admin/branches.php">
        <div class="card-icon">🏢</div>
        Branch Master
    </a>

    <a class="card" href="admin/employees.php">
        <div class="card-icon">👥</div>
        Employee Master
    </a>

    <a class="card" href="admin/branch_locations.php">
        <div class="card-icon">📍</div>
        Sub-Location Master
    </a>

    <a class="card" href="attendance_entry.php">
        <div class="card-icon">🕘</div>
        Attendance Entry
    </a>

    <a class="card" href="monthly_register.php">
        <div class="card-icon">📅</div>
        Monthly Register
    </a>

    <a class="card" href="payroll_sheet.php">
        <div class="card-icon">📊</div>
        Payroll Sheet
    </a>

    <a class="card" href="admin/leave_entry.php">
        <div class="card-icon">📝</div>
        Leave Entry
    </a>

    <a class="card" href="admin/leave_policy.php">
        <div class="card-icon">⚙️</div>
        Leave Policy
    </a>

    <a class="card" href="leave_balance.php">
        <div class="card-icon">📈</div>
        Leave Balance
    </a>

<a class="card" href="management_dashboard.php">
    <div class="card-icon">📈</div>
    Management Dashboard
</a>

<a class="card" href="admin/user_management.php">
    <div class="card-icon">👤</div>
    User Management
</a>

<?php } elseif ($role == "Branch User") { ?>

    <a class="card" href="attendance_entry.php">
        <div class="card-icon">🕘</div>
        Attendance Entry
    </a>

    <a class="card" href="monthly_register.php">
        <div class="card-icon">📅</div>
        Monthly Register
    </a>
    
    <a class="card" href="payroll_sheet.php">
        <div class="card-icon">📊</div>
        Payroll Sheet
    </a>

<?php } elseif ($role == "HO User") { ?>

    <a class="card" href="admin/employees.php">
        <div class="card-icon">👥</div>
        Employee Master
    </a>

    <a class="card" href="attendance_entry.php">
        <div class="card-icon">🕘</div>
        Attendance Entry
    </a>

    <a class="card" href="monthly_register.php">
        <div class="card-icon">📅</div>
        Monthly Register
    </a>

    <a class="card" href="payroll_sheet.php">
        <div class="card-icon">📊</div>
        Payroll Sheet
    </a>

    <a class="card" href="leave_balance.php">
        <div class="card-icon">📈</div>
        Leave Balance
    </a>
    
    <a class="card" href="management_dashboard.php">
    <div class="card-icon">📈</div>
    Management Dashboard
</a>

<?php } ?>

</div>

<?php require_once "includes/footer.php"; ?>
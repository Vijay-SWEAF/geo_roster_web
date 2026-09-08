<?php
if (!defined('APP_INCLUDED')) {
    http_response_code(403);
    exit('Forbidden');
}

require_once __DIR__ . '/security.php';
startSecureSession();
applySecurityHeaders();

if (!isset($pageTitle)) {
    $pageTitle = "GeoRoster Attendance";
}

if (!isset($pageSubtitle)) {
    $pageSubtitle = "";
}

$role = isset($_SESSION["role"]) ? $_SESSION["role"] : "";
$full_name = isset($_SESSION["full_name"]) ? $_SESSION["full_name"] : "";

$basePath = isset($basePath) ? $basePath : "";

function roleBadgeClassLayout($role) {
    if ($role == "Admin") return "badge-admin";
    if ($role == "Branch User") return "badge-branch";
    if ($role == "HO User") return "badge-ho";
    return "";
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo htmlspecialchars($pageTitle); ?></title>
    <link rel="icon" type="image/png" href="<?php echo $basePath; ?>assets/img/geo-roster.png">
    <link rel="stylesheet" href="<?php echo $basePath; ?>assets/css/main.css">
</head>
<body>

<div class="topbar">
    <a href="<?php echo $basePath; ?>dashboard.php" class="brand">
        <img src="<?php echo $basePath; ?>assets/img/geo-roster.png" alt="GeoRoster Logo">
        <div class="brand-title">GeoRoster Attendance</div>
    </a>

    <div class="topbar-right">

    <!-- Licensed Text -->
    <span style="font-size:12px; color:#64748b; margin-right:10px; white-space:nowrap;">
    Licensed to Surge Marine Services
</span>
<span style="margin:0 6px; color:#cbd5e1;">|</span>

    <?php if (!empty($full_name)) { ?>
        <span><?php echo htmlspecialchars($full_name); ?></span>
    <?php } ?>

    <?php if (!empty($role)) { ?>
        <span class="role-badge <?php echo roleBadgeClassLayout($role); ?>">
            <?php echo htmlspecialchars($role); ?>
        </span>
    <?php } ?>

    <?php if (isset($_SESSION["user_id"])) { ?>
        <a class="profile-btn" href="<?php echo $basePath; ?>profile.php">Profile</a>
        <a class="logout-btn" href="<?php echo $basePath; ?>logout.php">Logout</a>
    <?php } ?>

</div>
</div>

<div class="page-container">
    <div class="content-card <?php echo isset($pageContentClass) ? htmlspecialchars($pageContentClass) : ''; ?>">
        <div class="page-title"><?php echo htmlspecialchars($pageTitle); ?></div>
        <?php if (!empty($pageSubtitle)) { ?>
            <div class="page-subtitle"><?php echo htmlspecialchars($pageSubtitle); ?></div>
        <?php } ?>
        
        <?php if (!empty($_SESSION["flash_message"])) { ?>
    <div class="flash-message flash-success">
        <?php
            echo htmlspecialchars($_SESSION["flash_message"]);
            unset($_SESSION["flash_message"]);
        ?>
    </div>
<?php } ?>

<?php if (!empty($_SESSION["flash_error"])) { ?>
    <div class="flash-message flash-error">
        <?php
            echo htmlspecialchars($_SESSION["flash_error"]);
            unset($_SESSION["flash_error"]);
        ?>
    </div>
<?php } ?>
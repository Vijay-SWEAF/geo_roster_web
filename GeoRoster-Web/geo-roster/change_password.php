<?php
require_once "includes/auth_check.php";
require_once "config/database.php";

$pageTitle = "Change Password";
$pageSubtitle = "Update your account password securely.";
$basePath = "";
$pageContentClass = "profile-page-card";

define('APP_INCLUDED', true);
require_once "includes/header.php";
?>

<div class="panel-card profile-card">
    <div class="panel-title">Change Password</div>

    <form method="post" action="update_password.php" class="form-grid">
        <?php echo csrfField(); ?>

        <div>
            <label for="current_password">Current Password</label>
            <input type="password" id="current_password" name="current_password" required>
        </div>

        <div>
            <label for="new_password">New Password</label>
            <input type="password" id="new_password" name="new_password" required>
        </div>

        <div>
            <label for="confirm_password">Confirm New Password</label>
            <input type="password" id="confirm_password" name="confirm_password" required>
        </div>

        <div class="form-actions">
            <button type="submit">Update Password</button>
            <a href="profile.php" class="btn-secondary-link">Cancel</a>
        </div>

    </form>
</div>

<?php require_once "includes/footer.php"; ?>
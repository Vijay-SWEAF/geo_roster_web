<?php
require_once "includes/auth_check.php";
require_once "config/database.php";

$user_id = $_SESSION["user_id"];

$stmt = $conn->prepare("SELECT full_name, username, role_name FROM users WHERE user_id = ? LIMIT 1");
$stmt->bind_param("i", $user_id);
$stmt->execute();
$result = $stmt->get_result();

$user = $result->fetch_assoc();

$pageTitle = "My Profile";
$pageSubtitle = "View your account details.";
$basePath = "";
$pageContentClass = "profile-page-card";

define('APP_INCLUDED', true);
require_once "includes/header.php";
?>

<div class="panel-card profile-card">

<div class="panel-title">Profile Information</div>

<table style="max-width:500px;">
<tr>
    <th>Name</th>
    <td><?php echo htmlspecialchars($user["full_name"]); ?></td>
</tr>

<tr>
    <th>Username</th>
    <td><?php echo htmlspecialchars($user["username"]); ?></td>
</tr>

<tr>
    <th>Role</th>
    <td><?php echo htmlspecialchars($user["role_name"]); ?></td>
</tr>
</table>

<br>

<div class="form-actions">
    <a href="change_password.php" class="btn-generate">Change Password</a>
    <a href="dashboard.php" class="btn-cancel">Cancel</a>
</div>

</div>

<?php require_once "includes/footer.php"; ?>
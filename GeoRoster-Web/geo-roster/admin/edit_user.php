<?php
require_once "../includes/auth_check.php";
require_once "../config/database.php";
require_once "../includes/security.php";

$user_role = $_SESSION["role"] ?? "";

if ($user_role !== "Admin") {
    $_SESSION["flash_error"] = "Access denied.";
    header("Location: ../dashboard.php");
    exit;
}

$user_id = isset($_GET["id"]) ? (int)$_GET["id"] : 0;

if ($user_id <= 0) {
    $_SESSION["flash_error"] = "Invalid user.";
    header("Location: ../admin/user_management.php");
    exit;
}

/* Fetch user */
$user_q_stmt = $conn->prepare("SELECT user_id, full_name, username, role_name, branch_id, is_active FROM users WHERE user_id = ? LIMIT 1");
$user_q_stmt->bind_param("i", $user_id);
$user_q_stmt->execute();
$user_q = $user_q_stmt->get_result();

if (!$user_q || $user_q->num_rows === 0) {
    $_SESSION["flash_error"] = "User not found.";
    header("Location: ../admin/user_management.php");
    exit;
}

$user = $user_q->fetch_assoc();

/* Fetch branches */
$branches = $conn->query("
    SELECT branch_id, branch_name
    FROM branches
    ORDER BY branch_name
");

/* Handle POST */
if ($_SERVER["REQUEST_METHOD"] === "POST") {
    requireCsrf();

    $full_name = trim($_POST["full_name"] ?? "");
    $role_name = trim($_POST["role_name"] ?? "");
    $branch_id = trim($_POST["branch_id"] ?? "");
    $is_active = isset($_POST["is_active"]) ? (int)$_POST["is_active"] : 1;

    if ($full_name === "" || !in_array($role_name, ["Admin", "HO User", "Branch User"], true) || !in_array($is_active, [0, 1], true)) {
        $_SESSION["flash_error"] = "Required fields missing.";
        header("Location: edit_user.php?id=$user_id");
        exit;
    }

    if (($role_name === "Branch User" || $role_name === "HO User") && $branch_id === "") {
        $_SESSION["flash_error"] = "Branch is required.";
        header("Location: edit_user.php?id=$user_id");
        exit;
    }

    if ($role_name === "Admin") {
        $branch_id_sql = "NULL";
    } else {
        $branch_id_sql = (int)$branch_id;
    }

    /* Prevent removing last Admin */
    if ($user["role_name"] === "Admin" && $role_name !== "Admin") {
        $check_admin = $conn->query("
            SELECT COUNT(*) AS total_admins
            FROM users
            WHERE role_name = 'Admin' AND is_active = 1
        ");

        $row = $check_admin->fetch_assoc();
        if ((int)$row["total_admins"] <= 1) {
            $_SESSION["flash_error"] = "Cannot remove last Admin.";
            header("Location: edit_user.php?id=$user_id");
            exit;
        }
    }

    $stmt = $conn->prepare("UPDATE users SET full_name = ?, role_name = ?, branch_id = ?, is_active = ? WHERE user_id = ?");
    $branch_id_value = $role_name === "Admin" ? null : (int)$branch_id;
    $stmt->bind_param("sssii", $full_name, $role_name, $branch_id_value, $is_active, $user_id);
    if ($stmt->execute()) {
        $_SESSION["flash_message"] = "User updated successfully.";
        auditEvent($conn, "user_updated", "user", $user_id);
        header("Location: ../admin/user_management.php");
        exit;
    } else {
        $_SESSION["flash_error"] = "Update failed.";
        header("Location: edit_user.php?id=$user_id");
        exit;
    }
}

$pageTitle = "Edit User";
$pageSubtitle = "Modify user details.";
$basePath = "../";

define('APP_INCLUDED', true);
require_once "../includes/header.php";
?>

<div class="panel-card">

    <div class="panel-title">Edit User</div>

    <form method="post" class="form-grid">
        <?php echo csrfField(); ?>

        <div class="top-filters-flex">
            <div class="filter-box">
                <label>Full Name</label>
                <input type="text" name="full_name" value="<?php echo htmlspecialchars($user["full_name"]); ?>" required>
            </div>

            <div class="filter-box">
                <label>Username</label>
                <input type="text" value="<?php echo htmlspecialchars($user["username"]); ?>" disabled>
            </div>
        </div>

        <div class="top-filters-flex">
            <div class="filter-box">
                <label>Role</label>
                <select name="role_name" id="role_name" required>
                    <option value="Admin" <?php if ($user["role_name"]=="Admin") echo "selected"; ?>>Admin</option>
                    <option value="HO User" <?php if ($user["role_name"]=="HO User") echo "selected"; ?>>HO User</option>
                    <option value="Branch User" <?php if ($user["role_name"]=="Branch User") echo "selected"; ?>>Branch User</option>
                </select>
            </div>

            <div class="filter-box">
                <label>Branch</label>
                <select name="branch_id" id="branch_id">
                    <option value="">Select Branch</option>
                    <?php while ($b = $branches->fetch_assoc()) { ?>
                        <option value="<?php echo $b["branch_id"]; ?>"
                            <?php if ($user["branch_id"] == $b["branch_id"]) echo "selected"; ?>>
                            <?php echo htmlspecialchars($b["branch_name"]); ?>
                        </option>
                    <?php } ?>
                </select>
            </div>

            <div class="filter-box">
                <label>Status</label>
                <select name="is_active">
                    <option value="1" <?php if ($user["is_active"]==1) echo "selected"; ?>>Active</option>
                    <option value="0" <?php if ($user["is_active"]==0) echo "selected"; ?>>Inactive</option>
                </select>
            </div>
        </div>

        <div class="form-actions">
            <button type="submit" class="btn-generate">Update</button>
            <a href="../admin/user_management.php" class="btn-cancel">Cancel</a>
        </div>

    </form>
</div>

<script>
document.addEventListener("DOMContentLoaded", function () {
    const role = document.getElementById("role_name");
    const branch = document.getElementById("branch_id");

    function toggle() {
        if (role.value === "Branch User" || role.value === "HO User") {
            branch.required = true;
        } else {
            branch.required = false;
            branch.value = "";
        }
    }

    role.addEventListener("change", toggle);
    toggle();
});
</script>

<?php require_once "../includes/footer.php"; ?>
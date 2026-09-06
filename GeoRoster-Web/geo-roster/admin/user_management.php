<?php
require_once "../includes/auth_check.php";
require_once "../config/database.php";
require_once "../includes/security.php";
require_once "../includes/kyc_service.php";

$user_role = $_SESSION["role"] ?? "";

if ($user_role !== "Admin") {
    $_SESSION["flash_error"] = "Access denied.";
    header("Location: ../dashboard.php");
    exit;
}

$branches = $conn->query("
    SELECT branch_id, branch_name
    FROM branches
    ORDER BY branch_name
");

$users = $conn->query("
    SELECT 
        u.user_id,
        u.full_name,
        u.username,
        u.role_name,
        u.branch_id,
        b.branch_name,
        u.is_active,
        u.created_at,
        COALESCE(p.is_active, 0) AS kyc_officer_active
    FROM users u
    LEFT JOIN branches b ON u.branch_id = b.branch_id
    LEFT JOIN user_kyc_permissions p
        ON p.user_id = u.user_id AND p.permission_code = 'KYC_OFFICER'
    ORDER BY u.user_id DESC
");

$pageTitle = "User Management";
$pageSubtitle = "Create and manage application users.";
$basePath = "../";

define('APP_INCLUDED', true);
require_once "../includes/header.php";
?>

<div class="panel-card" style="margin-bottom:18px;">
    <div class="panel-title">Create User</div>

    <form method="post" action="create_user.php" class="form-grid">
        <?php echo csrfField(); ?>
        <div class="top-filters-flex">
            <div class="filter-box">
                <label for="full_name">Full Name</label>
                <input type="text" id="full_name" name="full_name" required>
            </div>

            <div class="filter-box">
                <label for="username">Username</label>
                <input type="text" id="username" name="username" required>
            </div>

            <div class="filter-box">
                <label for="password">Password</label>
                <input type="password" id="password" name="password" required>
            </div>
        </div>

        <div class="top-filters-flex">
            <div class="filter-box">
                <label for="role_name">Role</label>
                <select id="role_name" name="role_name" required>
                    <option value="">Select Role</option>
                    <option value="Admin">Admin</option>
                    <option value="HO User">HO User</option>
                    <option value="Branch User">Branch User</option>
                </select>
            </div>

            <div class="filter-box">
                <label for="branch_id">Branch</label>
                <select id="branch_id" name="branch_id">
                    <option value="">Select Branch</option>
                    <?php while ($b = $branches->fetch_assoc()) { ?>
                        <option value="<?php echo $b["branch_id"]; ?>">
                            <?php echo htmlspecialchars($b["branch_name"]); ?>
                        </option>
                    <?php } ?>
                </select>
            </div>

            <div class="filter-box">
                <label for="is_active">Status</label>
                <select id="is_active" name="is_active" required>
                    <option value="1" selected>Active</option>
                    <option value="0">Inactive</option>
                </select>
            </div>
        </div>

        <div class="form-actions">
            <button type="submit" class="btn-generate">Create User</button>
            <a href="../dashboard.php" class="btn-cancel">Cancel</a>
        </div>
    </form>
</div>

<div class="panel-card">
    <div class="panel-title">Existing Users</div>

    <div class="table-wrap">
        <table style="width:100%; table-layout:auto;">
            <thead>
                <tr>
                    <th style="width:30px;">ID</th>
                    <th>Full Name</th>
                    <th>Username</th>
                    <th style="width:140px;">Role</th>
                    <th style="width:120px;">Branch</th>
                    <th style="width:50px;">Active</th>
                    <th style="width:100px;">KYC Officer</th>
                    <th style="width:170px;">Created At</th>
                    <th style="width:120px;">Action</th>
                </tr>
            </thead>
            <tbody>
                <?php while ($u = $users->fetch_assoc()) { ?>
                    <tr>
                        <td><?php echo (int)$u["user_id"]; ?></td>
                        <td><?php echo htmlspecialchars($u["full_name"]); ?></td>
                        <td><?php echo htmlspecialchars($u["username"]); ?></td>
                        <td><?php echo htmlspecialchars($u["role_name"]); ?></td>
                        <td><?php echo htmlspecialchars($u["branch_name"] ?? ""); ?></td>
                        <td><?php echo ((int)$u["is_active"] === 1 ? "Yes" : "No"); ?></td>
                        <td><?php echo ((int)$u["kyc_officer_active"] === 1 ? "Yes" : "No"); ?></td>
                        <td><?php echo htmlspecialchars($u["created_at"]); ?></td>
                        <td style="white-space:nowrap;">

    <?php if (in_array($u["role_name"], ["HO User", "Branch User"], true) && (int)$u["is_active"] === 1) { ?>
        <form method="post" action="toggle_kyc_officer.php" style="display:inline;">
            <?php echo csrfField(); ?>
            <input type="hidden" name="user_id" value="<?php echo (int)$u["user_id"]; ?>">
            <input type="hidden" name="enabled" value="<?php echo (int)$u["kyc_officer_active"] === 1 ? 0 : 1; ?>">
            <button type="submit" class="action-icon <?php echo (int)$u["kyc_officer_active"] === 1 ? 'danger' : 'success'; ?>" title="<?php echo (int)$u["kyc_officer_active"] === 1 ? 'Revoke KYC Officer' : 'Grant KYC Officer'; ?>">
                <?php echo (int)$u["kyc_officer_active"] === 1 ? 'Revoke KYC' : 'Grant KYC'; ?>
            </button>
        </form>
    <?php } ?>

    <a href="edit_user.php?id=<?php echo (int)$u["user_id"]; ?>"
       class="action-icon primary"
       title="Edit User">
        ✏️
    </a>

    <?php if ((int)$u["is_active"] === 1) { ?>
        <form method="post" action="toggle_user_status.php" style="display:inline;">
            <?php echo csrfField(); ?>
            <input type="hidden" name="id" value="<?php echo (int)$u["user_id"]; ?>">
            <input type="hidden" name="status" value="0">
            <button type="submit" class="action-icon danger" title="Deactivate">⛔</button>
        </form>
    <?php } else { ?>
        <form method="post" action="toggle_user_status.php" style="display:inline;">
            <?php echo csrfField(); ?>
            <input type="hidden" name="id" value="<?php echo (int)$u["user_id"]; ?>">
            <input type="hidden" name="status" value="1">
            <button type="submit" class="action-icon success" title="Activate">✅</button>
        </form>
    <?php } ?>

    <form method="post" action="reset_user_password.php" style="display:inline;">
        <?php echo csrfField(); ?>
        <input type="hidden" name="id" value="<?php echo (int)$u["user_id"]; ?>">
        <button type="submit" class="action-icon primary" title="Reset Password">🔑</button>
    </form>

</td>
                    </tr>
                <?php } ?>
            </tbody>
        </table>
    </div>
</div>

<script>
document.addEventListener("DOMContentLoaded", function () {
    const roleSelect = document.getElementById("role_name");
    const branchSelect = document.getElementById("branch_id");

    function toggleBranchRequirement() {
        const role = roleSelect.value;

        if (role === "Branch User" || role === "HO User") {
            branchSelect.required = true;
        } else {
            branchSelect.required = false;
            branchSelect.value = "";
        }
    }

    roleSelect.addEventListener("change", toggleBranchRequirement);
    toggleBranchRequirement();
});
</script>

<?php require_once "../includes/footer.php"; ?>
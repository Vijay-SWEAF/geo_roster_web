<?php
require_once "../includes/auth_check.php";
require_once "../config/database.php";

if ($_SESSION["role"] != "Admin") {
    $_SESSION["flash_error"] = "Access denied.";
    header("Location: ../dashboard.php");
    exit;
}

$branches = $conn->query("
    SELECT branch_id, branch_name
    FROM branches
    ORDER BY branch_name
");

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $action = $_POST["action"] ?? "add_location";

    if ($action === "update_toggles") {
        $location_id = (int)($_POST["location_id"] ?? 0);
        $is_ot_enabled = isset($_POST["is_ot_enabled"]) && (int)$_POST["is_ot_enabled"] === 0 ? 0 : 1;
        $is_expense_enabled = isset($_POST["is_expense_enabled"]) && (int)$_POST["is_expense_enabled"] === 0 ? 0 : 1;

        if ($location_id <= 0) {
            $_SESSION["flash_error"] = "Invalid sub-location selected.";
            header("Location: branch_locations.php");
            exit;
        }

        $update_sql = "
            UPDATE branch_locations
            SET is_ot_enabled = '$is_ot_enabled',
                is_expense_enabled = '$is_expense_enabled'
            WHERE location_id = '$location_id'
            LIMIT 1
        ";

        if ($conn->query($update_sql)) {
            $_SESSION["flash_message"] = "Sub-location toggles updated successfully.";
        } else {
            $_SESSION["flash_error"] = "Unable to update sub-location toggles.";
        }

        header("Location: branch_locations.php");
        exit;
    }

    $branch_id = (int)($_POST["branch_id"] ?? 0);
    $location_name = trim($_POST["location_name"] ?? "");
    $is_ot_enabled = isset($_POST["is_ot_enabled"]) ? (int)$_POST["is_ot_enabled"] : 1;
    $is_expense_enabled = isset($_POST["is_expense_enabled"]) ? (int)$_POST["is_expense_enabled"] : 1;

    if ($branch_id <= 0 || $location_name === "") {
        $_SESSION["flash_error"] = "Branch and Sub-Location are required.";
        header("Location: branch_locations.php");
        exit;
    }

    $location_name_safe = $conn->real_escape_string($location_name);

    $check_existing = $conn->query("
        SELECT location_id
        FROM branch_locations
        WHERE branch_id = '$branch_id'
        AND location_name = '$location_name_safe'
        LIMIT 1
    ");

    if ($check_existing && $check_existing->num_rows > 0) {
        $_SESSION["flash_error"] = "Sub-Location already exists for the selected branch.";
        header("Location: branch_locations.php");
        exit;
    }

    $insert_sql = "
        INSERT INTO branch_locations
        (branch_id, location_name, is_active, is_ot_enabled, is_expense_enabled, created_at)
        VALUES
        ('$branch_id', '$location_name_safe', 1, '$is_ot_enabled', '$is_expense_enabled', NOW())
    ";

    if ($conn->query($insert_sql)) {
        $_SESSION["flash_message"] = "Sub-Location added successfully.";
    } else {
        $_SESSION["flash_error"] = "Unable to add Sub-Location.";
    }

    header("Location: branch_locations.php");
    exit;
}

$locations = $conn->query("
    SELECT 
        bl.location_id,
        bl.branch_id,
        bl.location_name,
        bl.is_active,
        bl.is_ot_enabled,
        bl.is_expense_enabled,
        bl.created_at,
        b.branch_name
    FROM branch_locations bl
    LEFT JOIN branches b ON bl.branch_id = b.branch_id
    ORDER BY b.branch_name, bl.location_name
");

define('APP_INCLUDED', true);

$pageTitle = "Sub-Location Master";
$pageSubtitle = "Create and maintain sub-locations with OT and expense control settings.";
$basePath = "../";

require_once "../includes/header.php";
?>

<div class="module-two-col">

    <div class="panel-card">
        <div class="panel-title">Add New Sub-Location</div>

        <form method="post" class="form-grid">

            <div>
                <label for="branch_id">Branch</label>
                <select id="branch_id" name="branch_id" required>
                    <option value="">Select Branch</option>
                    <?php while ($b = $branches->fetch_assoc()) { ?>
                        <option value="<?php echo $b["branch_id"]; ?>">
                            <?php echo htmlspecialchars($b["branch_name"]); ?>
                        </option>
                    <?php } ?>
                </select>
            </div>

            <div>
                <label for="location_name">Sub-Location Name</label>
                <input type="text" id="location_name" name="location_name" placeholder="e.g. Crystal Yard-3" required>
            </div>

            <div>
                <label for="is_ot_enabled">OT Allowed</label>
                <select id="is_ot_enabled" name="is_ot_enabled" required>
                    <option value="1">Yes</option>
                    <option value="0">No</option>
                </select>
            </div>

            <div>
                <label for="is_expense_enabled">Expense Allowed</label>
                <select id="is_expense_enabled" name="is_expense_enabled" required>
                    <option value="1">Yes</option>
                    <option value="0">No</option>
                </select>
            </div>

            <div class="form-actions">
                <button type="submit">Add Sub-Location</button>
                <a href="../dashboard.php" class="btn-secondary-link">Cancel</a>
            </div>

        </form>
    </div>

    <div class="panel-card">
        <div class="panel-title">Sub-Location Records</div>

        <div class="table-wrap">
            <table class="employee-master-table">
                <thead>
                    <tr>
                        <th style="width:220px;">Branch</th>
                        <th style="width:220px;">Sub-Location</th>
                        <th style="width:120px;">OT Allowed</th>
                        <th style="width:140px;">Expense Allowed</th>
                        <th style="width:120px;">Status</th>
                        <th style="width:180px;">Created At</th>
                        <th style="width:150px;">Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if ($locations && $locations->num_rows > 0) { ?>
                        <?php while ($loc = $locations->fetch_assoc()) { ?>
                            <?php $row_form_id = "update_loc_" . (int)$loc["location_id"]; ?>
                            <tr>
                                <td><?php echo htmlspecialchars($loc["branch_name"] ?? ""); ?></td>
                                <td><?php echo htmlspecialchars($loc["location_name"] ?? ""); ?></td>
                                <td>
                                    <select name="is_ot_enabled" form="<?php echo $row_form_id; ?>">
                                        <option value="1" <?php if ((int)$loc["is_ot_enabled"] === 1) echo "selected"; ?>>ON</option>
                                        <option value="0" <?php if ((int)$loc["is_ot_enabled"] === 0) echo "selected"; ?>>OFF</option>
                                    </select>
                                </td>
                                <td>
                                    <select name="is_expense_enabled" form="<?php echo $row_form_id; ?>">
                                        <option value="1" <?php if ((int)$loc["is_expense_enabled"] === 1) echo "selected"; ?>>ON</option>
                                        <option value="0" <?php if ((int)$loc["is_expense_enabled"] === 0) echo "selected"; ?>>OFF</option>
                                    </select>
                                </td>
                                <td>
                                    <?php if ((int)$loc["is_active"] === 1) { ?>
                                        <span style="color:green; font-weight:600;">Active</span>
                                    <?php } else { ?>
                                        <span style="color:red; font-weight:600;">Inactive</span>
                                    <?php } ?>
                                </td>
                                <td><?php echo htmlspecialchars($loc["created_at"] ?? ""); ?></td>
                                <td>
                                    <form id="<?php echo $row_form_id; ?>" method="post" style="margin:0;">
                                        <input type="hidden" name="action" value="update_toggles">
                                        <input type="hidden" name="location_id" value="<?php echo (int)$loc["location_id"]; ?>">
                                        <button type="submit">Update</button>
                                    </form>
                                </td>
                            </tr>
                        <?php } ?>
                    <?php } else { ?>
                        <tr>
                            <td colspan="7">No sub-location records found.</td>
                        </tr>
                    <?php } ?>
                </tbody>
            </table>
        </div>

        <div class="form-actions" style="margin-top:16px;">
            <a href="../dashboard.php" class="btn-secondary-link">Back</a>
        </div>
    </div>

</div>

<?php require_once "../includes/footer.php"; ?>
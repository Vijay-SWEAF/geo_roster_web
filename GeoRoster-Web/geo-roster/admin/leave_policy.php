<?php
require_once "../includes/auth_check.php";
require_once "../config/database.php";
require_once "../includes/security.php";

if ($_SESSION["role"] != "Admin") {
    $_SESSION["flash_error"] = "Access denied.";
    header("Location: ../dashboard.php");
    exit;
}

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    requireCsrf();

    $policy_year = trim($_POST["policy_year"]);
    $employee_category = trim($_POST["employee_category"]);
    $leave_type_id = trim($_POST["leave_type_id"]);
    $entitled_days = trim($_POST["entitled_days"]);

    $policy_year = filter_var($_POST["policy_year"] ?? null, FILTER_VALIDATE_INT);
    $leave_type_id = validPositiveInt($leave_type_id);
    $entitled_days = filter_var($entitled_days, FILTER_VALIDATE_FLOAT);
    if (!$policy_year || !in_array($employee_category, ["Staff", "Labour"], true) || !$leave_type_id || $entitled_days === false || $entitled_days < 0) {
        $_SESSION["flash_error"] = "Invalid leave policy.";
        header("Location: leave_policy.php");
        exit;
    }
    $stmt = $conn->prepare("INSERT INTO leave_policy (policy_year, employee_category, leave_type_id, entitled_days) VALUES (?, ?, ?, ?)");
    $stmt->bind_param("isid", $policy_year, $employee_category, $leave_type_id, $entitled_days);
    try {
        if ($stmt->execute()) {
            $_SESSION["flash_message"] = "Leave policy saved successfully.";
            auditEvent($conn, "leave_policy_created", "leave_policy", $stmt->insert_id);
        } else {
            $_SESSION["flash_error"] = "Unable to save leave policy.";
        }
    } catch (mysqli_sql_exception $e) {
        if ($e->getCode() == 1062) {
            $_SESSION["flash_error"] = "Leave policy already exists for this year and category.";
        } else {
            $_SESSION["flash_error"] = "Unable to save leave policy.";
        }
    }

    header("Location: leave_policy.php");
    exit;
}

$leave_types = $conn->query("
    SELECT leave_type_id, leave_code, leave_name
    FROM leave_types
    WHERE is_active = 1
    ORDER BY leave_name
");

$policies = $conn->query("
    SELECT 
        p.policy_id,
        p.policy_year,
        p.employee_category,
        lt.leave_code,
        lt.leave_name,
        p.entitled_days
    FROM leave_policy p
    INNER JOIN leave_types lt ON p.leave_type_id = lt.leave_type_id
    ORDER BY p.policy_year DESC, p.employee_category, lt.leave_code
");

define('APP_INCLUDED', true);

$pageTitle = "Leave Policy Master";
$pageSubtitle = "Maintain yearly leave entitlement rules for Staff and Labour categories.";
$basePath = "../";

require_once "../includes/header.php";
?>

<div class="module-two-col">

    <div class="panel-card">
        <div class="panel-title">Add Leave Policy</div>

        <form method="post" class="form-grid">
            <?php echo csrfField(); ?>

            <div>
                <label for="policy_year">Policy Year</label>
                <input type="number" id="policy_year" name="policy_year" value="<?php echo date('Y'); ?>" required>
            </div>

            <div>
                <label for="employee_category">Category</label>
                <select id="employee_category" name="employee_category" required>
                    <option value="">Select Category</option>
                    <option value="Staff">Staff</option>
                    <option value="Labour">Labour</option>
                </select>
            </div>

            <div>
                <label for="leave_type_id">Leave Type</label>
                <select id="leave_type_id" name="leave_type_id" required>
                    <option value="">Select Leave Type</option>
                    <?php while($lt = $leave_types->fetch_assoc()) { ?>
                        <option value="<?php echo $lt["leave_type_id"]; ?>">
                            <?php echo htmlspecialchars($lt["leave_code"] . " - " . $lt["leave_name"]); ?>
                        </option>
                    <?php } ?>
                </select>
            </div>

            <div>
                <label for="entitled_days">Entitled Days</label>
                <input type="number" id="entitled_days" name="entitled_days" step="0.5" placeholder="e.g. 5" required>
            </div>

            <div class="form-actions">
                <button type="submit">Save Policy</button>
                <a href="javascript:history.back()" class="btn-secondary-link">Cancel</a>
            </div>

        </form>
    </div>

    <div class="panel-card">
        <div class="panel-title">Leave Policy Records</div>

        <div class="table-wrap">
            <table class="leave-policy-table">
                <thead>
                    <tr>
                        <th style="width:100px;">Year</th>
                        <th style="width:140px;">Category</th>
                        <th style="width:240px;">Leave Type</th>
                        <th style="width:140px;">Entitled Days</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if ($policies && $policies->num_rows > 0) { ?>
                        <?php while($r = $policies->fetch_assoc()) { ?>
                            <tr>
                                <td><?php echo htmlspecialchars($r["policy_year"] ?? ""); ?></td>
                                <td><?php echo htmlspecialchars($r["employee_category"] ?? ""); ?></td>
                                <td><?php echo htmlspecialchars(($r["leave_code"] ?? "") . " - " . ($r["leave_name"] ?? "")); ?></td>
                                <td><?php echo number_format((float)($r["entitled_days"] ?? 0), 2); ?></td>
                            </tr>
                        <?php } ?>
                    <?php } else { ?>
                        <tr>
                            <td colspan="4">No leave policy records found.</td>
                        </tr>
                    <?php } ?>
                </tbody>
            </table>
        </div>
    </div>

</div>

<?php require_once "../includes/footer.php"; ?>
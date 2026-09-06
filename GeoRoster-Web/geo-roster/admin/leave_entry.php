<?php
require_once "../includes/auth_check.php";
require_once "../config/database.php";
require_once "../includes/security.php";

if ($_SESSION["role"] != "Admin") {
    $_SESSION["flash_error"] = "Access denied.";
    header("Location: ../dashboard.php");
    exit;
}

$user_id = $_SESSION["user_id"];

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    requireCsrf();

    $employee_category = trim($_POST["employee_category"]);
    $leave_type_id = trim($_POST["leave_type_id"]);
    $from_date = trim($_POST["from_date"]);
    $to_date = trim($_POST["to_date"]);
    $remarks = trim($_POST["remarks"]);

    if (!in_array($employee_category, ["Staff", "Labour"], true) || !validPositiveInt($leave_type_id) || !validDateValue($from_date) || !validDateValue($to_date)) {
        $_SESSION["flash_error"] = "Invalid leave entry.";
        header("Location: leave_entry.php");
        exit;
    }
    $stmt = $conn->prepare("INSERT INTO leave_entries (employee_category, leave_type_id, from_date, to_date, remarks, entered_by) VALUES (?, ?, ?, ?, ?, ?)");
    $leave_type_id = (int)$leave_type_id;
    $stmt->bind_param("sisssi", $employee_category, $leave_type_id, $from_date, $to_date, $remarks, $user_id);
    if ($stmt->execute()) {
        $_SESSION["flash_message"] = "Leave entry saved successfully.";
        auditEvent($conn, "leave_entry_created", "leave_entry", $stmt->insert_id);
    } else {
        $_SESSION["flash_error"] = "Unable to save leave entry.";
    }

    header("Location: leave_entry.php");
    exit;
}

$leave_types = $conn->query("
    SELECT leave_type_id, leave_code, leave_name
    FROM leave_types
    WHERE is_active = 1
    ORDER BY leave_name
");

$leave_records = $conn->query("
    SELECT 
        l.leave_id,
        l.employee_category,
        lt.leave_code,
        lt.leave_name,
        l.from_date,
        l.to_date,
        l.remarks
    FROM leave_entries l
    INNER JOIN leave_types lt ON l.leave_type_id = lt.leave_type_id
    ORDER BY l.from_date DESC, l.employee_category
");

define('APP_INCLUDED', true);

$pageTitle = "Leave Entry";
$pageSubtitle = "Maintain category-wise leave periods for Staff and Labour.";
$basePath = "../";

require_once "../includes/header.php";
?>

<div class="module-two-col">

    <div class="panel-card">
        <div class="panel-title">Add Leave Entry</div>

        <form method="post" class="form-grid">
            <?php echo csrfField(); ?>

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
                <label for="from_date">From Date</label>
                <input type="date" id="from_date" name="from_date" required>
            </div>

            <div>
                <label for="to_date">To Date</label>
                <input type="date" id="to_date" name="to_date" required>
            </div>

            <div>
                <label for="remarks">Remarks</label>
                <input type="text" id="remarks" name="remarks" placeholder="Optional remarks">
            </div>

            <div class="form-actions">
                <button type="submit">Save Leave</button>
                <a href="javascript:history.back()" class="btn-secondary-link">Cancel</a>
            </div>

        </form>
    </div>

    <div class="panel-card">
        <div class="panel-title">Leave Records</div>

        <div class="table-wrap">
            <table class="leave-entry-table">
                <thead>
                    <tr>
                        <th style="width:140px;">Category</th>
                        <th style="width:220px;">Leave Type</th>
                        <th style="width:120px;">From</th>
                        <th style="width:120px;">To</th>
                        <th style="width:260px;">Remarks</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if ($leave_records && $leave_records->num_rows > 0) { ?>
                        <?php while($r = $leave_records->fetch_assoc()) { ?>
                            <tr>
                                <td><?php echo htmlspecialchars($r["employee_category"] ?? ""); ?></td>
                                <td><?php echo htmlspecialchars(($r["leave_code"] ?? "") . " - " . ($r["leave_name"] ?? "")); ?></td>
                                <td><?php echo htmlspecialchars($r["from_date"] ?? ""); ?></td>
                                <td><?php echo htmlspecialchars($r["to_date"] ?? ""); ?></td>
                                <td><?php echo htmlspecialchars($r["remarks"] ?? ""); ?></td>
                            </tr>
                        <?php } ?>
                    <?php } else { ?>
                        <tr>
                            <td colspan="5">No leave records found.</td>
                        </tr>
                    <?php } ?>
                </tbody>
            </table>
        </div>
    </div>

</div>

<?php require_once "../includes/footer.php"; ?>
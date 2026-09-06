<?php
require_once "includes/auth_check.php";
require_once "config/database.php";

$user_id = $_SESSION["user_id"];
$user_role = $_SESSION["role"];

$selected_month = validMonthValue($_GET["month"] ?? date("Y-m")) ?: date("Y-m");
$selected_branch_id = "";
$user_branch_id = "";
$selected_location_id = validPositiveInt($_GET["location_id"] ?? null) ?: 0;
$locations = [];
$branch_name = "";

/* Get logged-in user's branch */
$user_result = preparedResult($conn, "SELECT branch_id FROM users WHERE user_id = ? LIMIT 1", "i", [$user_id]);

if (!$user_result || $user_result->num_rows == 0) {
    error_log("Monthly register user record not found.");
    exit("Unable to load report.");
}

$user_row = $user_result->fetch_assoc();
$user_branch_id = $user_row["branch_id"];

$branch_name_result = preparedResult($conn, "SELECT branch_name FROM branches WHERE branch_id = ? LIMIT 1", "i", [(int)$user_branch_id]);

if ($branch_name_result && $branch_name_result->num_rows > 0) {
    $branch_name_row = $branch_name_result->fetch_assoc();
    $branch_name = $branch_name_row["branch_name"];
}

/* Branch restriction by role */
if ($user_role == "Branch User") {
    $selected_branch_id = $user_branch_id;
} else {
    $selected_branch_id = validPositiveInt($_GET["branch_id"] ?? null) ?: "";
}

/* Load branches */
if ($user_role == "Branch User") {
    $branches = preparedResult($conn, "SELECT branch_id, branch_name FROM branches WHERE branch_id = ? ORDER BY branch_name", "i", [(int)$user_branch_id]);
} else {
    $branches = $conn->query("
        SELECT branch_id, branch_name
        FROM branches
        ORDER BY branch_name
    ");
}

if ($selected_branch_id != "") {
    $location_result = preparedResult($conn, "SELECT location_id, location_name FROM branch_locations WHERE branch_id = ? AND is_active = 1 ORDER BY location_name", "i", [(int)$selected_branch_id]);

    if ($location_result) {
        while ($loc = $location_result->fetch_assoc()) {
            $locations[] = $loc;
        }
    }
}

$records = [];

if ($selected_branch_id != "") {

    $start_date = $selected_month . "-01";
    $end_date = date("Y-m-t", strtotime($start_date));

    $sql = "
    SELECT 
        a.attendance_date,
        e.employee_no,
        e.employee_name,
        e.employee_category,
        b.branch_name,
        bl.location_name,
        a.status_code,
        lt.leave_code,
        a.ot_hours,
        a.other_expense,
        a.remarks
    FROM attendance_entries a
    INNER JOIN employees e ON a.employee_id = e.employee_id
    INNER JOIN branches b ON a.branch_id = b.branch_id
    LEFT JOIN branch_locations bl ON a.location_id = bl.location_id
    LEFT JOIN leave_types lt ON a.leave_type_id = lt.leave_type_id
    WHERE a.branch_id = ?
    AND a.attendance_date BETWEEN ? AND ?
    " . ($selected_location_id > 0 ? " AND a.location_id = ?" : "") . "
    ORDER BY a.attendance_date, e.employee_name
";

    if ($selected_location_id > 0) {
        $result = preparedResult($conn, $sql, "issi", [(int)$selected_branch_id, $start_date, $end_date, $selected_location_id]);
    } else {
        $result = preparedResult($conn, $sql, "iss", [(int)$selected_branch_id, $start_date, $end_date]);
    }

    if (!$result) {
        error_log("Monthly register query failed.");
        $_SESSION["flash_error"] = "Unable to load monthly register.";
        header("Location: monthly_register.php");
        exit;
    }

    while ($row = $result->fetch_assoc()) {
        $records[] = $row;
    }
}

$pageTitle = "Monthly Attendance Register";
$pageSubtitle = "Review date-wise attendance, leave, OT hours, and expenses for a selected month and branch.";
$basePath = "";

define('APP_INCLUDED', true);
require_once "includes/header.php";
?>

<form method="get">
    <div class="top-filters-flex">

        <div class="filter-box">
            <label for="month">Month</label>
            <input type="month" id="month" name="month" value="<?php echo htmlspecialchars($selected_month); ?>">
        </div>

        <div class="filter-box">
            <label for="branch_id">Branch</label>

            <?php if ($user_role == "Branch User") { ?>
    <input type="text" value="<?php echo htmlspecialchars($branch_name); ?>" readonly>
<?php } else { ?>

                <select id="branch_id" name="branch_id">
                    <option value="">Select Branch</option>
                    <?php while($b = $branches->fetch_assoc()) { ?>
                        <option value="<?php echo $b['branch_id']; ?>" <?php if($selected_branch_id == $b['branch_id']) echo "selected"; ?>>
                            <?php echo htmlspecialchars($b['branch_name']); ?>
                        </option>
                    <?php } ?>
                </select>
            <?php } ?>
        </div>

<div class="filter-box">
    <label for="location_id">Sub-Location</label>
    <select id="location_id" name="location_id">
        <option value="">All Sub-Locations</option>
        <?php foreach ($locations as $loc) { ?>
            <option value="<?php echo $loc["location_id"]; ?>" <?php if ($selected_location_id == $loc["location_id"]) echo "selected"; ?>>
                <?php echo htmlspecialchars($loc["location_name"]); ?>
            </option>
        <?php } ?>
    </select>
</div>

        <div class="filter-box button-box">
    <label>&nbsp;</label>
    <div class="action-buttons">
        <button type="submit">View Register</button>

        <?php if ($selected_branch_id != "") { ?>
            <a class="btn-excel" href="export_monthly_register.php?month=<?php echo urlencode($selected_month); ?>&branch_id=<?php echo urlencode($selected_branch_id); ?>&location_id=<?php echo urlencode($selected_location_id); ?>">
                Export to Excel
            </a>
        <?php } ?>

        <a href="dashboard.php" class="btn-secondary-link">Cancel</a>
    </div>
</div>

    </div>
</form>

<?php if ($selected_branch_id != "" && count($records) > 0) { ?>

    <div class="table-wrap">
        <table class="monthly-register-table">
            <thead>
                <tr>
                    <th style="width:130px;">Date</th>
                    <th style="width:140px;">Employee No</th>
                    <th style="width:220px;">Employee</th>
                    <th style="width:120px;">Category</th>
                    <th style="width:160px;">Branch</th>
<th style="width:180px;">Sub-Location</th>
<th style="width:100px;">Status</th>
<th style="width:120px;">Leave Type</th>
<th style="width:120px;">OT Hours</th>
<th style="width:140px;">Other Expense</th>
<th style="width:240px;">Remarks</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach($records as $r) { ?>
                    <?php
                        $rowClass = "";

$status_code = $r['status_code'] ?? '';
$leave_code = $r['leave_code'] ?? '';

if ($status_code === "P") $rowClass = "status-P";
if ($status_code === "A") $rowClass = "status-A";
if ($status_code === "H") $rowClass = "status-H";
if ($status_code === "WO") $rowClass = "status-WO";

if ($status_code === "L") {
    if ($leave_code === "CL") $rowClass = "status-CL";
    elseif ($leave_code === "SL") $rowClass = "status-SL";
    elseif ($leave_code === "EL") $rowClass = "status-EL";
    else $rowClass = "status-L";
}
                    ?>
                    <tr class="<?php echo $rowClass; ?>">
                        <td><?php echo htmlspecialchars($r['attendance_date'] ?? ''); ?></td>
                        <td><?php echo htmlspecialchars($r['employee_no'] ?? ''); ?></td>
                        <td><?php echo htmlspecialchars($r['employee_name'] ?? ''); ?></td>
                        <td><?php echo htmlspecialchars($r['employee_category'] ?? ''); ?></td>
                        <td><?php echo htmlspecialchars($r['branch_name'] ?? ''); ?></td>
                        <td><?php echo htmlspecialchars($r['location_name'] ?? ''); ?></td>
                        <td><?php echo htmlspecialchars($r['status_code'] ?? ''); ?></td>
                        <td><?php echo htmlspecialchars($r['leave_code'] ?? ''); ?></td>
                        <td style="text-align:right;"><?php echo number_format((float)($r['ot_hours'] ?? 0), 2); ?></td>
                        <td style="text-align:right;">₹ <?php echo number_format((float)($r['other_expense'] ?? 0), 2); ?></td>
                        <td><?php echo htmlspecialchars($r['remarks'] ?? ''); ?></td>
                    </tr>
                <?php } ?>
            </tbody>
        </table>
    </div>

<?php } elseif ($selected_branch_id != "") { ?>

    <div class="panel-card" style="margin-top:16px;">
        No attendance records found for the selected month and branch.
    </div>

<?php } ?>

<?php require_once "includes/footer.php"; ?>
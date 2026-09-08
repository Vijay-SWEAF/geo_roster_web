<?php
require_once "includes/auth_check.php";
require_once "config/database.php";

$user_id = $_SESSION["user_id"];
$user_role = $_SESSION["role"];

$selected_month = validMonthValue($_GET["month"] ?? date("Y-m")) ?: date("Y-m");
$selected_location_id = validPositiveInt($_GET["location_id"] ?? null) ?: 0;
$requested_branch_id = validPositiveInt($_GET["branch_id"] ?? null) ?: "";
$selected_branch_id = "";
$user_branch_id = "";

/* Get logged-in user's branch */
$user_result = preparedResult($conn, "SELECT branch_id FROM users WHERE user_id = ? LIMIT 1", "i", [$user_id]);

if (!$user_result || $user_result->num_rows == 0) {
    error_log("Monthly export user record not found.");
    exit("Unable to export monthly register.");
}

$user_row = $user_result->fetch_assoc();
$user_branch_id = $user_row["branch_id"];

/* Restrict Branch User to own branch only */
if ($user_role == "Branch User") {
    $selected_branch_id = $user_branch_id;
} else {
    $selected_branch_id = $requested_branch_id;
}

if ($selected_branch_id == "") {
    die("Branch is required.");
}

$start_date = $selected_month . "-01";
$end_date = date("Y-m-t", strtotime($start_date));

/* Branch name for filename */
$branch_name = "branch";
$branch_result = preparedResult($conn, "SELECT branch_name FROM branches WHERE branch_id = ? LIMIT 1", "i", [(int)$selected_branch_id]);

if ($branch_result && $branch_result->num_rows > 0) {
    $branch_row = $branch_result->fetch_assoc();
    $branch_name = preg_replace('/[^A-Za-z0-9_-]/', '_', $branch_row["branch_name"]);
}

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

$result = $selected_location_id > 0
    ? preparedResult($conn, $sql, "issi", [(int)$selected_branch_id, $start_date, $end_date, $selected_location_id])
    : preparedResult($conn, $sql, "iss", [(int)$selected_branch_id, $start_date, $end_date]);

if (!$result) {
    error_log("Monthly register export query failed: " . $conn->error);
    exit("Unable to export monthly register.");
}

$filename = "monthly_register_" . $selected_month . "_" . $branch_name . ".xls";

header("Content-Type: application/vnd.ms-excel");
header("Content-Disposition: attachment; filename=\"$filename\"");
header("Pragma: no-cache");
header("Expires: 0");
?>

<table border="1">
    <tr>
        <th>Date</th>
        <th>Employee No</th>
        <th>Employee</th>
        <th>Category</th>
        <th>Branch</th>
        <th>Sub-Location</th>
        <th>Status</th>
        <th>Leave Type</th>
        <th>OT Hours</th>
        <th>Other Expense</th>
        <th>Remarks</th>
    </tr>

    <?php while ($row = $result->fetch_assoc()) { ?>
    <tr>
        <td><?php echo htmlspecialchars(exportSafeText($row["attendance_date"] ?? ""), ENT_QUOTES, 'UTF-8'); ?></td>
        <td><?php echo htmlspecialchars(exportSafeText($row["employee_no"] ?? ""), ENT_QUOTES, 'UTF-8'); ?></td>
        <td><?php echo htmlspecialchars(exportSafeText($row["employee_name"] ?? ""), ENT_QUOTES, 'UTF-8'); ?></td>
        <td><?php echo htmlspecialchars(exportSafeText($row["employee_category"] ?? ""), ENT_QUOTES, 'UTF-8'); ?></td>
        <td><?php echo htmlspecialchars(exportSafeText($row["branch_name"] ?? ""), ENT_QUOTES, 'UTF-8'); ?></td>
        <td><?php echo htmlspecialchars(exportSafeText($row["location_name"] ?? ""), ENT_QUOTES, 'UTF-8'); ?></td>
        <td><?php echo htmlspecialchars(exportSafeText($row["status_code"] ?? ""), ENT_QUOTES, 'UTF-8'); ?></td>
        <td><?php echo htmlspecialchars(exportSafeText($row["leave_code"] ?? ""), ENT_QUOTES, 'UTF-8'); ?></td>
        <td><?php echo number_format((float)($row["ot_hours"] ?? 0), 2); ?></td>
        <td><?php echo number_format((float)($row["other_expense"] ?? 0), 2); ?></td>
        <td><?php echo htmlspecialchars(exportSafeText($row["remarks"] ?? ""), ENT_QUOTES, 'UTF-8'); ?></td>
    </tr>
    <?php } ?>
</table>
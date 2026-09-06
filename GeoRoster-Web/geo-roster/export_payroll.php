<?php
require_once "includes/auth_check.php";
require_once "config/database.php";

$month = validMonthValue($_GET["month"] ?? date("Y-m")) ?: date("Y-m");
$selected_location_id = validPositiveInt($_GET["location_id"] ?? null) ?: 0;
$branch_id = validPositiveInt($_GET["branch_id"] ?? null) ?: "";

$user_id = $_SESSION["user_id"];
$user_role = $_SESSION["role"];
$user_branch_id = "";

$user_result = preparedResult($conn, "SELECT branch_id FROM users WHERE user_id = ? LIMIT 1", "i", [$user_id]);

if (!$user_result || $user_result->num_rows == 0) {
    error_log("Payroll export user record not found.");
    exit("Unable to export payroll.");
}

$user_row = $user_result->fetch_assoc();
$user_branch_id = $user_row["branch_id"];

if ($user_role == "Branch User") {
    $branch_id = $user_branch_id;
}

if ($branch_id == "") {
    $_SESSION["flash_error"] = "Branch is required.";
    header("Location: payroll_sheet.php");
    exit;
}

$start = $month . "-01";
$end = date("Y-m-t", strtotime($start));
$days = (int)date("t", strtotime($start));
$selected_year = date("Y", strtotime($start));

$branch_name = "branch";
$branch_result = preparedResult($conn, "SELECT branch_name FROM branches WHERE branch_id = ? LIMIT 1", "i", [(int)$branch_id]);
if ($branch_result && $branch_result->num_rows > 0) {
    $branch_row = $branch_result->fetch_assoc();
    $branch_name = preg_replace('/[^A-Za-z0-9_-]/', '_', $branch_row["branch_name"]);
}

$employees = [];
$attendance = [];
$leave_policy_map = [];
$leave_used_map = [];

$location_condition = $selected_location_id > 0 ? " AND location_id = ?" : "";

$employee_sql = "
    SELECT employee_id, employee_no, employee_name, employee_category
    FROM employees
    WHERE branch_id = ?
    $location_condition
    ORDER BY 
        CASE 
            WHEN employee_category = 'Staff' THEN 1
            WHEN employee_category = 'Labour' THEN 2
            ELSE 3
        END,
        employee_name
";
$emp = $selected_location_id > 0
    ? preparedResult($conn, $employee_sql, "ii", [(int)$branch_id, $selected_location_id])
    : preparedResult($conn, $employee_sql, "i", [(int)$branch_id]);

if (!$emp) {
    error_log("Payroll export employee query failed: " . $conn->error);
    exit("Unable to export payroll.");
}

while ($r = $emp->fetch_assoc()) {
    $employees[] = $r;
}

$attendance_location_condition = $selected_location_id > 0 ? " AND a.location_id = ?" : "";

$attendance_sql = "
    SELECT 
        a.employee_id,
        a.attendance_date,
        a.status_code,
        a.ot_hours,
        a.other_expense,
        lt.leave_code
    FROM attendance_entries a
    LEFT JOIN leave_types lt ON a.leave_type_id = lt.leave_type_id
    WHERE a.branch_id = ?
    AND a.attendance_date BETWEEN ? AND ?
    $attendance_location_condition
";
$att = $selected_location_id > 0
    ? preparedResult($conn, $attendance_sql, "issi", [(int)$branch_id, $start, $end, $selected_location_id])
    : preparedResult($conn, $attendance_sql, "iss", [(int)$branch_id, $start, $end]);

if (!$att) {
    error_log("Payroll export attendance query failed: " . $conn->error);
    exit("Unable to export payroll.");
}

while ($a = $att->fetch_assoc()) {
    $day = (int)date("j", strtotime($a["attendance_date"]));

    $display_code = $a["status_code"];
    if ($a["status_code"] == "L" && !empty($a["leave_code"])) {
        $display_code = $a["leave_code"];
    }

    $attendance[$a["employee_id"]][$day] = [
        "code" => $display_code,
        "ot_hours" => (float)($a["ot_hours"] ?? 0),
        "other_expense" => (float)($a["other_expense"] ?? 0)
    ];
}

/* Leave policy map for CL, SL, EL by employee category and selected year */
$policy_result = preparedResult($conn, "
    SELECT 
        p.employee_category,
        lt.leave_code,
        p.entitled_days
    FROM leave_policy p
    INNER JOIN leave_types lt ON p.leave_type_id = lt.leave_type_id
    WHERE p.policy_year = ?
    AND lt.leave_code IN ('CL','SL','EL')
", "i", [(int)$selected_year]);

if (!$policy_result) {
    error_log("Payroll export leave policy query failed: " . $conn->error);
    exit("Unable to export payroll.");
}

while ($p = $policy_result->fetch_assoc()) {
    $leave_policy_map[$p["employee_category"]][$p["leave_code"]] = (float)$p["entitled_days"];
}

$used_location_condition = $selected_location_id > 0 ? " AND a.location_id = ?" : "";

/* Leave used map for CL, SL, EL by employee for selected year */
$used_sql = "
    SELECT 
        a.employee_id,
        lt.leave_code,
        COUNT(*) AS used_days
    FROM attendance_entries a
    INNER JOIN leave_types lt ON a.leave_type_id = lt.leave_type_id
    WHERE a.branch_id = ?
    AND a.status_code = 'L'
    AND YEAR(a.attendance_date) = ?
    AND lt.leave_code IN ('CL','SL','EL')
    $used_location_condition
    GROUP BY a.employee_id, lt.leave_code
";
$used_result = $selected_location_id > 0
    ? preparedResult($conn, $used_sql, "iii", [(int)$branch_id, (int)$selected_year, $selected_location_id])
    : preparedResult($conn, $used_sql, "ii", [(int)$branch_id, (int)$selected_year]);

if (!$used_result) {
    error_log("Payroll export leave usage query failed: " . $conn->error);
    exit("Unable to export payroll.");
}

while ($u = $used_result->fetch_assoc()) {
    $leave_used_map[$u["employee_id"]][$u["leave_code"]] = (float)$u["used_days"];
}

$filename = "payroll_sheet_" . $month . "_" . $branch_name . ".xls";

header("Content-Type: application/vnd.ms-excel");
header("Content-Disposition: attachment; filename=\"$filename\"");
header("Pragma: no-cache");
header("Expires: 0");
?>

<table border="1">
    <tr>
        <th>Employee No</th>
        <th>Employee</th>
        <th>Category</th>
        <th>P</th>
        <th>A</th>
        <th>L</th>
<th>H</th>
<th>WO</th>
<th>Paid Days</th>
<th>OT</th>
        <th>Expense</th>

        <th>CL Allot</th>
        <th>CL Used</th>
        <th>CL Bal</th>

        <th>SL Allot</th>
        <th>SL Used</th>
        <th>SL Bal</th>

        <th>EL Allot</th>
        <th>EL Used</th>
        <th>EL Bal</th>

        <?php for($d = 1; $d <= $days; $d++) { ?>
            <th><?php echo $d; ?></th>
        <?php } ?>
    </tr>

    <?php foreach($employees as $e) { ?>
        <tr>
            <td><?php echo htmlspecialchars(exportSafeText($e["employee_no"] ?? ""), ENT_QUOTES, 'UTF-8'); ?></td>
            <td><?php echo htmlspecialchars(exportSafeText($e["employee_name"] ?? ""), ENT_QUOTES, 'UTF-8'); ?></td>
            <td><?php echo htmlspecialchars(exportSafeText($e["employee_category"] ?? ""), ENT_QUOTES, 'UTF-8'); ?></td>

            <?php
            $present = 0;
            $absent = 0;
            $leave = 0;
            $half = 0;
            $weekly_off = 0;
            $paid_days = 0;
            $total_ot = 0;
            $total_expense = 0;

            for ($d = 1; $d <= $days; $d++) {
                $status = "";

                if (isset($attendance[$e["employee_id"]][$d])) {
                    $status = $attendance[$e["employee_id"]][$d]["code"];
                    $total_ot += (float)$attendance[$e["employee_id"]][$d]["ot_hours"];
                    $total_expense += (float)$attendance[$e["employee_id"]][$d]["other_expense"];

                    if ($status == "P") {
    $present++;
    $paid_days += 1;
}

if ($status == "WO") {
    $weekly_off++;
    $paid_days += 1;
}

if ($status == "H") {
    $half++;
    $paid_days += 0.5;
}

if ($status == "A") {
    $absent++;
}

if (in_array($status, ["CL","SL","EL"])) {
    $leave++;
    $paid_days += 1;
}

if (in_array($status, ["L","LWP","PL"])) {
    $leave++; // counted but NOT paid
}
            }
            }
            

            $category = $e["employee_category"];
            $emp_id = $e["employee_id"];

            $cl_allot = (float)($leave_policy_map[$category]["CL"] ?? 0);
            $sl_allot = (float)($leave_policy_map[$category]["SL"] ?? 0);
            $el_allot = (float)($leave_policy_map[$category]["EL"] ?? 0);

            $cl_used = (float)($leave_used_map[$emp_id]["CL"] ?? 0);
            $sl_used = (float)($leave_used_map[$emp_id]["SL"] ?? 0);
            $el_used = (float)($leave_used_map[$emp_id]["EL"] ?? 0);

            $cl_bal = $cl_allot - $cl_used;
            $sl_bal = $sl_allot - $sl_used;
            $el_bal = $el_allot - $el_used;
            ?>

            <td><?php echo $present; ?></td>
            <td><?php echo $absent; ?></td>
            <td><?php echo $leave; ?></td>
<td><?php echo $half; ?></td>
<td><?php echo $weekly_off; ?></td>
<td style="text-align:right;"><?php echo number_format($paid_days, 2); ?></td>
<td style="text-align:right;"><?php echo number_format($total_ot, 2); ?></td>
            <td style="text-align:right;">₹ <?php echo number_format($total_expense, 2); ?></td>

            <td><?php echo number_format($cl_allot, 2); ?></td>
            <td><?php echo number_format($cl_used, 2); ?></td>
            <td><?php echo number_format($cl_bal, 2); ?></td>

            <td><?php echo number_format($sl_allot, 2); ?></td>
            <td><?php echo number_format($sl_used, 2); ?></td>
            <td><?php echo number_format($sl_bal, 2); ?></td>

            <td><?php echo number_format($el_allot, 2); ?></td>
            <td><?php echo number_format($el_used, 2); ?></td>
            <td><?php echo number_format($el_bal, 2); ?></td>

            <?php for($d = 1; $d <= $days; $d++) { ?>
                <td>
                    <?php
                    if (isset($attendance[$e["employee_id"]][$d])) {
                        echo htmlspecialchars(exportSafeText($attendance[$e["employee_id"]][$d]["code"]), ENT_QUOTES, 'UTF-8');
                    }
                    ?>
                </td>
            <?php } ?>
        </tr>
    <?php } ?>
</table>
<?php
require_once "includes/auth_check.php";
require_once "config/database.php";

$month = validMonthValue($_GET["month"] ?? date("Y-m")) ?: date("Y-m");
$selected_location_id = validPositiveInt($_GET["location_id"] ?? null) ?: 0;
$locations = [];
$branch_name = "";
$branch_id = validPositiveInt($_GET["branch_id"] ?? null) ?: "";

$user_id = $_SESSION["user_id"];
$user_role = $_SESSION["role"];
$user_branch_id = "";

$user_result = preparedResult($conn, "SELECT branch_id FROM users WHERE user_id = ? LIMIT 1", "i", [$user_id]);

if (!$user_result || $user_result->num_rows == 0) {
    error_log("Payroll user record not found.");
    exit("Unable to load payroll.");
}

$user_row = $user_result->fetch_assoc();
$user_branch_id = $user_row["branch_id"];

$branch_name_result = preparedResult($conn, "SELECT branch_name FROM branches WHERE branch_id = ? LIMIT 1", "i", [(int)$user_branch_id]);

if ($branch_name_result && $branch_name_result->num_rows > 0) {
    $branch_name_row = $branch_name_result->fetch_assoc();
    $branch_name = $branch_name_row["branch_name"];
}

if ($user_role == "Branch User") {
    $branch_id = $user_branch_id;
}

if ($user_role == "Branch User") {
    $branches = preparedResult($conn, "SELECT branch_id, branch_name FROM branches WHERE branch_id = ? ORDER BY branch_name", "i", [(int)$user_branch_id]);
} else {
    $branches = $conn->query("
        SELECT branch_id, branch_name
        FROM branches
        ORDER BY branch_name
    ");
}

if ($branch_id != "") {
    $location_result = preparedResult($conn, "SELECT location_id, location_name FROM branch_locations WHERE branch_id = ? AND is_active = 1 ORDER BY location_name", "i", [(int)$branch_id]);

    if ($location_result) {
        while ($loc = $location_result->fetch_assoc()) {
            $locations[] = $loc;
        }
    }
}

$employees = [];
$attendance = [];
$days = 0;
$selected_year = "";
$leave_policy_map = [];
$leave_used_map = [];

if ($branch_id != "") {

    $start = $month . "-01";
    $end = date("Y-m-t", strtotime($start));
    $days = (int)date("t", strtotime($start));
    $selected_year = date("Y", strtotime($start));
    $location_condition = $selected_location_id > 0 ? " AND location_id = ?" : "";
    $attendance_location_condition = $selected_location_id > 0 ? " AND a.location_id = ?" : "";
    $used_location_condition = $selected_location_id > 0 ? " AND a.location_id = ?" : "";

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
    error_log("Payroll employee query failed: " . $conn->error);
    exit("Unable to load employees.");
}

    while ($r = $emp->fetch_assoc()) {
        $employees[] = $r;
    }

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
    error_log("Payroll attendance query failed: " . $conn->error);
    exit("Unable to load attendance.");
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

    /* Leave policy map for CL, SL, EL by employee category and year */
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
        error_log("Payroll leave policy query failed: " . $conn->error);
        exit("Unable to load leave policy.");
}

    while ($p = $policy_result->fetch_assoc()) {
        $leave_policy_map[$p["employee_category"]][$p["leave_code"]] = (float)$p["entitled_days"];
    }

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
    error_log("Payroll leave usage query failed: " . $conn->error);
    exit("Unable to load leave usage.");
}

    while ($u = $used_result->fetch_assoc()) {
        $leave_used_map[$u["employee_id"]][$u["leave_code"]] = (float)$u["used_days"];
    }
}

$pageTitle = "Monthly Payroll Attendance Sheet";
$pageSubtitle = "Review monthly attendance matrix with status totals, OT hours, expenses, and yearly leave balances.";
$basePath = "";

define('APP_INCLUDED', true);
require_once "includes/header.php";
?>

<form method="get">
    <div class="top-filters-flex">

        <div class="filter-box">
            <label for="month">Month</label>
            <input type="month" id="month" name="month" value="<?php echo htmlspecialchars($month); ?>">
        </div>

        <div class="filter-box">
    <label for="branch_id">Branch</label>

    <?php if ($user_role == "Branch User") { ?>
    <input type="text" value="<?php echo htmlspecialchars($branch_name); ?>" readonly>
<?php } else { ?>
        <select id="branch_id" name="branch_id">
            <option value="">Select Branch</option>
            <?php while($b = $branches->fetch_assoc()) { ?>
                <option value="<?php echo $b["branch_id"]; ?>" <?php if($branch_id == $b["branch_id"]) echo "selected"; ?>>
                    <?php echo htmlspecialchars($b["branch_name"]); ?>
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
                <button type="submit" class="btn-generate">Generate</button>

                <?php if ($branch_id != "") { ?>
                    <a class="btn-excel" href="export_payroll.php?month=<?php echo urlencode($month); ?>&branch_id=<?php echo urlencode($branch_id); ?>&location_id=<?php echo urlencode($selected_location_id); ?>">
                        📊 Export to Excel
                    </a>
                <?php } ?>

                <a class="btn-cancel" href="javascript:history.back()">Cancel</a>
            </div>
        </div>

    </div>
</form>


<?php if ($branch_id != "" && count($employees) > 0) { ?>

<?php
$summary_present = 0;
$summary_absent = 0;
$summary_leave = 0;
$summary_half = 0;
$summary_wo = 0;
$summary_paid_days = 0;

$summary_ot = 0;
$summary_expense = 0;

$summary_cl_used = 0;
$summary_sl_used = 0;
$summary_el_used = 0;

$summary_cl_bal = 0;
$summary_sl_bal = 0;
$summary_el_bal = 0;
?>

<div class="table-wrap">
    <table class="payroll-sheet-table">
        <thead>
            <tr>
                <th style="width:140px;">Employee No</th>
                <th style="width:220px;">Employee</th>
                <th style="width:120px;">Category</th>
                <th style="width:70px;">P</th>
                <th style="width:70px;">A</th>
                <th style="width:70px;">L</th>
                <th style="width:70px;">H</th>
<th style="width:70px;">WO</th>
<th style="width:100px;">Paid Days</th>
<th style="width:100px;">OT</th>
                <th style="width:140px;">Expense</th>

                <th style="width:80px;">CL Allot</th>
                <th style="width:80px;">CL Used</th>
                <th style="width:80px;">CL Bal</th>

                <th style="width:80px;">SL Allot</th>
                <th style="width:80px;">SL Used</th>
                <th style="width:80px;">SL Bal</th>

                <th style="width:80px;">EL Allot</th>
                <th style="width:80px;">EL Used</th>
                <th style="width:80px;">EL Bal</th>

                <?php for ($d = 1; $d <= $days; $d++) { ?>
                    <th style="width:60px;"><?php echo $d; ?></th>
                <?php } ?>
            </tr>
        </thead>
        <tbody>

            <?php foreach ($employees as $e) { ?>
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
    $leave++;
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
                
$summary_present += $present;
$summary_absent += $absent;
$summary_leave += $leave;
$summary_half += $half;
$summary_wo += $weekly_off;
$summary_paid_days += $paid_days;

$summary_ot += $total_ot;
$summary_expense += $total_expense;

$summary_cl_used += $cl_used;
$summary_sl_used += $sl_used;
$summary_el_used += $el_used;

$summary_cl_bal += $cl_bal;
$summary_sl_bal += $sl_bal;
$summary_el_bal += $el_bal;

                ?>

                <tr>
                    <td><?php echo htmlspecialchars($e["employee_no"] ?? ""); ?></td>
                    <td><?php echo htmlspecialchars($e["employee_name"] ?? ""); ?></td>
                    <td><?php echo htmlspecialchars($e["employee_category"] ?? ""); ?></td>
                    <td><?php echo $present; ?></td>
                    <td><?php echo $absent; ?></td>
                    <td><?php echo $leave; ?></td>
                    <td><?php echo $half; ?></td>
<td><?php echo $weekly_off; ?></td>
<td style="text-align:right;"><?php echo number_format($paid_days, 2); ?></td>
<td style="text-align:right;"><?php echo number_format($total_ot, 2); ?></td>
                    <td style="text-align:right;">₹ <?php echo number_format($total_expense, 2); ?></td>

                    <td style="text-align:right;"><?php echo number_format($cl_allot, 2); ?></td>
                    <td style="text-align:right;"><?php echo number_format($cl_used, 2); ?></td>
                    <td style="text-align:right;"><?php echo number_format($cl_bal, 2); ?></td>

                    <td style="text-align:right;"><?php echo number_format($sl_allot, 2); ?></td>
                    <td style="text-align:right;"><?php echo number_format($sl_used, 2); ?></td>
                    <td style="text-align:right;"><?php echo number_format($sl_bal, 2); ?></td>

                    <td style="text-align:right;"><?php echo number_format($el_allot, 2); ?></td>
                    <td style="text-align:right;"><?php echo number_format($el_used, 2); ?></td>
                    <td style="text-align:right;"><?php echo number_format($el_bal, 2); ?></td>

                    <?php for ($d = 1; $d <= $days; $d++) { ?>
                        <?php
                        $status = "";
                        if (isset($attendance[$e["employee_id"]][$d])) {
                            $status = $attendance[$e["employee_id"]][$d]["code"];
                        }
                        ?>
                        <td><?php echo htmlspecialchars($status); ?></td>
                    <?php } ?>
                </tr>

            <?php } ?>

        </tbody>
    </table>
</div>

<div class="panel-card" style="margin-top:16px; margin-bottom:16px;">

<strong>Branch Summary</strong> — <?php echo htmlspecialchars($month); ?>

<br><br>

<strong>Employees:</strong> <?php echo count($employees); ?>

<br><br>

<strong>Attendance</strong><br>
Present: <?php echo $summary_present; ?> |
Absent: <?php echo $summary_absent; ?> |
Leave: <?php echo $summary_leave; ?> |
Half Day: <?php echo $summary_half; ?> |
Weekly Off: <?php echo $summary_wo; ?> |
Paid Days: <?php echo number_format($summary_paid_days, 2); ?>

<br><br>

<strong>Leave Summary</strong><br>
CL Used: <?php echo $summary_cl_used; ?> |
CL Balance: <?php echo $summary_cl_bal; ?><br>

SL Used: <?php echo $summary_sl_used; ?> |
SL Balance: <?php echo $summary_sl_bal; ?><br>

EL Used: <?php echo $summary_el_used; ?> |
EL Balance: <?php echo $summary_el_bal; ?>

<br><br>

<strong>Financial</strong><br>
Total OT Hours: <?php echo number_format($summary_ot,2); ?> |
Total Other Expense: ₹ <?php echo number_format($summary_expense,2); ?>

</div>

<?php } elseif ($branch_id != "") { ?>

<div class="panel-card" style="margin-top:16px;">
    No payroll attendance records found for the selected month and branch.
</div>

<?php } ?>

<?php require_once "includes/footer.php"; ?>
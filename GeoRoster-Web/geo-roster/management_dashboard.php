<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once "includes/auth_check.php";
require_once "config/database.php";

$user_role = $_SESSION["role"] ?? "";

if ($user_role !== "Admin" && $user_role !== "HO User") {
    $_SESSION["flash_error"] = "Access denied.";
    header("Location: dashboard.php");
    exit;
}

$selected_date = $_GET["date"] ?? date("Y-m-d");
$selected_month = $_GET["month"] ?? date("Y-m");
$selected_branch_id = $_GET["branch_id"] ?? "";

$branches = $conn->query("
    SELECT branch_id, branch_name
    FROM branches
    ORDER BY branch_name
");

/* Branch location toggle status */
$location_toggle_where = "WHERE bl.is_active = 1";
if ($selected_branch_id !== "") {
    $location_toggle_where .= " AND bl.branch_id = '" . $conn->real_escape_string($selected_branch_id) . "'";
}

$location_toggle_sql = "
    SELECT
        b.branch_name,
        bl.location_name,
        bl.is_ot_enabled,
        bl.is_expense_enabled,
        bl.is_active
    FROM branch_locations bl
    INNER JOIN branches b ON bl.branch_id = b.branch_id
    $location_toggle_where
    ORDER BY b.branch_name, bl.location_name
";

$location_toggle_result = $conn->query($location_toggle_sql);
$location_toggle_rows = [];
$location_toggle_summary = [
    "total_locations" => 0,
    "ot_enabled_count" => 0,
    "ot_disabled_count" => 0,
    "expense_enabled_count" => 0,
    "expense_disabled_count" => 0,
];

if ($location_toggle_result) {
    while ($row = $location_toggle_result->fetch_assoc()) {
        $location_toggle_rows[] = $row;
        $location_toggle_summary["total_locations"]++;

        if ((int)($row["is_ot_enabled"] ?? 0) === 1) {
            $location_toggle_summary["ot_enabled_count"]++;
        } else {
            $location_toggle_summary["ot_disabled_count"]++;
        }

        if ((int)($row["is_expense_enabled"] ?? 0) === 1) {
            $location_toggle_summary["expense_enabled_count"]++;
        } else {
            $location_toggle_summary["expense_disabled_count"]++;
        }
    }
}
/* Top summary */
$top_where = " WHERE attendance_date = '$selected_date' ";
if ($selected_branch_id !== "") {
    $top_where .= " AND branch_id = '$selected_branch_id' ";
}

$top_sql = "
    SELECT
        COUNT(*) AS total_records,
        SUM(CASE WHEN status_code='P' THEN 1 ELSE 0 END) AS present_count,
        SUM(CASE WHEN status_code='A' THEN 1 ELSE 0 END) AS absent_count,
        SUM(CASE WHEN status_code='L' THEN 1 ELSE 0 END) AS leave_count,
        SUM(CASE WHEN status_code='H' THEN 1 ELSE 0 END) AS half_count,
        SUM(ot_hours) AS total_ot,
        SUM(other_expense) AS total_expense
    FROM attendance_entries
    $top_where
";

$top_result = $conn->query($top_sql);
$top = [
    "total_records" => 0,
    "present_count" => 0,
    "absent_count" => 0,
    "leave_count" => 0,
    "half_count" => 0,
    "total_ot" => 0,
    "total_expense" => 0
];

if ($top_result && $top_result->num_rows > 0) {
    $top = $top_result->fetch_assoc();
}

/* Total employees */
$emp_where = "";
if ($selected_branch_id !== "") {
    $emp_where = " WHERE branch_id = '$selected_branch_id' ";
}

$emp_count_sql = "SELECT COUNT(*) AS total_employees FROM employees $emp_where";
$emp_count_result = $conn->query($emp_count_sql);
$total_employees = 0;
if ($emp_count_result && $emp_count_result->num_rows > 0) {
    $emp_count_row = $emp_count_result->fetch_assoc();
    $total_employees = (int)($emp_count_row["total_employees"] ?? 0);
}

$attendance_percent = 0;
if ($total_employees > 0) {
    $attendance_percent = (($top["present_count"] ?? 0) / $total_employees) * 100;
}

/* Branch-wise today summary */
$branch_today_sql = "
    SELECT
        b.branch_id,
        b.branch_name,
        COUNT(e.employee_id) AS total_employees,
        SUM(CASE WHEN a.status_code='P' THEN 1 ELSE 0 END) AS present_count,
        SUM(CASE WHEN a.status_code='A' THEN 1 ELSE 0 END) AS absent_count,
        SUM(CASE WHEN a.status_code='L' THEN 1 ELSE 0 END) AS leave_count,
        SUM(CASE WHEN a.status_code='H' THEN 1 ELSE 0 END) AS half_count,
        SUM(a.ot_hours) AS total_ot,
        SUM(a.other_expense) AS total_expense
    FROM branches b
    LEFT JOIN employees e ON b.branch_id = e.branch_id
    LEFT JOIN attendance_entries a 
        ON a.employee_id = e.employee_id
        AND a.attendance_date = '$selected_date'
    " . ($selected_branch_id !== "" ? " WHERE b.branch_id = '$selected_branch_id' " : "") . "
    GROUP BY b.branch_id, b.branch_name
    ORDER BY b.branch_name
";

$branch_today_result = $conn->query($branch_today_sql);
$branch_rows = [];
if ($branch_today_result) {
    while ($row = $branch_today_result->fetch_assoc()) {
        $branch_rows[] = $row;
    }
}

/* Branch-wise present vs absent for donut chart */
$donut_sql = "
    SELECT
        b.branch_name,
        SUM(CASE WHEN a.status_code='P' THEN 1 ELSE 0 END) AS present_count,
        SUM(CASE WHEN a.status_code='A' THEN 1 ELSE 0 END) AS absent_count
    FROM branches b
    LEFT JOIN attendance_entries a
        ON b.branch_id = a.branch_id
        AND a.attendance_date = '$selected_date'
    " . ($selected_branch_id !== "" ? " WHERE b.branch_id = '$selected_branch_id' " : "") . "
    GROUP BY b.branch_id, b.branch_name
    ORDER BY b.branch_name
";

$donut_result = $conn->query($donut_sql);

$donut_labels = [];
$donut_present = [];
$donut_absent = [];

if ($donut_result) {
    while ($row = $donut_result->fetch_assoc()) {
        $donut_labels[] = $row["branch_name"] ?? "";
        $donut_present[] = (int)($row["present_count"] ?? 0);
        $donut_absent[] = (int)($row["absent_count"] ?? 0);
    }
}

/* Top 5 absentee branches */
$top_absent_sql = "
    SELECT
        b.branch_id,
        b.branch_name,
        SUM(CASE WHEN a.status_code='A' THEN 1 ELSE 0 END) AS absent_count
    FROM branches b
    LEFT JOIN attendance_entries a
        ON b.branch_id = a.branch_id
        AND a.attendance_date = '$selected_date'
    " . ($selected_branch_id !== "" ? " WHERE b.branch_id = '$selected_branch_id' " : "") . "
    GROUP BY b.branch_id, b.branch_name
    ORDER BY absent_count DESC, b.branch_name ASC
    LIMIT 5
";

$top_absent_result = $conn->query($top_absent_sql);
$top_absent_rows = [];

if ($top_absent_result) {
    while ($row = $top_absent_result->fetch_assoc()) {
        $top_absent_rows[] = $row;
    }
}

/* Absent employees list for top 5 branches (SAFE VERSION using branch_id) */
$absent_employees = [];

if (count($top_absent_rows) > 0) {

    // Extract branch IDs safely
    $branch_ids = array_map(function($r){
        return (int)$r["branch_id"];
    }, $top_absent_rows);

    $branch_ids_str = implode(",", $branch_ids);

    $absent_emp_sql = "
        SELECT
            b.branch_name,
            e.employee_name
        FROM attendance_entries a
        INNER JOIN employees e ON a.employee_id = e.employee_id
        INNER JOIN branches b ON a.branch_id = b.branch_id
        WHERE a.attendance_date = '$selected_date'
        AND a.status_code = 'A'
        AND b.branch_id IN ($branch_ids_str)
        ORDER BY b.branch_name, e.employee_name
    ";

    $absent_emp_result = $conn->query($absent_emp_sql);

    if ($absent_emp_result) {
        while ($row = $absent_emp_result->fetch_assoc()) {
            $absent_employees[$row["branch_name"]][] = $row["employee_name"];
        }
    }
}

/* Monthly trend */
$month_start = $selected_month . "-01";
$month_end = date("Y-m-t", strtotime($month_start));

$trend_where = " WHERE attendance_date BETWEEN '$month_start' AND '$month_end' ";
if ($selected_branch_id !== "") {
    $trend_where .= " AND branch_id = '$selected_branch_id' ";
}

$trend_sql = "
    SELECT
        attendance_date,
        SUM(CASE WHEN status_code='P' THEN 1 ELSE 0 END) AS present_count,
        SUM(CASE WHEN status_code='A' THEN 1 ELSE 0 END) AS absent_count,
        SUM(CASE WHEN status_code='L' THEN 1 ELSE 0 END) AS leave_count,
        SUM(CASE WHEN status_code='H' THEN 1 ELSE 0 END) AS half_count
    FROM attendance_entries
    $trend_where
    GROUP BY attendance_date
    ORDER BY attendance_date
";

$trend_result = $conn->query($trend_sql);

$trend_labels = [];
$trend_present = [];
$trend_absent = [];
$trend_leave = [];
$trend_half = [];

if ($trend_result) {
    while ($row = $trend_result->fetch_assoc()) {
        $trend_labels[] = $row["attendance_date"];
        $trend_present[] = (int)($row["present_count"] ?? 0);
        $trend_absent[] = (int)($row["absent_count"] ?? 0);
        $trend_leave[] = (int)($row["leave_count"] ?? 0);
        $trend_half[] = (int)($row["half_count"] ?? 0);
    }
}

/* Staff vs Labour summary for selected month */
$category_where = " WHERE a.attendance_date BETWEEN '$month_start' AND '$month_end' ";
if ($selected_branch_id !== "") {
    $category_where .= " AND a.branch_id = '$selected_branch_id' ";
}

$category_sql = "
    SELECT
        e.employee_category,
        SUM(CASE WHEN a.status_code='P' THEN 1 ELSE 0 END) AS present_count,
        SUM(CASE WHEN a.status_code='A' THEN 1 ELSE 0 END) AS absent_count,
        SUM(CASE WHEN a.status_code='L' THEN 1 ELSE 0 END) AS leave_count,
        SUM(CASE WHEN a.status_code='H' THEN 1 ELSE 0 END) AS half_count
    FROM attendance_entries a
    INNER JOIN employees e ON a.employee_id = e.employee_id
    $category_where
    GROUP BY e.employee_category
";

$category_result = $conn->query($category_sql);

$category_labels = [];
$category_present = [];
$category_absent = [];

if ($category_result) {
    while ($row = $category_result->fetch_assoc()) {
        $category_labels[] = $row["employee_category"] ?: "Unknown";
        $category_present[] = (int)($row["present_count"] ?? 0);
        $category_absent[] = (int)($row["absent_count"] ?? 0);
    }
}

$pageTitle = "Management Dashboard";
$pageSubtitle = "Branch-wise daily overview and monthly attendance trend.";
$basePath = "";

define('APP_INCLUDED', true);
require_once "includes/header.php";
?>

<form method="get">
    <div class="top-filters-flex">

        <div class="filter-box">
            <label for="date">Daily Snapshot Date</label>
            <input type="date" id="date" name="date" value="<?php echo htmlspecialchars($selected_date); ?>">
        </div>

        <div class="filter-box">
            <label for="month">Trend Month</label>
            <input type="month" id="month" name="month" value="<?php echo htmlspecialchars($selected_month); ?>">
        </div>

        <div class="filter-box">
            <label for="branch_id">Branch</label>
            <select id="branch_id" name="branch_id">
                <option value="">All Branches</option>
                <?php while($b = $branches->fetch_assoc()) { ?>
                    <option value="<?php echo $b["branch_id"]; ?>" <?php if($selected_branch_id == $b["branch_id"]) echo "selected"; ?>>
                        <?php echo htmlspecialchars($b["branch_name"]); ?>
                    </option>
                <?php } ?>
            </select>
        </div>

        <div class="filter-box button-box">
            <label>&nbsp;</label>
            <div class="action-buttons">
                <button type="submit" class="btn-generate">Load Dashboard</button>
                <a class="btn-cancel" href="dashboard.php">Cancel</a>
            </div>
        </div>

    </div>
</form>

<div class="cards" style="margin-bottom:18px;">
    <div class="card">
        <div class="card-icon">👥</div>
        <strong><?php echo $total_employees; ?></strong><br>
        Total Employees
    </div>

    <div class="card">
        <div class="card-icon">✅</div>
        <strong><?php echo (int)($top["present_count"] ?? 0); ?></strong><br>
        Present
    </div>

    <div class="card">
        <div class="card-icon">❌</div>
        <strong><?php echo (int)($top["absent_count"] ?? 0); ?></strong><br>
        Absent
    </div>

    <div class="card">
        <div class="card-icon">📝</div>
        <strong><?php echo (int)($top["leave_count"] ?? 0); ?></strong><br>
        Leave
    </div>

    <div class="card">
        <div class="card-icon">⏱️</div>
        <strong><?php echo number_format((float)($top["total_ot"] ?? 0), 2); ?></strong><br>
        OT Hours
    </div>

    <div class="card">
        <div class="card-icon">💰</div>
        <strong>₹ <?php echo number_format((float)($top["total_expense"] ?? 0), 2); ?></strong><br>
        Expense
    </div>

    <div class="card">
        <div class="card-icon">📊</div>
        <strong><?php echo number_format($attendance_percent, 2); ?>%</strong><br>
        Attendance %
    </div>
</div>

<div class="panel-card" style="margin-bottom:18px;">
    <div class="panel-title">Sub-Location OT/Expense Toggle Status</div>

    <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(180px, 1fr)); gap:12px; margin-bottom:14px;">
        <div style="padding:10px 12px; border:1px solid #e2e8f0; border-radius:8px; background:#f8fafc;">
            <div style="font-size:12px; color:#64748b;">Active Sub-Locations</div>
            <div style="font-size:20px; font-weight:700;"><?php echo (int)$location_toggle_summary["total_locations"]; ?></div>
        </div>
        <div style="padding:10px 12px; border:1px solid #e2e8f0; border-radius:8px; background:#f0fdf4;">
            <div style="font-size:12px; color:#166534;">OT Enabled</div>
            <div style="font-size:20px; font-weight:700; color:#166534;"><?php echo (int)$location_toggle_summary["ot_enabled_count"]; ?></div>
        </div>
        <div style="padding:10px 12px; border:1px solid #e2e8f0; border-radius:8px; background:#fef2f2;">
            <div style="font-size:12px; color:#b91c1c;">OT Disabled</div>
            <div style="font-size:20px; font-weight:700; color:#b91c1c;"><?php echo (int)$location_toggle_summary["ot_disabled_count"]; ?></div>
        </div>
        <div style="padding:10px 12px; border:1px solid #e2e8f0; border-radius:8px; background:#f0f9ff;">
            <div style="font-size:12px; color:#0c4a6e;">Expense Enabled</div>
            <div style="font-size:20px; font-weight:700; color:#0c4a6e;"><?php echo (int)$location_toggle_summary["expense_enabled_count"]; ?></div>
        </div>
        <div style="padding:10px 12px; border:1px solid #e2e8f0; border-radius:8px; background:#fff7ed;">
            <div style="font-size:12px; color:#9a3412;">Expense Disabled</div>
            <div style="font-size:20px; font-weight:700; color:#9a3412;"><?php echo (int)$location_toggle_summary["expense_disabled_count"]; ?></div>
        </div>
    </div>

    <?php if (count($location_toggle_rows) > 0) { ?>
        <div class="table-wrap">
            <table style="width:100%; table-layout:fixed;">
                <thead>
                    <tr>
                        <th style="width:220px; text-align:left;">Branch</th>
                        <th style="width:240px; text-align:left;">Sub-Location</th>
                        <th style="width:130px; text-align:center;">OT</th>
                        <th style="width:150px; text-align:center;">Expense</th>
                        <th style="width:120px; text-align:center;">Status</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($location_toggle_rows as $loc) { ?>
                        <?php
                            $ot_on = ((int)($loc["is_ot_enabled"] ?? 0) === 1);
                            $expense_on = ((int)($loc["is_expense_enabled"] ?? 0) === 1);
                            $active = ((int)($loc["is_active"] ?? 0) === 1);
                        ?>
                        <tr>
                            <td style="text-align:left;"><?php echo htmlspecialchars($loc["branch_name"] ?? ""); ?></td>
                            <td style="text-align:left;"><?php echo htmlspecialchars($loc["location_name"] ?? ""); ?></td>
                            <td style="text-align:center; color:<?php echo $ot_on ? '#166534' : '#b91c1c'; ?>; font-weight:600;">
                                <?php echo $ot_on ? 'ON' : 'OFF'; ?>
                            </td>
                            <td style="text-align:center; color:<?php echo $expense_on ? '#0c4a6e' : '#9a3412'; ?>; font-weight:600;">
                                <?php echo $expense_on ? 'ON' : 'OFF'; ?>
                            </td>
                            <td style="text-align:center; color:<?php echo $active ? '#166534' : '#b91c1c'; ?>; font-weight:600;">
                                <?php echo $active ? 'Active' : 'Inactive'; ?>
                            </td>
                        </tr>
                    <?php } ?>
                </tbody>
            </table>
        </div>
    <?php } else { ?>
        <p style="margin:0; color:#64748b;">No active sub-locations found for the selected branch filter.</p>
    <?php } ?>
</div>

<div class="panel-card" style="margin-bottom:18px;">
    <div class="panel-title">Branch-wise Daily Overview</div>
    <div class="table-wrap">
        <table style="width:100%; table-layout:fixed;">
           <thead>
    <tr>
        <th style="width:180px; text-align:left;">Branch</th>
        <th style="width:90px; text-align:right;">Emp</th>
        <th style="width:80px; text-align:right;">P</th>
        <th style="width:80px; text-align:right;">A</th>
        <th style="width:80px; text-align:right;">L</th>
        <th style="width:90px; text-align:right;">Half</th>
        <th style="width:100px; text-align:right;">OT</th>
        <th style="width:120px; text-align:right;">Expense</th>
        <th style="width:100px; text-align:right;">%</th>
    </tr>
</thead>
            <tbody>
                <?php foreach($branch_rows as $r) { ?>
                    <?php
                    $branch_total = (int)($r["total_employees"] ?? 0);
                    $branch_present = (int)($r["present_count"] ?? 0);
                    $branch_percent = $branch_total > 0 ? ($branch_present / $branch_total) * 100 : 0;
                    ?>
                    <tr>
                        <td style="text-align:left;"><?php echo htmlspecialchars($r["branch_name"] ?? ""); ?></td>

<td style="text-align:right;"><?php echo $branch_total; ?></td>
<td style="text-align:right;"><?php echo (int)($r["present_count"] ?? 0); ?></td>
<td style="text-align:right; color:
    <?php echo ($r["absent_count"] > 0 ? '#dc2626' : 'inherit'); ?>">
    <?php echo (int)($r["absent_count"] ?? 0); ?>
</td>
<td style="text-align:right;"><?php echo (int)($r["leave_count"] ?? 0); ?></td>
<td style="text-align:right;"><?php echo (int)($r["half_count"] ?? 0); ?></td>
<td style="text-align:right;"><?php echo number_format((float)($r["total_ot"] ?? 0), 2); ?></td>
<td style="text-align:right;">₹ <?php echo number_format((float)($r["total_expense"] ?? 0), 2); ?></td>
<td style="text-align:right; font-weight:600; color:
    <?php echo ($branch_percent >= 75 ? '#16a34a' : ($branch_percent >= 50 ? '#f59e0b' : '#dc2626')); ?>">
    <?php echo number_format($branch_percent, 2); ?>%
</td>
                    </tr>
                <?php } ?>
            </tbody>
        </table>
    </div>
</div>

<div class="management-main-grid" style="margin-bottom:18px;">

    <div class="panel-card">
        <div class="panel-title">Monthly Attendance Trend</div>
        <canvas id="monthlyTrendChart" height="210"></canvas>
    </div>

    <div class="management-side-stack">
        <div class="panel-card">
            <div class="panel-title small-chart-title">Staff vs Labour</div>
            <canvas id="categoryChart" height="180"></canvas>
        </div>

        <div class="panel-card">
    <div class="panel-title small-chart-title">Branch-wise Present vs Absent</div>

    <div style="height:170px; display:flex; align-items:center; justify-content:center;">
        <canvas id="branchDonutChart"></canvas>
    </div>
</div>
    </div>

</div>

    <div class="panel-card">
    <div class="panel-title">Top 5 Absentee Branches</div>

    <?php if (count($top_absent_rows) > 0) { ?>
        <div style="overflow-x:auto;">
            <table style="width:100%; min-width:unset; table-layout:auto;">
                <thead>
                    <tr>
                        <th style="width:70px;">Rank</th>
                        <th>Branch Name</th>
                        <th style="width:120px;">Absent</th>
                    </tr>
                </thead>
                <tbody>
                    <?php $rank = 1; ?>
                    <?php foreach ($top_absent_rows as $row) { ?>
                        <tr>
                            <td><?php echo $rank; ?></td>
                            <td><?php echo htmlspecialchars($row["branch_name"] ?? ""); ?></td>
                            <td><?php echo (int)($row["absent_count"] ?? 0); ?></td>
                        </tr>
                        <?php $rank++; ?>
                    <?php } ?>
                </tbody>
            </table>
        </div>
    <?php } else { ?>
        <p>No absentee data found for selected date.</p>
    <?php } ?>
        
        <?php if (count($absent_employees) > 0) { ?>

    <div style="margin-top:18px;">
        <strong>Absent Employees (<?php echo htmlspecialchars($selected_date); ?>)</strong>

        <?php foreach ($absent_employees as $branch => $employees) { ?>
            <div style="margin-top:10px; padding:10px; background:#f8fafc; border-radius:6px;">

                <div style="font-weight:600; margin-bottom:6px;">
                    <?php echo htmlspecialchars($branch); ?>
                </div>

                <ul style="margin:0; padding-left:18px;">
                    <?php foreach ($employees as $emp) { ?>
                        <li><?php echo htmlspecialchars($emp); ?></li>
                    <?php } ?>
                </ul>

            </div>
        <?php } ?>

    </div>

<?php } ?>

</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
window.managementDashboardData = {
    trendLabels: <?php echo json_encode($trend_labels); ?>,
    trendPresent: <?php echo json_encode($trend_present); ?>,
    trendAbsent: <?php echo json_encode($trend_absent); ?>,
    trendLeave: <?php echo json_encode($trend_leave); ?>,
    trendHalf: <?php echo json_encode($trend_half); ?>,
    categoryLabels: <?php echo json_encode($category_labels); ?>,
    categoryPresent: <?php echo json_encode($category_present); ?>,
    categoryAbsent: <?php echo json_encode($category_absent); ?>,
    donutLabels: <?php echo json_encode($donut_labels); ?>,
    donutPresent: <?php echo json_encode($donut_present); ?>,
    donutAbsent: <?php echo json_encode($donut_absent); ?>
};
</script>

<?php require_once "includes/footer.php"; ?>
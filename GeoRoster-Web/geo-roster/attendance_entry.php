<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once "includes/auth_check.php";
require_once "config/database.php";

$user_id = $_SESSION["user_id"];
$user_role = $_SESSION["role"];
$has_ot_expense_override = ($user_role === "HO User" || $user_role === "Admin");

$date = date("Y-m-d");
if (isset($_GET["attendance_date"]) && $_GET["attendance_date"] != "") {
    $date = $_GET["attendance_date"];
}

$selected_branch_id = "";
$user_branch_id = "";
$selected_category = isset($_GET["employee_category"]) ? $_GET["employee_category"] : "All";
$selected_location_id = isset($_GET["location_id"]) ? (int)$_GET["location_id"] : 0;
$locations = [];

$user_result = $conn->query("
    SELECT user_id, full_name, role_name, branch_id
    FROM users
    WHERE user_id = '$user_id'
    LIMIT 1
");

if (!$user_result || $user_result->num_rows == 0) {
    die("User record not found.");
}

$user_row = $user_result->fetch_assoc();
$user_branch_id = $user_row["branch_id"];

if ($user_role == "Branch User") {
    $selected_branch_id = $user_branch_id;
} else {
    if (isset($_GET["branch_id"])) {
        $selected_branch_id = $_GET["branch_id"];
    }
}

$branches = $conn->query("SELECT branch_id, branch_name FROM branches ORDER BY branch_name");
if (!$branches) {
    die("Branch query failed: " . $conn->error);
}

if ($selected_branch_id != "") {
    $location_result = $conn->query("
        SELECT location_id, location_name
        FROM branch_locations
        WHERE branch_id = '$selected_branch_id'
        AND is_active = 1
        ORDER BY location_name
    ");

    if ($location_result) {
        while ($loc = $location_result->fetch_assoc()) {
            $locations[] = $loc;
        }
    }
}

$leave_types = [];
$leave_type_result = $conn->query("
    SELECT leave_type_id, leave_code, leave_name
    FROM leave_types
    WHERE is_active = 1
    ORDER BY leave_code
");

if (!$leave_type_result) {
    die("Leave type query failed: " . $conn->error);
}

while ($lt = $leave_type_result->fetch_assoc()) {
    $leave_types[] = $lt;
}

$selected_year = date("Y", strtotime($date));
$leave_balance_map = [];

$employee_rows = [];
$existing_attendance = [];

if ($selected_branch_id != "") {

    $attendance_result = $conn->query("
    SELECT employee_id, status_code, leave_type_id, remarks, ot_hours, other_expense
    FROM attendance_entries
    WHERE branch_id = '$selected_branch_id'
    AND attendance_date = '$date'
");

    if ($attendance_result) {
        while ($a = $attendance_result->fetch_assoc()) {
            $existing_attendance[$a["employee_id"]] = [
    "status_code" => $a["status_code"],
    "leave_type_id" => $a["leave_type_id"],
    "remarks" => $a["remarks"],
    "ot_hours" => $a["ot_hours"],
    "other_expense" => $a["other_expense"]
];
        }
    }

    $category_condition = "";
if ($selected_category == "Staff" || $selected_category == "Labour") {
    $category_condition .= " AND e.employee_category = '$selected_category' ";
}

$location_condition = "";
if ($selected_location_id > 0) {
    $location_condition .= " AND e.location_id = '$selected_location_id' ";
}

    $employees = $conn->query("
    SELECT 
        e.employee_id,
        e.employee_no,
        e.employee_name,
        e.employee_category,
        e.branch_id,
        e.location_id,
        b.branch_name,
        bl.location_name,
        bl.is_ot_enabled,
        bl.is_expense_enabled
    FROM employees e
    LEFT JOIN branches b ON e.branch_id = b.branch_id
    LEFT JOIN branch_locations bl ON e.location_id = bl.location_id
    WHERE e.branch_id = '$selected_branch_id'
    $category_condition
    $location_condition
    ORDER BY 
        CASE 
            WHEN e.employee_category = 'Staff' THEN 1
            WHEN e.employee_category = 'Labour' THEN 2
            ELSE 3
        END,
        e.employee_name
");

    if (!$employees) {
        die("Employee query failed: " . $conn->error);
    }

    while ($row = $employees->fetch_assoc()) {
        $employee_rows[] = $row;

        $employee_id = (int)$row["employee_id"];
        $employee_category = $row["employee_category"];

        foreach ($leave_types as $lt) {
            $current_leave_type_id = (int)$lt["leave_type_id"];

            $policy_result = $conn->query("\n                SELECT entitled_days\n                FROM leave_policy\n                WHERE policy_year = '$selected_year'\n                AND employee_category = '" . $conn->real_escape_string($employee_category) . "'\n                AND leave_type_id = '$current_leave_type_id'\n                LIMIT 1\n            ");

            $entitled = 0;
            if ($policy_result && $policy_result->num_rows > 0) {
                $policy_row = $policy_result->fetch_assoc();
                $entitled = (float)$policy_row["entitled_days"];
            }

            $availed_result = $conn->query("\n                SELECT COUNT(*) AS used_days\n                FROM attendance_entries\n                WHERE employee_id = '$employee_id'\n                AND status_code = 'L'\n                AND leave_type_id = '$current_leave_type_id'\n                AND YEAR(attendance_date) = '$selected_year'\n            ");

            $availed = 0;
            if ($availed_result) {
                $availed_row = $availed_result->fetch_assoc();
                $availed = (float)$availed_row["used_days"];
            }

            $balance = $entitled - $availed;

            $leave_balance_map[$employee_id][$current_leave_type_id] = [
                "leave_code" => $lt["leave_code"],
                "entitled" => $entitled,
                "availed" => $availed,
                "balance" => $balance
            ];
        }
    }
}

$pageTitle = "Attendance Entry";
$pageSubtitle = "Create or update daily attendance records branch-wise.";
$basePath = "";

define('APP_INCLUDED', true);
require_once "includes/header.php";
?>

<form method="get" action="attendance_entry.php">
    <div class="attendance-top-grid">

        <div class="filter-box">
    <label>Attendance Date</label>

    <?php $isBranchUser = ($_SESSION["role"] === "Branch User"); ?>

    <?php if ($isBranchUser) { ?>
        <input type="date" value="<?php echo htmlspecialchars($date); ?>" readonly>
        <input type="hidden" name="attendance_date" value="<?php echo htmlspecialchars($date); ?>">
    <?php } else { ?>
        <input 
            type="date"
            name="attendance_date"
            value="<?php echo htmlspecialchars($date); ?>"
        >
    <?php } ?>
</div>

        <div class="filter-box">
            <?php if ($user_role == "Branch User") { ?>

                <label>Branch</label>
                <?php
                $branch_name_result = $conn->query("SELECT branch_name FROM branches WHERE branch_id = '$user_branch_id' LIMIT 1");
                $branch_name = "";
                if ($branch_name_result && $branch_name_result->num_rows > 0) {
                    $branch_name_row = $branch_name_result->fetch_assoc();
                    $branch_name = $branch_name_row["branch_name"];
                }
                ?>
                <input type="text" value="<?php echo htmlspecialchars($branch_name); ?>" readonly>

            <?php } else { ?>

                <label>Branch</label>
                <select name="branch_id" id="branch_id" required>
                    <option value="">Select Branch</option>
                    <?php while ($b = $branches->fetch_assoc()) { ?>
                        <option value="<?php echo $b["branch_id"]; ?>" <?php if ($selected_branch_id == $b["branch_id"]) echo "selected"; ?>>
                            <?php echo $b["branch_name"]; ?>
                        </option>
                    <?php } ?>
                </select>

            <?php } ?>
        </div>

<div class="filter-box">
    <label>Sub-Location</label>
    <select name="location_id">
        <option value="">All Sub-Locations</option>
        <?php foreach ($locations as $loc) { ?>
            <option value="<?php echo $loc["location_id"]; ?>" <?php if ($selected_location_id == $loc["location_id"]) echo "selected"; ?>>
                <?php echo htmlspecialchars($loc["location_name"]); ?>
            </option>
        <?php } ?>
    </select>
</div>

        <div class="filter-box">
            <label>Category Filter</label>
            <select name="employee_category">
                <option value="All" <?php if ($selected_category == "All") echo "selected"; ?>>All</option>
                <option value="Staff" <?php if ($selected_category == "Staff") echo "selected"; ?>>Staff</option>
                <option value="Labour" <?php if ($selected_category == "Labour") echo "selected"; ?>>Labour</option>
            </select>
        </div>

       <div class="button-box">
    <label>&nbsp;</label>
    <div class="action-buttons">
        <button type="submit">Load Attendance</button>
        <a href="dashboard.php" class="btn-secondary-link">Cancel</a>
    </div>
</div>

    </div>
</form>

<?php if ($selected_branch_id != "" && count($employee_rows) > 0) { ?>

<form method="post" action="save_attendance.php">

<input type="hidden" name="attendance_date" value="<?php echo htmlspecialchars($date); ?>">

<div class="top-filters-flex" style="margin-top:0; margin-bottom:12px;">

    <div class="filter-box" style="max-width:520px;">
        <label>&nbsp;</label>
        <div class="search-row" style="margin-bottom:0; max-width:100%;">
            <input type="text" id="employeeSearch" placeholder="Search by employee no, name or category...">
        </div>
    </div>

    <div class="filter-box" style="max-width:260px;">
        <label for="statusFilter">Filter by Status</label>
        <select id="statusFilter">
            <option value="ALL">All Employees</option>
            <option value="A">Absent Only</option>
            <option value="L">Leave Only</option>
            <option value="H">Half Day Only</option>
            <option value="WO">Weekly Off Only</option>
            <option value="EXCEPTION">All Exceptions</option>
        </select>
    </div>

    <div class="filter-box" style="max-width:260px;">
        <label for="bulkStatusSelect">Bulk Status Update</label>
        <select id="bulkStatusSelect">
            <option value="">Select Status</option>
            <option value="P">Present</option>
            <option value="WO">Weekly Off</option>
            <option value="A">Absent</option>
            <option value="H">Half Day</option>
            <option value="L">Leave</option>
        </select>
    </div>

    <div class="button-box">
        <label>&nbsp;</label>
        <div class="action-buttons">
            <button type="button" id="applyBulkStatusBtn">Apply to Visible Rows</button>
        </div>
    </div>

</div> <!-- CLOSE top-filters-flex -->

<div class="table-wrap">

<table id="attendanceTable">
        <thead>
    <tr>
        <th style="width:130px;">Employee No</th>
        <th style="width:170px;">Employee</th>
        <th style="width:130px;">Category</th>
        <th style="width:120px;">Branch</th>
<th style="width:160px;">Sub-Location</th>
<th style="width:150px;">Status</th>
        <th style="width:150px;">Leave Type</th>
        <th style="width:120px;">OT Hours</th>
        <th style="width:140px;">Other Expense</th>
        <th style="width:260px;">Remarks</th>
    </tr>
</thead>

        <tbody>
            <?php
            $present_count = 0;
            $absent_count = 0;
            $leave_count = 0;
            $half_count = 0;
            ?>

            <?php foreach ($employee_rows as $e) {
                $emp_id = $e["employee_id"];
                $saved_status = isset($existing_attendance[$emp_id]) ? $existing_attendance[$emp_id]["status_code"] : "P";
$saved_leave_type = isset($existing_attendance[$emp_id]) ? $existing_attendance[$emp_id]["leave_type_id"] : "";
$saved_ot_hours = isset($existing_attendance[$emp_id]) ? $existing_attendance[$emp_id]["ot_hours"] : "0";
$saved_other_expense = isset($existing_attendance[$emp_id]) ? $existing_attendance[$emp_id]["other_expense"] : "0";
$saved_remarks = isset($existing_attendance[$emp_id]) ? $existing_attendance[$emp_id]["remarks"] : "";
$is_ot_enabled = ((int)($e["is_ot_enabled"] ?? 1) === 1);
$is_expense_enabled = ((int)($e["is_expense_enabled"] ?? 1) === 1);
$can_edit_ot = $has_ot_expense_override || $is_ot_enabled;
$can_edit_expense = $has_ot_expense_override || $is_expense_enabled;

                if ($saved_status == "P") $present_count++;
                if ($saved_status == "A") $absent_count++;
                if ($saved_status == "L") $leave_count++;
                if ($saved_status == "H") $half_count++;
            ?>
            <tr class="attendance-row status-<?php echo strtolower($saved_status); ?>" data-status="<?php echo htmlspecialchars($saved_status); ?>">
                <td><?php echo htmlspecialchars($e["employee_no"]); ?></td>
                <td>
                    <?php echo htmlspecialchars($e["employee_name"]); ?>
                    <input type="hidden" name="employee_id[]" value="<?php echo $e["employee_id"]; ?>">
                </td>
                <td><?php echo htmlspecialchars($e["employee_category"]); ?></td>
                <td>
    <?php echo htmlspecialchars($e["branch_name"]); ?>
    <input type="hidden" name="branch_id[]" value="<?php echo $e["branch_id"]; ?>">
</td>
<td>
    <?php echo htmlspecialchars($e["location_name"] ?? ""); ?>
    <input type="hidden" name="location_id[]" value="<?php echo (int)($e["location_id"] ?? 0); ?>">
</td>
<td>
    <select name="status_code[]" class="status-select">
                        <option value="P" <?php if ($saved_status == "P") echo "selected"; ?>>Present</option>
                        <option value="A" <?php if ($saved_status == "A") echo "selected"; ?>>Absent</option>
                        <option value="L" <?php if ($saved_status == "L") echo "selected"; ?>>Leave</option>
                        <option value="H" <?php if ($saved_status == "H") echo "selected"; ?>>Half Day</option>
                        <option value="WO" <?php if ($saved_status == "WO") echo "selected"; ?>>Weekly Off</option>
                    </select>
                </td>
                <td>
                    <select name="leave_type_id[]" class="leave-select">
                        <option value="">--Select--</option>
                        <?php foreach ($leave_types as $lt) {
                            $lt_id = (int)$lt["leave_type_id"];
                            $lt_balance = $leave_balance_map[$emp_id][$lt_id]["balance"] ?? 0;
                            $lt_code = $leave_balance_map[$emp_id][$lt_id]["leave_code"] ?? $lt["leave_code"];
                        ?>
                            <option 
                                value="<?php echo $lt_id; ?>" 
                                <?php if ($saved_leave_type == $lt_id) echo "selected"; ?>
                                data-balance="<?php echo $lt_balance; ?>"
                                data-code="<?php echo htmlspecialchars($lt_code); ?>"
                            >
                                <?php echo htmlspecialchars($lt_code . " (Bal: " . number_format($lt_balance, 2) . ")"); ?>
                            </option>
                        <?php } ?>
                    </select>
                    <div class="leave-warning" style="font-size:12px; color:#b45309; margin-top:4px;"></div>
                </td>
                <td>
    <?php if (!$can_edit_ot && !$has_ot_expense_override) { ?>
        <div style="font-size:11px;color:#9ca3af;">OT disabled</div>
    <?php } elseif ($has_ot_expense_override && !$is_ot_enabled) { ?>
        <div style="font-size:11px;color:#0f766e;">Role override</div>
    <?php } ?>

    <input 
        type="number"
        name="ot_hours[]"
        class="ot-input"
        value="<?php echo $can_edit_ot ? htmlspecialchars($saved_ot_hours) : "0"; ?>"
        step="0.25"
        min="0"
        max="12"
        placeholder="0"
        style="text-align:right; <?php echo !$can_edit_ot ? 'background:#f1f5f9; color:#64748b; cursor:not-allowed;' : ''; ?>"
        <?php echo !$can_edit_ot ? 'readonly title="OT disabled for this location"' : ''; ?>
    >
</td>

<td>
    <?php if (!$can_edit_expense && !$has_ot_expense_override) { ?>
        <div style="font-size:11px;color:#9ca3af;">Expense disabled</div>
    <?php } elseif ($has_ot_expense_override && !$is_expense_enabled) { ?>
        <div style="font-size:11px;color:#0f766e;">Role override</div>
    <?php } ?>

    <input 
        type="number"
        name="other_expense[]"
        class="expense-input"
        value="<?php echo $can_edit_expense ? htmlspecialchars($saved_other_expense) : "0"; ?>"
        step="0.01"
        min="0"
        placeholder="0.00"
        style="text-align:right; <?php echo !$can_edit_expense ? 'background:#f1f5f9; color:#64748b; cursor:not-allowed;' : ''; ?>"
        <?php echo !$can_edit_expense ? 'readonly title="Expense disabled for this location"' : ''; ?>
    >
</td>

<td>
    <input 
        type="text"
        name="remarks[]"
        value="<?php echo htmlspecialchars($saved_remarks); ?>"
        placeholder="Optional note"
    >
</td>
            </tr>
            <?php } ?>
        </tbody>
    </table>
</div>
    <div class="summary-box" id="attendanceSummary">
    Present: <?php echo $present_count; ?> |
    Absent: <?php echo $absent_count; ?> |
    Leave: <?php echo $leave_count; ?> |
    Half Day: <?php echo $half_count; ?>
    <br>
    Total OT Hours: 0 |
    Total Other Expense: ₹ 0
</div>

    <div class="form-actions">
    <button type="submit">Save Attendance</button>
    <a href="dashboard.php" class="btn-secondary-link">Cancel</a>
</div>
</form>

<?php } elseif ($selected_branch_id != "") { ?>

<p>No employees found for selected branch.</p>

<?php } ?>

<script>
document.addEventListener("DOMContentLoaded", function () {
    const branchSelect = document.getElementById("branch_id");
    if (!branchSelect) return;

    branchSelect.addEventListener("change", function () {
        const locationSelect = document.querySelector('select[name="location_id"]');
        if (locationSelect) {
            locationSelect.value = "";
        }
        this.form.submit();
    });
});
</script>

<?php require_once "includes/footer.php"; ?>

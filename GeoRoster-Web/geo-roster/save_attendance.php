<?php
require_once "includes/auth_check.php";
require_once "config/database.php";

$user_id = $_SESSION["user_id"];
$user_role = $_SESSION["role"] ?? "";
$has_ot_expense_override = ($user_role === "HO User" || $user_role === "Admin");

$date = $_POST["attendance_date"] ?? "";
$employee_ids = $_POST["employee_id"] ?? [];
$branch_ids = $_POST["branch_id"] ?? [];
$location_ids = $_POST["location_id"] ?? [];
$status_codes = $_POST["status_code"] ?? [];
$leave_type_ids = $_POST["leave_type_id"] ?? [];
$ot_hours_list = $_POST["ot_hours"] ?? [];
$other_expense_list = $_POST["other_expense"] ?? [];
$remarks = $_POST["remarks"] ?? [];

$lwp_leave_type_id = 0;

$lwp_result = $conn->query("\n    SELECT leave_type_id\n    FROM leave_types\n    WHERE leave_code = 'LWP'\n    AND is_active = 1\n    LIMIT 1\n");

if ($lwp_result && $lwp_result->num_rows > 0) {
    $lwp_row = $lwp_result->fetch_assoc();
    $lwp_leave_type_id = (int)$lwp_row["leave_type_id"];
}

$leave_warning_messages = [];

if ($user_role === "Branch User" && $date !== date("Y-m-d")) {
    $_SESSION["flash_error"] = "Branch users can mark attendance only for today's date.";
    header("Location: attendance_entry.php");
    exit;
}

if ($date === "" || empty($employee_ids)) {
    $_SESSION["flash_error"] = "No attendance data received.";
    header("Location: attendance_entry.php");
    exit;
}

$count = count($employee_ids);
$redirect_branch = "";

for ($i = 0; $i < $count; $i++) {

    $emp = (int)$employee_ids[$i];
    $branch = (int)$branch_ids[$i];
    $location = !empty($location_ids[$i]) ? (int)$location_ids[$i] : "NULL";
    $status = trim($status_codes[$i] ?? "");
    $allowed_statuses = ["P", "A", "L", "H", "WO"];
if (!in_array($status, $allowed_statuses, true)) {
    $_SESSION["flash_error"] = "Invalid attendance status received.";
    header("Location: attendance_entry.php?attendance_date=" . urlencode($date) . "&branch_id=" . urlencode($branch));
    exit;
}
    $leave_type_raw = trim($leave_type_ids[$i] ?? "");
    $ot_hours = trim($ot_hours_list[$i] ?? "") === "" ? 0 : (float)$ot_hours_list[$i];
    $other_expense = trim($other_expense_list[$i] ?? "") === "" ? 0 : (float)$other_expense_list[$i];
    $remark = $conn->real_escape_string(trim($remarks[$i] ?? ""));

    $is_ot_enabled = 1;
$is_expense_enabled = 1;

if ($location !== "NULL") {
    $location_config_result = $conn->query("
        SELECT is_ot_enabled, is_expense_enabled
        FROM branch_locations
        WHERE location_id = '$location'
        LIMIT 1
    ");

    if ($location_config_result && $location_config_result->num_rows > 0) {
        $location_config = $location_config_result->fetch_assoc();
        $is_ot_enabled = (int)($location_config["is_ot_enabled"] ?? 1);
        $is_expense_enabled = (int)($location_config["is_expense_enabled"] ?? 1);
    }
}

if (!$has_ot_expense_override && !$is_ot_enabled) {
    $ot_hours = 0;
}

if (!$has_ot_expense_override && !$is_expense_enabled) {
    $other_expense = 0;
}

    $redirect_branch = $branch;

    if ($status !== "L") {
        $leave_type_id = "NULL";
    } else {
        if ($leave_type_raw === "") {
            $_SESSION["flash_error"] = "Leave type is required when status is Leave.";
            header("Location: attendance_entry.php?attendance_date=" . urlencode($date) . "&branch_id=" . urlencode($branch));
            exit;
        }

        $requested_leave_type_id = (int)$leave_type_raw;
        $leave_type_id = $requested_leave_type_id;

        $employee_result = $conn->query("\n            SELECT employee_name, employee_category\n            FROM employees\n            WHERE employee_id = '$emp'\n            LIMIT 1\n        ");

        $employee_name = "Employee";
        $employee_category = "";

        if ($employee_result && $employee_result->num_rows > 0) {
            $employee_row = $employee_result->fetch_assoc();
            $employee_name = $employee_row["employee_name"] ?? "Employee";
            $employee_category = $conn->real_escape_string($employee_row["employee_category"] ?? "");
        }

        $policy_result = $conn->query("\n            SELECT entitled_days\n            FROM leave_policy\n            WHERE policy_year = YEAR('$date')\n            AND employee_category = '$employee_category'\n            AND leave_type_id = '$requested_leave_type_id'\n            LIMIT 1\n        ");

        $entitled = 0;
        if ($policy_result && $policy_result->num_rows > 0) {
            $policy_row = $policy_result->fetch_assoc();
            $entitled = (float)$policy_row["entitled_days"];
        }

        $availed_result = $conn->query("\n            SELECT COUNT(*) AS used_days\n            FROM attendance_entries\n            WHERE employee_id = '$emp'\n            AND status_code = 'L'\n            AND leave_type_id = '$requested_leave_type_id'\n            AND YEAR(attendance_date) = YEAR('$date')\n            AND attendance_date <> '$date'\n        ");

        $availed = 0;
        if ($availed_result) {
            $availed_row = $availed_result->fetch_assoc();
            $availed = (float)$availed_row["used_days"];
        }

        $balance = $entitled - $availed;

        if (
            $balance <= 0 &&
            $lwp_leave_type_id > 0 &&
            $requested_leave_type_id !== $lwp_leave_type_id
        ) {
            $leave_type_id = $lwp_leave_type_id;
            $leave_warning_messages[] = $employee_name . " leave exhausted, saved as LWP.";
        }
    }

    if ($status === "A" || $status === "L" || $status === "WO") {
    $ot_hours = 0;
    $other_expense = 0;
}

    $check = $conn->query("
        SELECT attendance_id
        FROM attendance_entries
        WHERE employee_id = '$emp'
        AND attendance_date = '$date'
        LIMIT 1
    ");

    if ($check && $check->num_rows > 0) {

$sql = "
    UPDATE attendance_entries
    SET 
        branch_id = '$branch',
        location_id = $location,
        status_code = '$status',
        leave_type_id = $leave_type_id,
        ot_hours = '$ot_hours',
        other_expense = '$other_expense',
        remarks = '$remark',
        entered_by = '$user_id'
    WHERE employee_id = '$emp'
    AND attendance_date = '$date'
";

        if (!$conn->query($sql)) {
    $_SESSION["flash_error"] = "Failed to update attendance: " . $conn->error;
    header("Location: attendance_entry.php?attendance_date=" . urlencode($date) . "&branch_id=" . urlencode($branch));
    exit;
}

    } else {

    $sql = "
    INSERT INTO attendance_entries
    (attendance_date, branch_id, location_id, employee_id, status_code, leave_type_id, ot_hours, other_expense, remarks, entered_by)
    VALUES
    ('$date', '$branch', $location, '$emp', '$status', $leave_type_id, '$ot_hours', '$other_expense', '$remark', '$user_id')
";

    if (!$conn->query($sql)) {
    $_SESSION["flash_error"] = "Failed to insert attendance: " . $conn->error;
    header("Location: attendance_entry.php?attendance_date=" . urlencode($date) . "&branch_id=" . urlencode($branch));
    exit;
}
}
}

if (!empty($leave_warning_messages)) {
    $_SESSION["flash_message"] = "Attendance saved successfully. " . implode(" ", $leave_warning_messages);
} else {
    $_SESSION["flash_message"] = "Attendance saved successfully.";
}

header("Location: attendance_entry.php?attendance_date=" . urlencode($date) . "&branch_id=" . urlencode($redirect_branch));
exit;
?>
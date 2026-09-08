<?php
require_once "includes/auth_check.php";
require_once "config/database.php";
requirePostWithCsrf();

$user_id = $_SESSION["user_id"];
$user_role = $_SESSION["role"] ?? "";
$has_ot_expense_override = ($user_role === "HO User" || $user_role === "Admin");

$date = validDateValue($_POST["attendance_date"] ?? "");
$employee_ids = $_POST["employee_id"] ?? [];
$branch_ids = $_POST["branch_id"] ?? [];
$location_ids = $_POST["location_id"] ?? [];
$status_codes = $_POST["status_code"] ?? [];
$leave_type_ids = $_POST["leave_type_id"] ?? [];
$ot_hours_list = $_POST["ot_hours"] ?? [];
$other_expense_list = $_POST["other_expense"] ?? [];
$remarks = $_POST["remarks"] ?? [];

$lwp_leave_type_id = 0;

$lwp_stmt = $conn->prepare("SELECT leave_type_id FROM leave_types WHERE leave_code = ? AND is_active = 1 LIMIT 1");
$lwp_code = "LWP";
$lwp_stmt->bind_param("s", $lwp_code);
$lwp_stmt->execute();
$lwp_result = $lwp_stmt->get_result();

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
$authorized_employees = [];

if (
    count($branch_ids) !== $count ||
    count($location_ids) !== $count ||
    count($status_codes) !== $count ||
    count($leave_type_ids) !== $count ||
    count($ot_hours_list) !== $count ||
    count($other_expense_list) !== $count ||
    count($remarks) !== $count
) {
    http_response_code(400);
    exit("Invalid attendance batch.");
}

// Validate the complete batch before any row can be written.
for ($i = 0; $i < $count; $i++) {
    $candidate_employee_id = validPositiveInt($employee_ids[$i] ?? null);
    if (!$candidate_employee_id) {
        http_response_code(400);
        exit("Invalid employee.");
    }

    $candidate_employee = requireEmployeeAccess($conn, $candidate_employee_id);
    $candidate_branch = (int)$candidate_employee["branch_id"];
    $candidate_submitted_branch = validPositiveInt($branch_ids[$i] ?? null);
    $candidate_submitted_location = !empty($location_ids[$i]) ? validPositiveInt($location_ids[$i]) : null;
    $candidate_location = !empty($candidate_employee["location_id"]) ? (int)$candidate_employee["location_id"] : null;

    if ($candidate_submitted_branch !== null && $candidate_submitted_branch !== $candidate_branch) {
        http_response_code(403);
        exit("Invalid employee branch.");
    }
    if ($candidate_submitted_location !== $candidate_location) {
        http_response_code(400);
        exit("Invalid employee location.");
    }

    $authorized_employees[$candidate_employee_id] = $candidate_employee;
}

$redirect_branch = "";

for ($i = 0; $i < $count; $i++) {

    $emp = validPositiveInt($employee_ids[$i] ?? null);
    if (!$emp) {
        http_response_code(400);
        exit("Invalid employee.");
    }
    $employee = $authorized_employees[$emp];
    $branch = (int)$employee["branch_id"];
    $submitted_branch = validPositiveInt($branch_ids[$i] ?? null);
    if ($submitted_branch !== null && $submitted_branch !== $branch) {
        http_response_code(403);
        exit("Invalid employee branch.");
    }
    $submitted_location = !empty($location_ids[$i]) ? validPositiveInt($location_ids[$i]) : null;
    $employee_location = !empty($employee["location_id"]) ? (int)$employee["location_id"] : null;
    if ($submitted_location !== $employee_location) {
        http_response_code(400);
        exit("Invalid employee location.");
    }
    $location = $employee_location;
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
    $remark = trim($remarks[$i] ?? "");

    $is_ot_enabled = 1;
$is_expense_enabled = 1;

if ($location !== null) {
    $location_config_stmt = $conn->prepare("SELECT is_ot_enabled, is_expense_enabled FROM branch_locations WHERE location_id = ? AND branch_id = ? LIMIT 1");
    $location_config_stmt->bind_param("ii", $location, $branch);
    $location_config_stmt->execute();
    $location_config_result = $location_config_stmt->get_result();

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
        $leave_type_id = null;
    } else {
        if ($leave_type_raw === "") {
            $_SESSION["flash_error"] = "Leave type is required when status is Leave.";
            header("Location: attendance_entry.php?attendance_date=" . urlencode($date) . "&branch_id=" . urlencode($branch));
            exit;
        }

        $requested_leave_type_id = (int)$leave_type_raw;
        $leave_type_id = $requested_leave_type_id;

        $employee_stmt = $conn->prepare("SELECT employee_name, employee_category FROM employees WHERE employee_id = ? LIMIT 1");
        $employee_stmt->bind_param("i", $emp);
        $employee_stmt->execute();
        $employee_result = $employee_stmt->get_result();

        $employee_name = "Employee";
        $employee_category = "";

        if ($employee_result && $employee_result->num_rows > 0) {
            $employee_row = $employee_result->fetch_assoc();
            $employee_name = $employee_row["employee_name"] ?? "Employee";
            $employee_category = $employee_row["employee_category"] ?? "";
        }

        $policy_stmt = $conn->prepare("SELECT entitled_days FROM leave_policy WHERE policy_year = YEAR(?) AND employee_category = ? AND leave_type_id = ? LIMIT 1");
        $policy_stmt->bind_param("ssi", $date, $employee_category, $requested_leave_type_id);
        $policy_stmt->execute();
        $policy_result = $policy_stmt->get_result();

        $entitled = 0;
        if ($policy_result && $policy_result->num_rows > 0) {
            $policy_row = $policy_result->fetch_assoc();
            $entitled = (float)$policy_row["entitled_days"];
        }

        $availed_stmt = $conn->prepare("SELECT COUNT(*) AS used_days FROM attendance_entries WHERE employee_id = ? AND status_code = 'L' AND leave_type_id = ? AND YEAR(attendance_date) = YEAR(?) AND attendance_date <> ?");
        $availed_stmt->bind_param("iiss", $emp, $requested_leave_type_id, $date, $date);
        $availed_stmt->execute();
        $availed_result = $availed_stmt->get_result();

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

    $check_stmt = $conn->prepare("SELECT attendance_id FROM attendance_entries WHERE employee_id = ? AND attendance_date = ? LIMIT 1");
    $check_stmt->bind_param("is", $emp, $date);
    $check_stmt->execute();
    $check = $check_stmt->get_result();

    if ($check && $check->num_rows > 0) {

        $update_stmt = $conn->prepare("UPDATE attendance_entries SET branch_id = ?, location_id = ?, status_code = ?, leave_type_id = ?, ot_hours = ?, other_expense = ?, remarks = ?, entered_by = ? WHERE employee_id = ? AND attendance_date = ?");
        $update_stmt->bind_param("iisiddsiis", $branch, $location, $status, $leave_type_id, $ot_hours, $other_expense, $remark, $user_id, $emp, $date);

        if (!$update_stmt->execute()) {
    $_SESSION["flash_error"] = "Failed to update attendance.";
    header("Location: attendance_entry.php?attendance_date=" . urlencode($date) . "&branch_id=" . urlencode($branch));
    exit;
}

    } else {

    $insert_stmt = $conn->prepare("INSERT INTO attendance_entries (attendance_date, branch_id, location_id, employee_id, status_code, leave_type_id, ot_hours, other_expense, remarks, entered_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $insert_stmt->bind_param("siiisiddsi", $date, $branch, $location, $emp, $status, $leave_type_id, $ot_hours, $other_expense, $remark, $user_id);

    if (!$insert_stmt->execute()) {
    $_SESSION["flash_error"] = "Failed to insert attendance.";
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
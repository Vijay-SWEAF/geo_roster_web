<?php
require_once "includes/auth_check.php";
require_once "config/database.php";

$selected_year = filter_var($_GET["year"] ?? date("Y"), FILTER_VALIDATE_INT) ?: (int)date("Y");
$branch_id = validPositiveInt($_GET["branch_id"] ?? null) ?: "";
$leave_type_id = $_GET["leave_type_id"] ?? "";

if (($_SESSION["role"] ?? "") === "Branch User") {
    $branch_id = currentUserBranchId($conn);
}
if ($leave_type_id !== "ALL") {
    $leave_type_id = validPositiveInt($leave_type_id) ?: "";
}

if ($branch_id == "" || $leave_type_id == "") {
    $_SESSION["flash_error"] = "Branch and Leave Type are required.";
    header("Location: leave_balance.php");
    exit;
}

$branch_name = "branch";
$leave_code = "leave";
$selected_leave = null;

$branch_result = preparedResult($conn, "SELECT branch_name FROM branches WHERE branch_id = ? LIMIT 1", "i", [(int)$branch_id]);
if ($branch_result && $branch_result->num_rows > 0) {
    $branch_row = $branch_result->fetch_assoc();
    $branch_name = preg_replace('/[^A-Za-z0-9_-]/', '_', $branch_row["branch_name"]);
}

if ($leave_type_id === "ALL") {
    $leave_code = "ALL";
} else {
    $lt_result = preparedResult($conn, "SELECT leave_code, leave_name FROM leave_types WHERE leave_type_id = ? LIMIT 1", "i", [(int)$leave_type_id]);

    if ($lt_result && $lt_result->num_rows > 0) {
        $selected_leave = $lt_result->fetch_assoc();
        $leave_code = $selected_leave["leave_code"];
    }
}

$rows = [];

$emp_result = preparedResult($conn, "SELECT employee_id, employee_no, employee_name, employee_category FROM employees WHERE branch_id = ? AND is_active = 1 ORDER BY employee_name", "i", [(int)$branch_id]);

if ($leave_type_id === "ALL") {

    $all_leave_types = [];
    $lt_result = $conn->query("
        SELECT leave_type_id, leave_code, leave_name
        FROM leave_types
        WHERE is_active = 1
        ORDER BY leave_code
    ");

    while ($lt = $lt_result->fetch_assoc()) {
        $all_leave_types[] = $lt;
    }

    while ($emp = $emp_result->fetch_assoc()) {
        $employee_id = $emp["employee_id"];
        $employee_category = $emp["employee_category"];

        foreach ($all_leave_types as $lt) {
            $current_leave_type_id = $lt["leave_type_id"];

            $policy_result = preparedResult($conn, "SELECT entitled_days FROM leave_policy WHERE policy_year = ? AND employee_category = ? AND leave_type_id = ? LIMIT 1", "isi", [(int)$selected_year, $employee_category, (int)$current_leave_type_id]);
            $entitled = 0;

            if ($policy_result && $policy_result->num_rows > 0) {
                $policy_row = $policy_result->fetch_assoc();
                $entitled = (float)$policy_row["entitled_days"];
            }

            $availed_result = preparedResult($conn, "SELECT COUNT(*) AS used_days FROM attendance_entries WHERE employee_id = ? AND status_code = 'L' AND leave_type_id = ? AND YEAR(attendance_date) = ?", "iii", [(int)$employee_id, (int)$current_leave_type_id, (int)$selected_year]);
            $availed = 0;

            if ($availed_result) {
                $availed_row = $availed_result->fetch_assoc();
                $availed = (float)$availed_row["used_days"];
            }

            $balance = $entitled - $availed;

            $rows[] = [
                "employee_no" => $emp["employee_no"] ?? "",
                "employee_name" => $emp["employee_name"] ?? "",
                "employee_category" => $employee_category ?? "",
                "leave_code" => $lt["leave_code"] ?? "",
                "leave_name" => $lt["leave_name"] ?? "",
                "entitled" => $entitled,
                "availed" => $availed,
                "balance" => $balance
            ];
        }
    }

} else {

    while ($emp = $emp_result->fetch_assoc()) {

        $employee_id = $emp["employee_id"];
        $employee_category = $emp["employee_category"];

        $policy_result = preparedResult($conn, "SELECT entitled_days FROM leave_policy WHERE policy_year = ? AND employee_category = ? AND leave_type_id = ? LIMIT 1", "isi", [(int)$selected_year, $employee_category, (int)$leave_type_id]);
        $entitled = 0;

        if ($policy_result && $policy_result->num_rows > 0) {
            $policy_row = $policy_result->fetch_assoc();
            $entitled = (float)$policy_row["entitled_days"];
        }

        $availed_result = preparedResult($conn, "SELECT COUNT(*) AS used_days FROM attendance_entries WHERE employee_id = ? AND status_code = 'L' AND leave_type_id = ? AND YEAR(attendance_date) = ?", "iii", [(int)$employee_id, (int)$leave_type_id, (int)$selected_year]);
        $availed = 0;

        if ($availed_result) {
            $availed_row = $availed_result->fetch_assoc();
            $availed = (float)$availed_row["used_days"];
        }

        $balance = $entitled - $availed;

        $rows[] = [
            "employee_no" => $emp["employee_no"] ?? "",
            "employee_name" => $emp["employee_name"] ?? "",
            "employee_category" => $employee_category ?? "",
            "leave_code" => $selected_leave["leave_code"] ?? "",
            "leave_name" => $selected_leave["leave_name"] ?? "",
            "entitled" => $entitled,
            "availed" => $availed,
            "balance" => $balance
        ];
    }
}

$filename = "leave_balance_" . $selected_year . "_" . $branch_name . "_" . $leave_code . ".xls";

header("Content-Type: application/vnd.ms-excel");
header("Content-Disposition: attachment; filename=\"$filename\"");
header("Pragma: no-cache");
header("Expires: 0");
?>

<table border="1">
    <tr>
        <th>Employee No</th>
        <th>Employee Name</th>
        <th>Category</th>
        <th>Leave Type</th>
        <th>Entitled</th>
        <th>Availed</th>
        <th>Balance</th>
    </tr>

    <?php foreach($rows as $r) { ?>
    <tr>
        <td><?php echo htmlspecialchars(exportSafeText($r["employee_no"]), ENT_QUOTES, 'UTF-8'); ?></td>
        <td><?php echo htmlspecialchars(exportSafeText($r["employee_name"]), ENT_QUOTES, 'UTF-8'); ?></td>
        <td><?php echo htmlspecialchars(exportSafeText($r["employee_category"]), ENT_QUOTES, 'UTF-8'); ?></td>
        <td><?php echo htmlspecialchars(exportSafeText($r["leave_code"]), ENT_QUOTES, 'UTF-8'); ?></td>
        <td><?php echo number_format((float)$r["entitled"], 2); ?></td>
        <td><?php echo number_format((float)$r["availed"], 2); ?></td>
        <td><?php echo number_format((float)$r["balance"], 2); ?></td>
    </tr>
    <?php } ?>
</table>
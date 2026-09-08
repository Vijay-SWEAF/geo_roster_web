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

$branches = $conn->query("SELECT branch_id, branch_name FROM branches ORDER BY branch_name");
$leave_types = $conn->query("
    SELECT leave_type_id, leave_code, leave_name
    FROM leave_types
    WHERE is_active = 1
    ORDER BY leave_code
");


$rows = [];
$selected_leave = null;

if ($branch_id != "" && $leave_type_id != "") {

    $emp_result = preparedResult($conn, "
        SELECT employee_id, employee_no, employee_name, employee_category
        FROM employees
        WHERE branch_id = ?
        AND is_active = 1
        ORDER BY 
            CASE 
                WHEN employee_category = 'Staff' THEN 1
                WHEN employee_category = 'Labour' THEN 2
                ELSE 3
            END,
            employee_name
    ", "i", [(int)$branch_id]);

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

        $lt_result = preparedResult($conn, "
            SELECT leave_code, leave_name
            FROM leave_types
            WHERE leave_type_id = ?
            LIMIT 1
        ", "i", [(int)$leave_type_id]);

        if ($lt_result && $lt_result->num_rows > 0) {
            $selected_leave = $lt_result->fetch_assoc();
        }

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
}

$pageTitle = "Leave Balance Report";
$pageSubtitle = "Review employee-wise leave entitlement, availed days, and available balance.";
$basePath = "";

define('APP_INCLUDED', true);
require_once "includes/header.php";
?>

<form method="get">
    <div class="top-filters-flex">

        <div class="filter-box">
            <label for="year">Year</label>
            <input type="number" id="year" name="year" value="<?php echo htmlspecialchars($selected_year); ?>" required>
        </div>

        <div class="filter-box">
            <label for="branch_id">Branch</label>
            <select id="branch_id" name="branch_id" required>
                <option value="">Select Branch</option>
                <?php while($b = $branches->fetch_assoc()) { ?>
                    <option value="<?php echo $b["branch_id"]; ?>" <?php if($branch_id == $b["branch_id"]) echo "selected"; ?>>
                        <?php echo htmlspecialchars($b["branch_name"]); ?>
                    </option>
                <?php } ?>
            </select>
        </div>

        <div class="filter-box">
            <label for="leave_type_id">Leave Type</label>
            <select id="leave_type_id" name="leave_type_id" required>
    <option value="">Select Leave Type</option>
    <option value="ALL" <?php if($leave_type_id == "ALL") echo "selected"; ?>>ALL - All Leave Types</option>
    <?php while($lt = $leave_types->fetch_assoc()) { ?>
        <option value="<?php echo $lt["leave_type_id"]; ?>" <?php if($leave_type_id == $lt["leave_type_id"]) echo "selected"; ?>>
            <?php echo htmlspecialchars($lt["leave_code"] . " - " . $lt["leave_name"]); ?>
        </option>
    <?php } ?>
</select>
        </div>

        <div class="filter-box button-box">
            <label>&nbsp;</label>
            <div class="action-buttons">
                <button type="submit" class="btn-generate">View Balance</button>

                <?php if ($branch_id != "" && $leave_type_id != "") { ?>
                   <a class="btn-excel" href="export_leave_balance.php?year=<?php echo urlencode($selected_year); ?>&branch_id=<?php echo urlencode($branch_id); ?>&leave_type_id=<?php echo urlencode($leave_type_id); ?>">
    📊 Export to Excel
</a>
                <?php } ?>

                <a class="btn-cancel" href="javascript:history.back()">Cancel</a>
            </div>
        </div>

    </div>
</form>

<?php if ($branch_id != "" && $leave_type_id != "" && count($rows) > 0) { ?>

    <div class="table-wrap">
        <table class="leave-balance-table">
            <thead>
                <tr>
                    <th style="width:140px;">Employee No</th>
                    <th style="width:220px;">Employee Name</th>
                    <th style="width:120px;">Category</th>
                    <th style="width:140px;">Leave Type</th>
                    <th style="width:120px;">Entitled</th>
                    <th style="width:120px;">Availed</th>
                    <th style="width:120px;">Balance</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach($rows as $r) { ?>
                    <tr>
                        <td><?php echo htmlspecialchars($r["employee_no"] ?? ""); ?></td>
                        <td><?php echo htmlspecialchars($r["employee_name"] ?? ""); ?></td>
                        <td><?php echo htmlspecialchars($r["employee_category"] ?? ""); ?></td>
                        <td><?php echo htmlspecialchars($r["leave_code"] ?? ""); ?></td>
                        <td style="text-align:right;"><?php echo number_format((float)$r["entitled"], 2); ?></td>
                        <td style="text-align:right;"><?php echo number_format((float)$r["availed"], 2); ?></td>
                        <td style="text-align:right;"><?php echo number_format((float)$r["balance"], 2); ?></td>
                    </tr>
                <?php } ?>
            </tbody>
        </table>
    </div>

<?php } elseif ($branch_id != "" && $leave_type_id != "") { ?>

    <div class="panel-card" style="margin-top:16px;">
        No leave balance records found for the selected filters.
    </div>

<?php } ?>

<?php require_once "includes/footer.php"; ?>
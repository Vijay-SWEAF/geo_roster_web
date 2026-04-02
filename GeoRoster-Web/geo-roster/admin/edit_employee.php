<?php
require_once "../includes/auth_check.php";
require_once "../config/database.php";

if ($_SESSION["role"] != "Admin" && $_SESSION["role"] != "HO User") {
    $_SESSION["flash_error"] = "Access denied.";
    header("Location: ../dashboard.php");
    exit;
}

$employee_id = isset($_GET["id"]) ? (int)$_GET["id"] : 0;

if ($employee_id <= 0) {
    $_SESSION["flash_error"] = "Invalid employee.";
    header("Location: employees.php");
    exit;
}

$employee_result = $conn->query("
    SELECT employee_id, employee_no, employee_name, branch_id, location_id, designation, employee_category, is_active
    FROM employees
    WHERE employee_id = $employee_id
    LIMIT 1
");

if (!$employee_result || $employee_result->num_rows == 0) {
    $_SESSION["flash_error"] = "Employee not found.";
    header("Location: employees.php");
    exit;
}

$employee = $employee_result->fetch_assoc();

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $employee_no = trim($_POST["employee_no"] ?? "");
    $employee_name = trim($_POST["employee_name"] ?? "");
    $branch_id = (int)($_POST["branch_id"] ?? 0);
    $location_id = !empty($_POST["location_id"]) ? (int)$_POST["location_id"] : "NULL";
    $designation = trim($_POST["designation"] ?? "");
    $employee_category = trim($_POST["employee_category"] ?? "");
    $is_active = isset($_POST["is_active"]) ? (int)$_POST["is_active"] : 1;

    if ($employee_no === "" || $employee_name === "" || $branch_id <= 0 || $employee_category === "") {
        $_SESSION["flash_error"] = "Please fill all required fields.";
        header("Location: edit_employee.php?id=" . $employee_id);
        exit;
    }

    $employee_no_safe = $conn->real_escape_string($employee_no);
    $employee_name_safe = $conn->real_escape_string($employee_name);
    $designation_safe = $conn->real_escape_string($designation);
    $employee_category_safe = $conn->real_escape_string($employee_category);

    $sql = "
        UPDATE employees
        SET
            employee_no = '$employee_no_safe',
            employee_name = '$employee_name_safe',
            branch_id = $branch_id,
            location_id = $location_id,
            designation = '$designation_safe',
            employee_category = '$employee_category_safe',
            is_active = $is_active
        WHERE employee_id = $employee_id
    ";

    if ($conn->query($sql)) {
        $_SESSION["flash_message"] = "Employee updated successfully.";
        header("Location: employees.php");
        exit;
    } else {
        $_SESSION["flash_error"] = "Failed to update employee.";
        header("Location: edit_employee.php?id=" . $employee_id);
        exit;
    }
}

$branches = $conn->query("
    SELECT branch_id, branch_name
    FROM branches
    ORDER BY branch_name
");

$locations = $conn->query("
    SELECT location_id, branch_id, location_name
    FROM branch_locations
    WHERE is_active = 1
    ORDER BY location_name
");

define('APP_INCLUDED', true);
$pageTitle = "Edit Employee";
$pageSubtitle = "Update employee details and assignment.";
$basePath = "../";

require_once "../includes/header.php";
?>

<div class="panel-card">
    <div class="panel-title">Edit Employee</div>

    <form method="post" class="form-grid">

        <div>
            <label for="employee_no">Employee No</label>
            <input type="text" id="employee_no" name="employee_no"
                   value="<?php echo htmlspecialchars($employee["employee_no"] ?? ""); ?>" required>
        </div>

        <div>
            <label for="employee_name">Employee Name</label>
            <input type="text" id="employee_name" name="employee_name"
                   value="<?php echo htmlspecialchars($employee["employee_name"] ?? ""); ?>" required>
        </div>

        <div>
            <label for="branch_id">Branch</label>
            <select id="branch_id" name="branch_id" required>
                <option value="">Select Branch</option>
                <?php while ($b = $branches->fetch_assoc()) { ?>
                    <option value="<?php echo $b["branch_id"]; ?>"
                        <?php if ((int)$employee["branch_id"] === (int)$b["branch_id"]) echo "selected"; ?>>
                        <?php echo htmlspecialchars($b["branch_name"]); ?>
                    </option>
                <?php } ?>
            </select>
        </div>

        <div>
            <label for="location_id">Sub-Location</label>
            <select id="location_id" name="location_id">
                <option value="">Select Sub-Location</option>
                <?php while ($loc = $locations->fetch_assoc()) { ?>
                    <option value="<?php echo $loc["location_id"]; ?>"
                            data-branch="<?php echo $loc["branch_id"]; ?>"
                        <?php if ((int)$employee["location_id"] === (int)$loc["location_id"]) echo "selected"; ?>>
                        <?php echo htmlspecialchars($loc["location_name"]); ?>
                    </option>
                <?php } ?>
            </select>
        </div>

        <div>
            <label for="designation">Designation</label>
            <input type="text" id="designation" name="designation"
                   value="<?php echo htmlspecialchars($employee["designation"] ?? ""); ?>">
        </div>

        <div>
            <label for="employee_category">Category</label>
            <select id="employee_category" name="employee_category" required>
                <option value="Staff" <?php if (($employee["employee_category"] ?? "") === "Staff") echo "selected"; ?>>Staff</option>
                <option value="Labour" <?php if (($employee["employee_category"] ?? "") === "Labour") echo "selected"; ?>>Labour</option>
            </select>
        </div>

        <div>
            <label for="is_active">Status</label>
            <select id="is_active" name="is_active" required>
                <option value="1" <?php if ((int)$employee["is_active"] === 1) echo "selected"; ?>>Active</option>
                <option value="0" <?php if ((int)$employee["is_active"] === 0) echo "selected"; ?>>Inactive</option>
            </select>
        </div>

        <div class="form-actions">
            <button type="submit">Update Employee</button>
            <a href="employees.php" class="btn-secondary-link">Cancel</a>
        </div>

    </form>
</div>

<script>
document.addEventListener("DOMContentLoaded", function () {
    const branchSelect = document.getElementById("branch_id");
    const locationSelect = document.getElementById("location_id");

    if (!branchSelect || !locationSelect) return;

    const originalOptions = Array.from(locationSelect.options).filter(opt => opt.value !== "");
    const currentLocation = "<?php echo (int)($employee['location_id'] ?? 0); ?>";

    function filterLocations() {
        const selectedBranch = branchSelect.value;

        locationSelect.innerHTML = "";

        const defaultOption = document.createElement("option");
        defaultOption.value = "";
        defaultOption.textContent = "Select Sub-Location";
        locationSelect.appendChild(defaultOption);

        originalOptions.forEach(function (opt) {
            const branchId = opt.getAttribute("data-branch");

            if (selectedBranch !== "" && branchId === selectedBranch) {
                const clone = opt.cloneNode(true);
                if (clone.value === currentLocation) {
                    clone.selected = true;
                }
                locationSelect.appendChild(clone);
            }
        });
    }

    branchSelect.addEventListener("change", function () {
        filterLocations();
        if (locationSelect.value === currentLocation) return;
        if (locationSelect.options.length > 0) {
            locationSelect.selectedIndex = 0;
        }
    });

    filterLocations();
});
</script>

<?php require_once "../includes/footer.php"; ?>
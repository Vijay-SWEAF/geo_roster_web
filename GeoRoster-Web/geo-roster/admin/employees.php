<?php
require_once "../includes/auth_check.php";
require_once "../config/database.php";

if ($_SESSION["role"] != "Admin" && $_SESSION["role"] != "HO User") {
    $_SESSION["flash_error"] = "Access denied.";
    header("Location: ../dashboard.php");
    exit;
}

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $location_id = !empty($_POST["location_id"]) ? (int)$_POST["location_id"] : "NULL";
    $employee_no = trim($_POST["employee_no"]);
    $employee_name = trim($_POST["employee_name"]);
    $branch_id = $_POST["branch_id"];
    $designation = trim($_POST["designation"]);
    $employee_category = $_POST["employee_category"];

    $sql = "INSERT INTO employees 
        (employee_no, employee_name, branch_id, location_id, designation, employee_category)
        VALUES 
        ('$employee_no', '$employee_name', '$branch_id', $location_id, '$designation', '$employee_category')";

    if ($conn->query($sql)) {
        $_SESSION["flash_message"] = "Employee added successfully.";
    } else {
        $_SESSION["flash_error"] = "Unable to add employee.";
    }

    header("Location: employees.php");
    exit;
}

$branches = $conn->query("SELECT * FROM branches ORDER BY branch_name");

$locations = $conn->query("
    SELECT location_id, branch_id, location_name
    FROM branch_locations
    WHERE is_active = 1
    ORDER BY location_name
");

$employees = $conn->query("
    SELECT e.*, b.branch_name, bl.location_name
    FROM employees e
    LEFT JOIN branches b ON e.branch_id = b.branch_id
    LEFT JOIN branch_locations bl ON e.location_id = bl.location_id
    ORDER BY e.employee_name
");

define('APP_INCLUDED', true);

$pageTitle = "Employee Master";
$pageSubtitle = "Create and maintain employee records, branch assignment, designation, and category.";
$basePath = "../";

require_once "../includes/header.php";
?>

<div class="module-two-col">

    <div class="panel-card">
        <div class="panel-title">Add New Employee</div>

        <form method="post" class="form-grid">

            <div class="top-filters-flex">
    <div class="filter-box">
        <label for="employee_no">Employee No</label>
        <input type="text" id="employee_no" name="employee_no" placeholder="e.g. SMS-00001" required>
    </div>

    <div class="filter-box">
        <label for="employee_name">Employee Name</label>
        <input type="text" id="employee_name" name="employee_name" placeholder="Employee name" required>
    </div>
</div>

<div class="top-filters-flex">
    <div class="filter-box">
        <label for="branch_id">Branch</label>
        <select id="branch_id" name="branch_id" required>
            <option value="">Select Branch</option>
            <?php while ($b = $branches->fetch_assoc()) { ?>
                <option value="<?php echo $b['branch_id']; ?>">
                    <?php echo htmlspecialchars($b['branch_name']); ?>
                </option>
            <?php } ?>
        </select>
    </div>

    <div class="filter-box">
        <label for="location_id">Sub-Location</label>
        <select id="location_id" name="location_id" required>
            <option value="">Select Sub-Location</option>
            <?php while ($loc = $locations->fetch_assoc()) { ?>
                <option value="<?php echo $loc['location_id']; ?>" data-branch="<?php echo $loc['branch_id']; ?>">
                    <?php echo htmlspecialchars($loc['location_name']); ?>
                </option>
            <?php } ?>
        </select>
    </div>
</div>

<div class="top-filters-flex">
    <div class="filter-box">
        <label for="designation">Designation</label>
        <input type="text" id="designation" name="designation" placeholder="e.g. Supervisor">
    </div>

    <div class="filter-box">
        <label for="employee_category">Category</label>
        <select id="employee_category" name="employee_category" required>
            <option value="Staff">Staff</option>
            <option value="Labour">Labour</option>
        </select>
    </div>
</div>

<div class="form-actions" style="display:flex; align-items:flex-end; gap:16px; flex-wrap:wrap;">

    <div style="display:flex; gap:12px;">
        <button type="submit">Add Employee</button>
        <a href="../dashboard.php" class="btn-secondary-link">Cancel</a>
    </div>

    <div class="filter-box" style="margin-left:auto; width:100%; max-width:760px;">
        <label>&nbsp;</label>
        <div class="search-row" style="margin-bottom:0; width:100%;">
            <input type="text" id="employeeSearch"
                   placeholder="Search by employee no, name or category..."
                   style="width:100%;">
        </div>
    </div>

</div>

        </form>
    </div>

    <div class="panel-card">
        <div class="panel-title">Employee Records</div>

        <div class="table-wrap">
            <table class="employee-master-table">
                <thead>
                    <tr>
                        <th style="width:150px;">Employee No</th>
                        <th style="width:260px;">Employee Name</th>
                        <th style="width:180px;">Branch</th>
                        <th style="width:180px;">Sub-Location</th>
                        <th style="width:180px;">Designation</th>
                        <th style="width:120px;">Category</th>
                        <th style="width:120px;">Status</th>
                        <th style="width:180px;">Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if ($employees && $employees->num_rows > 0) { ?>
                        <?php while ($e = $employees->fetch_assoc()) { ?>
                            <tr>
                                <td><?php echo htmlspecialchars($e['employee_no'] ?? ''); ?></td>
                                <td><?php echo htmlspecialchars($e['employee_name'] ?? ''); ?></td>
                                <td><?php echo htmlspecialchars($e['branch_name'] ?? ''); ?></td>
                                <td><?php echo htmlspecialchars($e['location_name'] ?? ''); ?></td>
                                <td><?php echo htmlspecialchars($e['designation'] ?? ''); ?></td>
                                <td><?php echo htmlspecialchars($e['employee_category'] ?? ''); ?></td>
                                <td>
    <?php if ($e['is_active'] == 1) { ?>
        <span style="color:green; font-weight:600;">Active</span>
    <?php } else { ?>
        <span style="color:red; font-weight:600;">Inactive</span>
    <?php } ?>
</td>

<td style="white-space:nowrap;">

    <a href="edit_employee.php?id=<?php echo (int)$e['employee_id']; ?>"
       class="action-icon primary"
       title="Edit Employee">
        ✏️
    </a>

    <?php if ((int)$e['is_active'] === 1) { ?>
        <a href="toggle_employee.php?id=<?php echo (int)$e['employee_id']; ?>&action=deactivate"
           class="action-icon danger employee-status-link"
           title="Deactivate Employee"
           data-message="Are you sure you want to deactivate this employee?">
            ⛔
        </a>
    <?php } else { ?>
        <a href="toggle_employee.php?id=<?php echo (int)$e['employee_id']; ?>&action=activate"
           class="action-icon success employee-status-link"
           title="Activate Employee"
           data-message="Are you sure you want to activate this employee?">
            ✅
        </a>
    <?php } ?>

</td>
                            </tr>
                        <?php } ?>
                    <?php } else { ?>
                        <tr>
                            <td colspan="8">No employee records found.</td>
                        </tr>
                    <?php } ?>
                </tbody>
            </table>
        </div>
    </div>

</div>

<script>
document.addEventListener("DOMContentLoaded", function () {
    const branchSelect = document.getElementById("branch_id");
    const locationSelect = document.getElementById("location_id");

    if (branchSelect && locationSelect) {
        const originalOptions = Array.from(locationSelect.options).filter(opt => opt.value !== "");

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
                    locationSelect.appendChild(opt.cloneNode(true));
                }
            });

            locationSelect.value = "";
        }

        branchSelect.addEventListener("change", filterLocations);
        filterLocations();
    }

    const modal = document.getElementById("employeeConfirmModal");
    const messageBox = document.getElementById("employeeConfirmMessage");
    const confirmBtn = document.getElementById("employeeConfirmOk");
    const cancelBtn = document.getElementById("employeeConfirmCancel");
    const statusLinks = document.querySelectorAll(".employee-status-link");

    statusLinks.forEach(function (link) {
        link.addEventListener("click", function (e) {
            e.preventDefault();

            const url = this.getAttribute("href");
            const message = this.getAttribute("data-message") || "Are you sure?";

            messageBox.textContent = message;
            confirmBtn.setAttribute("href", url);
            modal.style.display = "flex";
        });
    });

    if (cancelBtn) {
        cancelBtn.addEventListener("click", function () {
            modal.style.display = "none";
            confirmBtn.setAttribute("href", "#");
        });
    }

    if (modal) {
        modal.addEventListener("click", function (e) {
            if (e.target === modal) {
                modal.style.display = "none";
                confirmBtn.setAttribute("href", "#");
            }
        });
    }
    
    const searchInput = document.getElementById("employeeSearch");

if (searchInput) {
    searchInput.addEventListener("keyup", function () {
        const value = this.value.toLowerCase();
        const rows = document.querySelectorAll(".employee-master-table tbody tr");

        rows.forEach(function (row) {
            const text = row.innerText.toLowerCase();
            row.style.display = text.includes(value) ? "" : "none";
        });
    });
}

});
</script>

<style>
.custom-modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(15, 23, 42, 0.45);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 9999;
}

.custom-modal-box {
    width: 100%;
    max-width: 420px;
    background: #ffffff;
    border-radius: 18px;
    box-shadow: 0 20px 60px rgba(15, 23, 42, 0.20);
    padding: 24px;
    border: 1px solid #dbe4f0;
}

.custom-modal-title {
    font-size: 22px;
    font-weight: 700;
    color: #0f172a;
    margin-bottom: 12px;
}

.custom-modal-text {
    font-size: 16px;
    color: #475569;
    line-height: 1.5;
    margin-bottom: 20px;
}

.custom-modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 12px;
}

.custom-modal-actions .btn-secondary-link,
.custom-modal-actions .btn-generate {
    text-decoration: none;
    min-width: 110px;
    text-align: center;
}
</style>

<div id="employeeConfirmModal" class="custom-modal-overlay" style="display:none;">
    <div class="custom-modal-box">
        <div class="custom-modal-title">Confirm Action</div>
        <div class="custom-modal-text" id="employeeConfirmMessage">
            Are you sure?
        </div>

        <div class="custom-modal-actions">
            <button type="button" class="btn-secondary-link" id="employeeConfirmCancel">Cancel</button>
            <a href="#" class="btn-generate" id="employeeConfirmOk">Confirm</a>
        </div>
    </div>
</div>

<?php require_once "../includes/footer.php"; ?>
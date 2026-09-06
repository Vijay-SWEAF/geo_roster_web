<?php
require_once "../includes/auth_check.php";
require_once "../config/database.php";
require_once "../includes/security.php";

if ($_SESSION["role"] != "Admin") {
    $_SESSION["flash_error"] = "Access denied.";
    header("Location: ../dashboard.php");
    exit;
}

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    requireCsrf();
    $code = trim($_POST["branch_code"]);
    $name = trim($_POST["branch_name"]);
    $city = trim($_POST["location_city"]);

    $stmt = $conn->prepare("INSERT INTO branches (branch_code, branch_name, location_city) VALUES (?, ?, ?)");
    $stmt->bind_param("sss", $code, $name, $city);
    try {
        if ($stmt->execute()) {
            $_SESSION["flash_message"] = "Branch added successfully.";
            auditEvent($conn, "branch_created", "branch", $stmt->insert_id);
        } else {
            $_SESSION["flash_error"] = "Unable to add branch.";
        }
    } catch (mysqli_sql_exception $e) {
        if ($e->getCode() == 1062) {
            $_SESSION["flash_error"] = "Branch code already exists.";
        } else {
            $_SESSION["flash_error"] = "Unable to add branch.";
        }
    }

    header("Location: branches.php");
    exit;
}

$branches = $conn->query("SELECT * FROM branches ORDER BY branch_name");

define('APP_INCLUDED', true);

$pageTitle = "Branch Master";
$pageSubtitle = "Create and maintain branch locations used across attendance and reporting.";
$basePath = "../";

require_once "../includes/header.php";
?>

<div class="module-two-col">

    <div class="panel-card">
        <div class="panel-title">Add New Branch</div>

        <form method="post" class="form-grid">
            <?php echo csrfField(); ?>

            <div>
                <label for="branch_code">Branch Code</label>
                <input type="text" id="branch_code" name="branch_code" placeholder="e.g. NS-BD-003" required>
            </div>

            <div>
                <label for="branch_name">Branch Name</label>
                <input type="text" id="branch_name" name="branch_name" placeholder="e.g. Crystal Depot" required>
            </div>

            <div>
                <label for="location_city">City / Location</label>
                <input type="text" id="location_city" name="location_city" placeholder="e.g. Nhava Sheva, MH" required>
            </div>

            <div class="form-actions">
                <button type="submit">Add Branch</button>
                <a href="../dashboard.php" class="btn-secondary-link">Cancel</a>
            </div>

        </form>
    </div>

    <div class="panel-card">
        <div class="panel-title">Branch Records</div>

        <div class="table-wrap">
            <table>
                <thead>
                    <tr>
                        <th style="width:160px;">Code</th>
                        <th style="width:220px;">Name</th>
                        <th style="width:240px;">City</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if ($branches && $branches->num_rows > 0) { ?>
                        <?php while($b = $branches->fetch_assoc()) { ?>
                            <tr>
                                <td><?php echo htmlspecialchars($b["branch_code"]); ?></td>
                                <td><?php echo htmlspecialchars($b["branch_name"]); ?></td>
                                <td><?php echo htmlspecialchars($b["location_city"]); ?></td>
                            </tr>
                        <?php } ?>
                    <?php } else { ?>
                        <tr>
                            <td colspan="3">No branch records found.</td>
                        </tr>
                    <?php } ?>
                </tbody>
            </table>
        </div>
    </div>

</div>

<?php require_once "../includes/footer.php"; ?>
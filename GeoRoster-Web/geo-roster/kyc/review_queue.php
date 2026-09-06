<?php

require_once "../includes/auth_check.php";
require_once "../config/database.php";
require_once "../includes/security.php";
require_once "../includes/functions.php";
require_once "../includes/kyc_service.php";

startSecureSession();
applySecurityHeaders();

$sessionUserId = (int)($_SESSION['user_id'] ?? 0);
if ($sessionUserId <= 0) {
    header("Location: ../auth/login.php");
    exit;
}

$liveUser = getAuthoritativeUser($conn, $sessionUserId);
if (!$liveUser || (int)$liveUser['is_active'] !== 1) {
    $_SESSION = [];
    session_destroy();
    header("Location: ../auth/login.php");
    exit;
}

$userRole = $liveUser['role_name'];
$userBranchId = isset($liveUser['branch_id']) ? (int)$liveUser['branch_id'] : 0;

if (!in_array($userRole, ['Admin', 'HO User'], true)) {
    $_SESSION['flash_error'] = "Access denied. Review queue is restricted to Admin and HO Users.";
    header("Location: ../dashboard.php");
    exit;
}

$filterBranchId = validPositiveInt($_GET['branch_id'] ?? null) ?: "";
$filterType = trim($_GET['workflow_type'] ?? "ALL");
$filterStatus = trim($_GET['status'] ?? "ALL");
$searchTerm = trim($_GET['search'] ?? "");

$queueItems = getKycReviewQueue($conn, $userRole, $userBranchId);

// Apply in-memory filtering for search & types
$filteredItems = array_filter($queueItems, function($item) use ($filterBranchId, $filterType, $filterStatus, $searchTerm) {
    if ($filterBranchId !== "" && (int)$item['branch_id'] !== (int)$filterBranchId) {
        return false;
    }
    if ($filterType !== "ALL" && $item['workflow_type'] !== $filterType) {
        return false;
    }
    if ($filterStatus !== "ALL" && $item['status'] !== $filterStatus) {
        return false;
    }
    if ($searchTerm !== "") {
        $term = mb_strtolower($searchTerm);
        $empNo = mb_strtolower($item['employee_no']);
        $empName = mb_strtolower($item['employee_name']);
        if (strpos($empNo, $term) === false && strpos($empName, $term) === false) {
            return false;
        }
    }
    return true;
});

$branches = $conn->query("SELECT branch_id, branch_name FROM branches ORDER BY branch_name");

$pageTitle = "KYC Operational Review Queue";
$pageSubtitle = "Review and process submitted KYC profiles and amendment requests.";
$basePath = "../";

define('APP_INCLUDED', true);
require_once "../includes/header.php";

function statusBadgeClass($status) {
    switch ($status) {
        case 'VERIFIED':
        case 'APPROVED': return 'badge-ho';
        case 'SUBMITTED':
        case 'UNDER_REVIEW': return 'badge-branch';
        case 'REJECTED': return 'badge-admin';
        case 'DRAFT':
        case 'REQUESTED': return 'badge-ho';
        default: return '';
    }
}
?>

<div class="panel-card" style="margin-bottom:18px;">
    <div class="panel-title">Filter Review Queue</div>

    <form method="get" action="review_queue.php">
        <div class="top-filters-flex">

            <div class="filter-box">
                <label for="branch_id">Branch</label>
                <select id="branch_id" name="branch_id">
                    <option value="">All Branches</option>
                    <?php while ($b = $branches->fetch_assoc()) { ?>
                        <option value="<?php echo $b['branch_id']; ?>" <?php if ((string)$filterBranchId === (string)$b['branch_id']) echo 'selected'; ?>>
                            <?php echo htmlspecialchars($b['branch_name']); ?>
                        </option>
                    <?php } ?>
                </select>
            </div>

            <div class="filter-box">
                <label for="workflow_type">Workflow Type</label>
                <select id="workflow_type" name="workflow_type">
                    <option value="ALL" <?php if ($filterType === 'ALL') echo 'selected'; ?>>All Workflows</option>
                    <option value="INITIAL" <?php if ($filterType === 'INITIAL') echo 'selected'; ?>>Initial KYC</option>
                    <option value="AMENDMENT" <?php if ($filterType === 'AMENDMENT') echo 'selected'; ?>>Amendment</option>
                </select>
            </div>

            <div class="filter-box">
                <label for="status">Status</label>
                <select id="status" name="status">
                    <option value="ALL" <?php if ($filterStatus === 'ALL') echo 'selected'; ?>>All Pending Statuses</option>
                    <option value="SUBMITTED" <?php if ($filterStatus === 'SUBMITTED') echo 'selected'; ?>>Submitted Only</option>
                    <option value="UNDER_REVIEW" <?php if ($filterStatus === 'UNDER_REVIEW') echo 'selected'; ?>>Under Review Only</option>
                    <option value="REJECTED" <?php if ($filterStatus === 'REJECTED') echo 'selected'; ?>>Rejected Only</option>
                    <option value="REQUESTED" <?php if ($filterStatus === 'REQUESTED') echo 'selected'; ?>>Amendment Requested</option>
                    <option value="DRAFT" <?php if ($filterStatus === 'DRAFT') echo 'selected'; ?>>Amendment Draft</option>
                </select>
            </div>

            <div class="filter-box">
                <label for="search">Search Employee</label>
                <input type="text" id="search" name="search" placeholder="Emp No or Name" value="<?php echo htmlspecialchars($searchTerm); ?>">
            </div>

            <div class="button-box">
                <label>&nbsp;</label>
                <div class="action-buttons">
                    <button type="submit" class="btn-generate">Apply Filters</button>
                    <a href="review_queue.php" class="btn-secondary-link">Reset</a>
                </div>
            </div>

        </div>
    </form>
</div>

<div class="panel-card">
    <div class="panel-title">
        Pending Operational Items (<?php echo count($filteredItems); ?>)
    </div>

    <div class="table-wrap">
        <table>
            <thead>
                <tr>
                    <th style="width:130px;">Workflow</th>
                    <th style="width:140px;">Employee No</th>
                    <th style="width:200px;">Employee Name</th>
                    <th style="width:160px;">Branch</th>
                    <th style="width:110px;">Category</th>
                    <th style="width:140px;">Status</th>
                    <th style="width:150px;">Submitted / Requested</th>
                    <th style="width:150px;">Last Updated</th>
                    <th style="width:130px;">Action</th>
                </tr>
            </thead>
            <tbody>
                <?php if (!empty($filteredItems)) { ?>
                    <?php foreach ($filteredItems as $item) { ?>
                        <tr>
                            <td>
                                <?php if ($item['workflow_type'] === 'AMENDMENT') { ?>
                                    <span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-size:11px; font-weight:700;">AMENDMENT</span>
                                <?php } else { ?>
                                    <span style="background:#e0f2fe; color:#0369a1; padding:2px 6px; border-radius:4px; font-size:11px; font-weight:700;">INITIAL KYC</span>
                                <?php } ?>
                            </td>
                            <td><strong><?php echo htmlspecialchars($item['employee_no']); ?></strong></td>
                            <td><?php echo htmlspecialchars($item['employee_name']); ?></td>
                            <td><?php echo htmlspecialchars($item['branch_name']); ?></td>
                            <td><?php echo htmlspecialchars($item['employee_category']); ?></td>
                            <td>
                                <span class="role-badge <?php echo statusBadgeClass($item['status']); ?>">
                                    <?php echo htmlspecialchars(str_replace('_', ' ', $item['status'])); ?>
                                </span>
                            </td>
                            <td style="font-size:12px; color:#64748b;"><?php echo htmlspecialchars($item['submitted_at'] ?? 'N/A'); ?></td>
                            <td style="font-size:12px; color:#64748b;"><?php echo htmlspecialchars($item['updated_at']); ?></td>
                            <td>
                                <a href="employee_kyc.php?employee_id=<?php echo (int)$item['employee_id']; ?>"
                                   class="action-icon primary" style="font-size:13px; font-weight:600; text-decoration:none;"
                                   title="Review Item">
                                    Review
                                </a>
                            </td>
                        </tr>
                    <?php } ?>
                <?php } else { ?>
                    <tr>
                        <td colspan="9" style="text-align:center; color:#64748b; padding:20px;">
                            No pending KYC review items matching current filters.
                        </td>
                    </tr>
                <?php } ?>
            </tbody>
        </table>
    </div>
</div>

<?php require_once "../includes/footer.php"; ?>

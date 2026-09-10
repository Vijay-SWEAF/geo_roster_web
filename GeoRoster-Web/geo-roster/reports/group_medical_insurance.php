<?php

require_once '../includes/auth_check.php';
require_once '../config/database.php';
require_once '../includes/security.php';
require_once '../includes/functions.php';
require_once '../includes/employee_benefit_service.php';

$user = getAuthoritativeUser($conn, (int)($_SESSION['user_id'] ?? 0));
if (!canManageEmployeeBenefits($conn, $user)) {
    http_response_code(403);
    exit('Employee benefit information is restricted.');
}

$filters = [
    'branch_id' => $_GET['branch_id'] ?? '',
    'coverage' => $_GET['coverage'] ?? 'ALL',
    'active' => $_GET['active'] ?? 'ACTIVE'
];
$report = getGroupMedicalCoverageReport($conn, $filters);
$branches = $user['role_name'] === 'Admin' ? getBenefitReportBranches($conn) : [];
$pageTitle = 'Group Medical Insurance Coverage';
$pageSubtitle = 'Enrollment status only.';
$basePath = '../';
require_once '../includes/header.php';
?>
<div class="kyc-page">

    <!-- Breadcrumb Navigation -->
    <div class="kyc-breadcrumb" style="margin-bottom:16px;">
        <a href="../dashboard.php">Dashboard</a>
        <span class="kyc-breadcrumb-separator">›</span>
        <span>Reports</span>
        <span class="kyc-breadcrumb-separator">›</span>
        <strong>Group Medical Insurance</strong>
    </div>

    <!-- Page Header -->
    <div class="kyc-header" style="margin-bottom:16px;">
        <div class="kyc-header-title">Group Medical Insurance Coverage</div>
        <p style="color:#64748b; margin:8px 0 0 0; font-size:13px;">Enrollment status and coverage tracking across all employees.</p>
    </div>

    <!-- Navigation Bar -->
    <div style="background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:16px; margin-bottom:16px; display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px;">
        <a href="../dashboard.php" class="btn-secondary-link">← Back to Dashboard</a>
    </div>

    <!-- Summary Stat Cards -->
    <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(200px, 1fr)); gap:12px; margin-bottom:20px;">
        <div class="kyc-stat-card">
            <div class="kyc-stat-label">Total Employees</div>
            <div class="kyc-stat-value"><?php echo (int)$report['counts']['total']; ?></div>
        </div>
        <div class="kyc-stat-card">
            <div class="kyc-stat-label">Covered</div>
            <div class="kyc-stat-value" style="color:#0f766e;"><?php echo (int)$report['counts']['covered']; ?></div>
        </div>
        <div class="kyc-stat-card">
            <div class="kyc-stat-label">Not Covered</div>
            <div class="kyc-stat-value" style="color:#b91c1c;"><?php echo (int)$report['counts']['not_covered']; ?></div>
        </div>
        <div class="kyc-stat-card">
            <div class="kyc-stat-label">Not Set</div>
            <div class="kyc-stat-value" style="color:#78716c;"><?php echo (int)$report['counts']['not_set']; ?></div>
        </div>
    </div>

    <!-- Filters -->
    <div class="panel-card" style="margin-bottom:18px;">
        <div class="panel-title">Filter Report</div>
        <form method="get" action="group_medical_insurance.php" class="form-grid" style="margin-top:12px;">
            <?php if ($user['role_name'] === 'Admin') { ?>
                <div class="kyc-form-group">
                    <label for="branch_id">Branch</label>
                    <select id="branch_id" name="branch_id" style="padding:10px 12px; border:1px solid #cbd5e1; border-radius:6px;">
                        <option value="">All Branches</option>
                        <?php foreach ($branches as $branch) { ?>
                            <option value="<?php echo (int)$branch['branch_id']; ?>" <?php echo ((string)$filters['branch_id'] === (string)$branch['branch_id']) ? 'selected' : ''; ?>>
                                <?php echo htmlspecialchars($branch['branch_name']); ?>
                            </option>
                        <?php } ?>
                    </select>
                </div>
            <?php } ?>
            <div class="kyc-form-group">
                <label for="coverage">Coverage Status</label>
                <select id="coverage" name="coverage" style="padding:10px 12px; border:1px solid #cbd5e1; border-radius:6px;">
                    <option value="ALL">All</option>
                    <option value="COVERED" <?php echo $filters['coverage'] === 'COVERED' ? 'selected' : ''; ?>>Covered</option>
                    <option value="NOT_COVERED" <?php echo $filters['coverage'] === 'NOT_COVERED' ? 'selected' : ''; ?>>Not Covered</option>
                    <option value="NOT_SET" <?php echo $filters['coverage'] === 'NOT_SET' ? 'selected' : ''; ?>>Not Set</option>
                </select>
            </div>
            <div class="kyc-form-group">
                <label for="active">Employee Status</label>
                <select id="active" name="active" style="padding:10px 12px; border:1px solid #cbd5e1; border-radius:6px;">
                    <option value="ACTIVE" <?php echo $filters['active'] === 'ACTIVE' ? 'selected' : ''; ?>>Active</option>
                    <option value="INACTIVE" <?php echo $filters['active'] === 'INACTIVE' ? 'selected' : ''; ?>>Inactive</option>
                    <option value="ALL" <?php echo $filters['active'] === 'ALL' ? 'selected' : ''; ?>>All</option>
                </select>
            </div>
            <div class="kyc-form-group" style="align-self:flex-end;">
                <div style="display:flex; gap:10px; flex-wrap:wrap;">
                    <button type="submit" class="btn-generate">Apply Filters</button>
                    <a href="group_medical_insurance.php" class="btn-secondary-link">Reset</a>
                </div>
            </div>
        </form>
    </div>

    <!-- Export Button -->
    <form method="post" action="../export_group_medical_insurance.php" style="margin-bottom:16px;">
        <?php echo csrfField(); ?>
        <input type="hidden" name="branch_id" value="<?php echo htmlspecialchars((string)$filters['branch_id']); ?>">
        <input type="hidden" name="coverage" value="<?php echo htmlspecialchars((string)$filters['coverage']); ?>">
        <input type="hidden" name="active" value="<?php echo htmlspecialchars((string)$filters['active']); ?>">
        <button type="submit" class="btn-secondary-link">📥 Export to CSV</button>
    </form>

    <!-- Results Table -->
    <div class="panel-card">
        <div class="panel-title">Coverage Results (<?php echo count($report['rows']); ?> employees)</div>
        <div style="overflow-x:auto; margin-top:12px;">
            <table class="kyc-responsive-table" style="width:100%; font-size:13px;">
                <thead>
                    <tr>
                        <th>Employee No</th>
                        <th>Employee Name</th>
                        <th>Branch</th>
                        <th>Sub-Location</th>
                        <th>Designation</th>
                        <th>Category</th>
                        <th>Active</th>
                        <th>Coverage</th>
                        <th>Last Updated</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (!empty($report['rows'])) { ?>
                        <?php foreach ($report['rows'] as $row) { ?>
                            <tr>
                                <td><strong><?php echo htmlspecialchars($row['employee_no']); ?></strong></td>
                                <td><?php echo htmlspecialchars($row['employee_name']); ?></td>
                                <td><?php echo htmlspecialchars($row['branch_name'] ?? ''); ?></td>
                                <td><?php echo htmlspecialchars($row['sub_location'] ?? ''); ?></td>
                                <td><?php echo htmlspecialchars($row['designation'] ?? ''); ?></td>
                                <td><?php echo htmlspecialchars($row['employee_category'] ?? ''); ?></td>
                                <td><?php echo (int)$row['is_active'] === 1 ? '✓ Active' : 'Inactive'; ?></td>
                                <td>
                                    <?php
                                    if ($row['coverage_label'] === 'Covered') {
                                        echo '<span style="background:#dcfce7; color:#166534; padding:2px 6px; border-radius:4px; font-weight:600; font-size:12px;">Covered</span>';
                                    } elseif ($row['coverage_label'] === 'Not Covered') {
                                        echo '<span style="background:#fee2e2; color:#dc2626; padding:2px 6px; border-radius:4px; font-weight:600; font-size:12px;">Not Covered</span>';
                                    } else {
                                        echo '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px; font-weight:600; font-size:12px;">Not Set</span>';
                                    }
                                    ?>
                                </td>
                                <td style="font-size:12px; color:#64748b;"><?php echo htmlspecialchars($row['updated_at'] ?? 'Not Updated'); ?></td>
                            </tr>
                        <?php } ?>
                    <?php } else { ?>
                        <tr>
                            <td colspan="9" style="text-align:center; padding:20px; color:#64748b; font-size:13px;">No employees match the selected filters.</td>
                        </tr>
                    <?php } ?>
                </tbody>
            </table>
        </div>
    </div>

</div>

<?php require_once '../includes/footer.php'; ?>

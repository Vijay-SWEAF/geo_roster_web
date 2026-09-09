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
<div class="panel-card">
    <div class="panel-title">Group Medical Insurance Coverage</div>
    <form method="get" action="group_medical_insurance.php" class="form-grid" style="margin-bottom:16px;">
        <?php if ($user['role_name'] === 'Admin') { ?><div><label for="branch_id">Branch</label><select id="branch_id" name="branch_id"><option value="">All Branches</option><?php foreach ($branches as $branch) { ?><option value="<?php echo (int)$branch['branch_id']; ?>" <?php echo ((string)$filters['branch_id'] === (string)$branch['branch_id']) ? 'selected' : ''; ?>><?php echo htmlspecialchars($branch['branch_name']); ?></option><?php } ?></select></div><?php } ?>
        <div><label for="coverage">Coverage Status</label><select id="coverage" name="coverage"><option value="ALL">All</option><option value="COVERED" <?php echo $filters['coverage'] === 'COVERED' ? 'selected' : ''; ?>>Covered</option><option value="NOT_COVERED" <?php echo $filters['coverage'] === 'NOT_COVERED' ? 'selected' : ''; ?>>Not Covered</option><option value="NOT_SET" <?php echo $filters['coverage'] === 'NOT_SET' ? 'selected' : ''; ?>>Not Set</option></select></div>
        <div><label for="active">Employee Status</label><select id="active" name="active"><option value="ACTIVE" <?php echo $filters['active'] === 'ACTIVE' ? 'selected' : ''; ?>>Active</option><option value="INACTIVE" <?php echo $filters['active'] === 'INACTIVE' ? 'selected' : ''; ?>>Inactive</option><option value="ALL" <?php echo $filters['active'] === 'ALL' ? 'selected' : ''; ?>>All</option></select></div>
        <div style="align-self:end;"><button type="submit" class="btn-generate">Apply Filters</button></div>
    </form>
    <div class="form-grid" style="margin-bottom:16px;"><div><strong>Total Employees</strong><br><?php echo (int)$report['counts']['total']; ?></div><div><strong>Covered</strong><br><?php echo (int)$report['counts']['covered']; ?></div><div><strong>Not Covered</strong><br><?php echo (int)$report['counts']['not_covered']; ?></div><div><strong>Not Set</strong><br><?php echo (int)$report['counts']['not_set']; ?></div></div>
    <form method="post" action="../export_group_medical_insurance.php" style="margin-bottom:16px;"><?php echo csrfField(); ?><input type="hidden" name="branch_id" value="<?php echo htmlspecialchars((string)$filters['branch_id']); ?>"><input type="hidden" name="coverage" value="<?php echo htmlspecialchars((string)$filters['coverage']); ?>"><input type="hidden" name="active" value="<?php echo htmlspecialchars((string)$filters['active']); ?>"><button type="submit" class="btn-secondary-link">Export Coverage CSV</button></form>
    <div class="table-wrap"><table><thead><tr><th>Employee No</th><th>Employee Name</th><th>Branch</th><th>Sub-Location</th><th>Designation</th><th>Category</th><th>Active Status</th><th>Medical Insurance Coverage</th><th>Last Updated</th></tr></thead><tbody><?php foreach ($report['rows'] as $row) { ?><tr><td><?php echo htmlspecialchars($row['employee_no']); ?></td><td><?php echo htmlspecialchars($row['employee_name']); ?></td><td><?php echo htmlspecialchars($row['branch_name'] ?? ''); ?></td><td><?php echo htmlspecialchars($row['sub_location'] ?? ''); ?></td><td><?php echo htmlspecialchars($row['designation'] ?? ''); ?></td><td><?php echo htmlspecialchars($row['employee_category'] ?? ''); ?></td><td><?php echo (int)$row['is_active'] === 1 ? 'Active' : 'Inactive'; ?></td><td><?php echo htmlspecialchars($row['coverage_label']); ?></td><td><?php echo htmlspecialchars($row['updated_at'] ?? 'Not Updated'); ?></td></tr><?php } if (!$report['rows']) { ?><tr><td colspan="9">No employees match the selected filters.</td></tr><?php } ?></tbody></table></div>
</div>
<?php require_once '../includes/footer.php'; ?>

<?php

require_once 'includes/auth_check.php';
require_once 'config/database.php';
require_once 'includes/security.php';
require_once 'includes/functions.php';
require_once 'includes/employee_benefit_service.php';

requirePostWithCsrf();
$user = getAuthoritativeUser($conn, (int)($_SESSION['user_id'] ?? 0));
if (!canManageEmployeeBenefits($conn, $user)) {
    http_response_code(403);
    exit('Employee benefit information is restricted.');
}

$report = getGroupMedicalCoverageReport($conn, [
    'branch_id' => $_POST['branch_id'] ?? '',
    'coverage' => $_POST['coverage'] ?? 'ALL',
    'active' => $_POST['active'] ?? 'ACTIVE'
]);
header('Content-Type: text/csv; charset=utf-8');
header('Content-Disposition: attachment; filename="group_medical_insurance_coverage_' . date('Ymd') . '.csv"');
$output = fopen('php://output', 'w');
fputcsv($output, ['Employee No', 'Employee Name', 'Branch', 'Sub-Location', 'Designation', 'Employee Category', 'Employee Active Status', 'Medical Insurance Coverage', 'Last Updated']);
foreach ($report['rows'] as $row) {
    fputcsv($output, [
        exportSafeText($row['employee_no'] ?? ''),
        exportSafeText($row['employee_name'] ?? ''),
        exportSafeText($row['branch_name'] ?? ''),
        exportSafeText($row['sub_location'] ?? ''),
        exportSafeText($row['designation'] ?? ''),
        exportSafeText($row['employee_category'] ?? ''),
        exportSafeText((int)$row['is_active'] === 1 ? 'Active' : 'Inactive'),
        exportSafeText($row['coverage_label'] ?? 'Not Set'),
        exportSafeText($row['updated_at'] ?? 'Not Updated')
    ]);
}
fclose($output);
exit;

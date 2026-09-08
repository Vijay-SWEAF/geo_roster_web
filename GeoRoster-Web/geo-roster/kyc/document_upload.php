<?php

require_once '../includes/auth_check.php';
require_once '../config/database.php';
require_once '../includes/security.php';
require_once '../includes/kyc_document_service.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') { http_response_code(405); exit('Method not allowed.'); }
requireCsrf();
$employeeId = validPositiveInt($_POST['employee_id'] ?? null);
if (!$employeeId) { $_SESSION['flash_error'] = 'Invalid employee selected.'; header('Location: ../admin/employees.php'); exit; }
try {
    $actorId = (int)($_SESSION['user_id'] ?? 0);
    uploadKycDocument($conn, $employeeId, trim($_POST['document_type'] ?? ''), trim($_POST['document_label'] ?? ''), $_FILES['document'] ?? [], $actorId);
    $_SESSION['flash_message'] = 'KYC document uploaded securely.';
} catch (Throwable $exception) {
    error_log('KYC document upload failed: ' . $exception->getMessage());
    $_SESSION['flash_error'] = 'Unable to upload the KYC document.';
}
header('Location: documents.php?employee_id=' . $employeeId);
exit;

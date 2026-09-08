<?php

require_once "../includes/auth_check.php";
require_once "../config/database.php";
require_once "../includes/security.php";
require_once "../includes/kyc_service.php";

requirePostWithCsrf();

$actorId = (int)($_SESSION['user_id'] ?? 0);
$actor = getAuthoritativeUser($conn, $actorId);
if (!$actor || (int)$actor['is_active'] !== 1 || $actor['role_name'] !== 'Admin') {
    http_response_code(403);
    exit('Admin permission required.');
}

$targetId = validPositiveInt($_POST['user_id'] ?? null);
$enabled = filter_var($_POST['enabled'] ?? null, FILTER_VALIDATE_INT);
if (!$targetId || !in_array($enabled, [0, 1], true)) {
    $_SESSION['flash_error'] = 'Invalid KYC Officer permission request.';
    header('Location: user_management.php');
    exit;
}

$targetStmt = $conn->prepare('SELECT user_id, role_name, is_active FROM users WHERE user_id = ? LIMIT 1');
$targetStmt->bind_param('i', $targetId);
$targetStmt->execute();
$target = $targetStmt->get_result()->fetch_assoc();
if (!$target) {
    $_SESSION['flash_error'] = 'User not found.';
    header('Location: user_management.php');
    exit;
}

if ($enabled === 1 && ((int)$target['is_active'] !== 1 || !in_array($target['role_name'], ['HO User', 'Branch User'], true))) {
    $_SESSION['flash_error'] = 'Only active HO User or Branch User accounts may receive KYC Officer permission.';
    header('Location: user_management.php');
    exit;
}

$permission = KYC_PERMISSION_OFFICER;
$conn->begin_transaction();
try {
    $stmt = $conn->prepare(
        'INSERT INTO user_kyc_permissions (user_id, permission_code, is_active, granted_by, granted_at, updated_by, updated_at) '
        . 'VALUES (?, ?, ?, ?, NOW(), ?, NOW()) '
        . 'ON DUPLICATE KEY UPDATE is_active = VALUES(is_active), updated_by = VALUES(updated_by), updated_at = NOW()'
    );
    $stmt->bind_param('isiii', $targetId, $permission, $enabled, $actorId, $actorId);
    $stmt->execute();
    $conn->commit();

    auditEvent($conn, $enabled === 1 ? 'kyc_officer_granted' : 'kyc_officer_revoked', 'user', $targetId, [
        'permission' => KYC_PERMISSION_OFFICER,
        'active' => $enabled
    ]);
    $_SESSION['flash_message'] = $enabled === 1 ? 'KYC Officer permission granted.' : 'KYC Officer permission revoked.';
} catch (Throwable $exception) {
    $conn->rollback();
    error_log('KYC Officer permission update failed: ' . $exception->getMessage());
    $_SESSION['flash_error'] = 'Unable to update KYC Officer permission.';
}

header('Location: user_management.php');
exit;

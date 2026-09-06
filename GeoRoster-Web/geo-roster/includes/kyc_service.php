<?php

require_once __DIR__ . '/security.php';

define('KYC_STATUS_NOT_STARTED', 'NOT_STARTED');
define('KYC_STATUS_DRAFT', 'DRAFT');
define('KYC_STATUS_SUBMITTED', 'SUBMITTED');
define('KYC_STATUS_UNDER_REVIEW', 'UNDER_REVIEW');
define('KYC_STATUS_VERIFIED', 'VERIFIED');
define('KYC_STATUS_REJECTED', 'REJECTED');
define('KYC_PERMISSION_OFFICER', 'KYC_OFFICER');

/**
 * Re-queries the users table live to obtain current active status, role, and branch.
 * Prevents stale authorization from cached session snapshots.
 */
function getAuthoritativeUser($conn, $userId) {
    $userId = (int)$userId;
    if ($userId <= 0) {
        return null;
    }
    $stmt = $conn->prepare('SELECT user_id, full_name, username, role_name, branch_id, is_active FROM users WHERE user_id = ? LIMIT 1');
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $result = $stmt->get_result();
    return $result ? $result->fetch_assoc() : null;
}

function hasKycOfficerPermission($conn, $userId) {
    $userId = (int)$userId;
    if ($userId <= 0) {
        return false;
    }
    $stmt = $conn->prepare('SELECT 1 FROM user_kyc_permissions WHERE user_id = ? AND permission_code = ? AND is_active = 1 LIMIT 1');
    $permission = KYC_PERMISSION_OFFICER;
    $stmt->bind_param('is', $userId, $permission);
    $stmt->execute();
    return $stmt->get_result()->num_rows === 1;
}

function canAccessSensitiveKyc($conn, $liveUser) {
    return $liveUser['role_name'] === 'Admin' || hasKycOfficerPermission($conn, (int)$liveUser['user_id']);
}

/**
 * Enforces live database authorization for KYC access:
 * 1. Requires active session user_id.
 * 2. Fetches live user from DB and asserts is_active = 1.
 * 3. Fetches target employee from DB and asserts existence.
 * 4. Asserts live branch isolation if user role is 'Branch User'.
 */
function requireAuthoritativeKycAccess($conn, $employeeId) {
    startSecureSession();
    $sessionUserId = (int)($_SESSION['user_id'] ?? 0);
    if ($sessionUserId <= 0) {
        http_response_code(401);
        exit('Authentication required.');
    }

    $liveUser = getAuthoritativeUser($conn, $sessionUserId);
    if (!$liveUser || (int)$liveUser['is_active'] !== 1) {
        $_SESSION = [];
        session_destroy();
        http_response_code(403);
        exit('User account is inactive or invalid.');
    }

    $employeeId = validPositiveInt($employeeId);
    if (!$employeeId) {
        http_response_code(400);
        exit('Invalid employee ID.');
    }

    $employeeStmt = $conn->prepare('SELECT employee_id, employee_no, employee_name, branch_id, location_id, designation, employee_category, is_active FROM employees WHERE employee_id = ? LIMIT 1');
    $employeeStmt->bind_param('i', $employeeId);
    $employeeStmt->execute();
    $employee = $employeeStmt->get_result()->fetch_assoc();

    if (!$employee) {
        http_response_code(404);
        exit('Employee not found.');
    }

    $liveRole = $liveUser['role_name'];
    $liveBranchId = isset($liveUser['branch_id']) ? (int)$liveUser['branch_id'] : 0;
    $empBranchId = (int)$employee['branch_id'];

    if ($liveRole === 'Branch User') {
        if ($liveBranchId <= 0 || $liveBranchId !== $empBranchId) {
            auditEvent($conn, 'kyc_access_denied_branch_mismatch', 'employee', $employeeId);
            http_response_code(403);
            exit('Access denied to employee in another branch.');
        }
    }

    return [
        'user' => $liveUser,
        'employee' => $employee,
        'is_kyc_officer' => hasKycOfficerPermission($conn, (int)$liveUser['user_id']),
        'can_sensitive' => canAccessSensitiveKyc($conn, $liveUser)
    ];
}

/**
 * Fetches the current employee_kyc record for an employee.
 */
function getKycProfile($conn, $employeeId) {
    $employeeId = (int)$employeeId;
    $stmt = $conn->prepare('SELECT kyc_id, employee_id, kyc_status, submitted_at, submitted_by, verified_at, verified_by, rejected_at, rejected_by, rejection_reason, created_at, created_by, updated_at, updated_by FROM employee_kyc WHERE employee_id = ? LIMIT 1');
    $stmt->bind_param('i', $employeeId);
    $stmt->execute();
    $res = $stmt->get_result();
    return $res ? $res->fetch_assoc() : null;
}

/**
 * Fetches the private KYC structured data row for an employee.
 */
function getKycPrivateData($conn, $employeeId) {
    $employeeId = (int)$employeeId;
    $stmt = $conn->prepare('SELECT kyc_private_id, kyc_id, employee_id, date_of_birth, mobile_number, current_address, permanent_address, same_as_current, pan_applicable, aadhaar_applicable, uan_applicable, esic_applicable, pan_number_enc, pan_hmac, aadhaar_number_enc, aadhaar_hmac, uan_number_enc, uan_hmac, esic_number_enc, created_at, updated_at FROM employee_kyc_private WHERE employee_id = ? LIMIT 1');
    $stmt->bind_param('i', $employeeId);
    $stmt->execute();
    $res = $stmt->get_result();
    return $res ? $res->fetch_assoc() : null;
}

/**
 * Returns current string status of employee KYC ('NOT_STARTED' if no record exists).
 */
function getKycStatus($conn, $employeeId) {
    $profile = getKycProfile($conn, $employeeId);
    return $profile ? $profile['kyc_status'] : KYC_STATUS_NOT_STARTED;
}

/**
 * Returns allowed status transitions for a given current status.
 */
function getAllowedKycTransitions($currentStatus) {
    switch ($currentStatus) {
        case KYC_STATUS_NOT_STARTED:
            return [KYC_STATUS_DRAFT];
        case KYC_STATUS_DRAFT:
            return [KYC_STATUS_SUBMITTED];
        case KYC_STATUS_SUBMITTED:
            return [KYC_STATUS_UNDER_REVIEW];
        case KYC_STATUS_UNDER_REVIEW:
            return [KYC_STATUS_VERIFIED, KYC_STATUS_REJECTED];
        case KYC_STATUS_REJECTED:
            return [KYC_STATUS_DRAFT];
        case KYC_STATUS_VERIFIED:
        default:
            return []; // Immutable in Prompt 03A
    }
}

/**
 * Validates role-based permission for a specific state transition.
 */
function canUserTransitionKyc($userRole, $fromStatus, $toStatus) {
    $allowed = getAllowedKycTransitions($fromStatus);
    if (!in_array($toStatus, $allowed, true)) {
        return false;
    }

    if ($fromStatus === KYC_STATUS_NOT_STARTED && $toStatus === KYC_STATUS_DRAFT) {
        return in_array($userRole, ['Admin', 'HO User', 'Branch User'], true);
    }
    if ($fromStatus === KYC_STATUS_DRAFT && $toStatus === KYC_STATUS_SUBMITTED) {
        return in_array($userRole, ['Admin', 'HO User', 'Branch User'], true);
    }
    if ($fromStatus === KYC_STATUS_SUBMITTED && $toStatus === KYC_STATUS_UNDER_REVIEW) {
        return in_array($userRole, ['Admin', 'HO User'], true);
    }
    if ($fromStatus === KYC_STATUS_UNDER_REVIEW && ($toStatus === KYC_STATUS_VERIFIED || $toStatus === KYC_STATUS_REJECTED)) {
        // Admin-only final verification / rejection authority per KYC-DEC-009
        return $userRole === 'Admin';
    }
    if ($fromStatus === KYC_STATUS_REJECTED && $toStatus === KYC_STATUS_DRAFT) {
        return in_array($userRole, ['Admin', 'HO User', 'Branch User'], true);
    }

    return false;
}

/**
 * Starts a new KYC profile for an employee (NOT_STARTED -> DRAFT).
 * Transactional: creates profile and history entry atomically.
 */
function startKycProfile($conn, $employeeId, $actorUserId) {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $liveRole = $liveUser['role_name'];

    if (!canUserTransitionKyc($liveRole, KYC_STATUS_NOT_STARTED, KYC_STATUS_DRAFT)) {
        http_response_code(403);
        exit('Unauthorized to start KYC profile.');
    }

    $existing = getKycProfile($conn, $employeeId);
    if ($existing) {
        return $existing['kyc_id'];
    }

    $conn->begin_transaction();
    try {
        $stmt = $conn->prepare('INSERT INTO employee_kyc (employee_id, kyc_status, created_at, created_by, updated_at, updated_by) VALUES (?, ?, NOW(), ?, NOW(), ?)');
        $statusDraft = KYC_STATUS_DRAFT;
        $actorId = (int)$liveUser['user_id'];
        $stmt->bind_param('isii', $employeeId, $statusDraft, $actorId, $actorId);
        $stmt->execute();
        $kycId = $stmt->insert_id;

        $histStmt = $conn->prepare('INSERT INTO employee_kyc_history (kyc_id, employee_id, actor_user_id, action, previous_status, new_status, remarks, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())');
        $action = 'start_profile';
        $prev = KYC_STATUS_NOT_STARTED;
        $next = KYC_STATUS_DRAFT;
        $remarks = 'KYC profile initiated';
        $histStmt->bind_param('iiissss', $kycId, $employeeId, $actorId, $action, $prev, $next, $remarks);
        $histStmt->execute();

        $conn->commit();
        auditEvent($conn, 'kyc_profile_started', 'employee_kyc', $kycId);
        return $kycId;
    } catch (Throwable $e) {
        $conn->rollback();
        error_log('Failed to start KYC profile: ' . $e->getMessage());
        http_response_code(500);
        exit('Unable to start KYC profile.');
    }
}

/**
 * Transitions KYC status (e.g. DRAFT -> SUBMITTED, SUBMITTED -> UNDER_REVIEW, etc.).
 * Executes within a database transaction with rollback on failure.
 */
function transitionKycStatus($conn, $employeeId, $newStatus, $actorUserId, $remarks = '') {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $liveRole = $liveUser['role_name'];
    $actorId = (int)$liveUser['user_id'];

    $conn->begin_transaction();
    try {
        // Lock row for update
        $lockStmt = $conn->prepare('SELECT kyc_id, employee_id, kyc_status FROM employee_kyc WHERE employee_id = ? FOR UPDATE');
        $lockStmt->bind_param('i', $employeeId);
        $lockStmt->execute();
        $lockRes = $lockStmt->get_result();
        $profile = $lockRes ? $lockRes->fetch_assoc() : null;

        if (!$profile) {
            $conn->rollback();
            http_response_code(404);
            exit('KYC profile not found.');
        }

        $kycId = (int)$profile['kyc_id'];
        $currentStatus = $profile['kyc_status'];

        $canTransition = canUserTransitionKyc($liveRole, $currentStatus, $newStatus);
        if ($currentStatus === KYC_STATUS_SUBMITTED && $newStatus === KYC_STATUS_UNDER_REVIEW) {
            $canTransition = $canTransition || hasKycOfficerPermission($conn, $actorId);
        }
        if (!$canTransition) {
            $conn->rollback();
            auditEvent($conn, 'kyc_unauthorized_transition_attempt', 'employee_kyc', $kycId, ['from' => $currentStatus, 'to' => $newStatus]);
            http_response_code(403);
            exit('Unauthorized status transition.');
        }

        // Validate submission completeness
        if ($newStatus === KYC_STATUS_SUBMITTED) {
            $subErrors = validateKycForSubmission($conn, $employeeId);
            if (!empty($subErrors)) {
                $conn->rollback();
                $_SESSION['flash_error'] = 'Cannot submit KYC profile: ' . implode(' ', $subErrors);
                return false;
            }
        }

        $remarks = trim($remarks);
        if ($newStatus === KYC_STATUS_REJECTED && $remarks === '') {
            $conn->rollback();
            http_response_code(400);
            exit('Rejection reason is required.');
        }

        if (mb_strlen($remarks) > 500) {
            $remarks = mb_substr($remarks, 0, 500);
        }

        // Prepare status-specific column updates
        $sql = 'UPDATE employee_kyc SET kyc_status = ?, updated_at = NOW(), updated_by = ?';
        $params = [$newStatus, $actorId];
        $types = 'si';

        if ($newStatus === KYC_STATUS_SUBMITTED) {
            $sql .= ', submitted_at = NOW(), submitted_by = ?';
            $params[] = $actorId;
            $types .= 'i';
        } elseif ($newStatus === KYC_STATUS_VERIFIED) {
            $sql .= ', verified_at = NOW(), verified_by = ?';
            $params[] = $actorId;
            $types .= 'i';
        } elseif ($newStatus === KYC_STATUS_REJECTED) {
            $sql .= ', rejected_at = NOW(), rejected_by = ?, rejection_reason = ?';
            $params[] = $actorId;
            $params[] = $remarks;
            $types .= 'is';
        }

        $sql .= ' WHERE kyc_id = ?';
        $params[] = $kycId;
        $types .= 'i';

        $updStmt = $conn->prepare($sql);
        $references = [$types];
        foreach ($params as $k => $v) {
            $references[] = &$params[$k];
        }
        call_user_func_array([$updStmt, 'bind_param'], $references);
        $updStmt->execute();

        // Insert history record
        $actionName = strtolower($newStatus) . '_transition';
        $histStmt = $conn->prepare('INSERT INTO employee_kyc_history (kyc_id, employee_id, actor_user_id, action, previous_status, new_status, remarks, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())');
        $histStmt->bind_param('iiissss', $kycId, $employeeId, $actorId, $actionName, $currentStatus, $newStatus, $remarks);
        $histStmt->execute();

        $conn->commit();
        auditEvent($conn, 'kyc_status_transition', 'employee_kyc', $kycId, ['from' => $currentStatus, 'to' => $newStatus]);
        return true;

    } catch (Throwable $e) {
        $conn->rollback();
        error_log('Failed to transition KYC status: ' . $e->getMessage());
        http_response_code(500);
        exit('Unable to update KYC status.');
    }
}

/**
 * Fetches history trail for a given kyc_id.
 */
function getKycHistory($conn, $kycId) {
    $kycId = (int)$kycId;
    $stmt = $conn->prepare('SELECT h.history_id, h.kyc_id, h.employee_id, h.actor_user_id, u.full_name AS actor_name, h.action, h.previous_status, h.new_status, h.remarks, h.created_at FROM employee_kyc_history h LEFT JOIN users u ON h.actor_user_id = u.user_id WHERE h.kyc_id = ? ORDER BY h.history_id ASC');
    $stmt->bind_param('i', $kycId);
    $stmt->execute();
    $res = $stmt->get_result();
    $rows = [];
    if ($res) {
        while ($r = $res->fetch_assoc()) {
            $rows[] = $r;
        }
    }
    return $rows;
}

/**
 * Updates basic KYC data (DOB, Mobile, Current Address, Permanent Address).
 * Branch Users, HO Users, and Admin can update basic data for authorized branch employees.
 */
function updateKycBasicData($conn, $employeeId, $dob, $mobile, $currentAddr, $permAddr, $sameAsCurrent) {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $actorId = (int)$liveUser['user_id'];

    $profile = getKycProfile($conn, $employeeId);
    if (!$profile) {
        $kycId = startKycProfile($conn, $employeeId, $actorId);
        $profile = getKycProfile($conn, $employeeId);
    }

    if ($profile['kyc_status'] === KYC_STATUS_VERIFIED) {
        http_response_code(403);
        exit('Verified KYC profiles are locked against modification.');
    }

    $dob = validDateValue($dob);
    $mobile = trim((string)$mobile);
    if ($mobile !== '' && !preg_match('/^[6-9]\d{9}$/', $mobile)) {
        $_SESSION['flash_error'] = 'Invalid Indian 10-digit mobile number.';
        return false;
    }

    $currentAddr = trim((string)$currentAddr);
    $sameAsCurrent = $sameAsCurrent ? 1 : 0;
    if ($sameAsCurrent) {
        $permAddr = $currentAddr;
    } else {
        $permAddr = trim((string)$permAddr);
    }

    $kycId = (int)$profile['kyc_id'];
    $existingPrivate = getKycPrivateData($conn, $employeeId);

    if ($existingPrivate) {
        $stmt = $conn->prepare('UPDATE employee_kyc_private SET date_of_birth = ?, mobile_number = ?, current_address = ?, permanent_address = ?, same_as_current = ?, updated_at = NOW() WHERE employee_id = ?');
        $stmt->bind_param('ssssii', $dob, $mobile, $currentAddr, $permAddr, $sameAsCurrent, $employeeId);
        $stmt->execute();
    } else {
        $stmt = $conn->prepare('INSERT INTO employee_kyc_private (kyc_id, employee_id, date_of_birth, mobile_number, current_address, permanent_address, same_as_current, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())');
        $stmt->bind_param('iissssi', $kycId, $employeeId, $dob, $mobile, $currentAddr, $permAddr, $sameAsCurrent);
        $stmt->execute();
    }

    auditEvent($conn, 'kyc_basic_data_updated', 'employee_kyc', $kycId);
    return true;
}

/**
 * Updates statutory applicability flags and encrypted statutory fields.
 * Branch Users CANNOT edit applicability or statutory fields! Admin and HO Users only.
 */
function updateKycStatutoryData($conn, $employeeId, $panApp, $aadhaarApp, $uanApp, $esicApp, $panRaw, $aadhaarRaw, $uanRaw, $esicRaw) {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $liveRole = $liveUser['role_name'];
    $actorId = (int)$liveUser['user_id'];

    if (!canAccessSensitiveKyc($conn, $liveUser)) {
        http_response_code(403);
        exit('KYC sensitive permission required.');
    }

    $profile = getKycProfile($conn, $employeeId);
    if (!$profile) {
        $kycId = startKycProfile($conn, $employeeId, $actorId);
        $profile = getKycProfile($conn, $employeeId);
    }

    if ($profile['kyc_status'] === KYC_STATUS_VERIFIED) {
        http_response_code(403);
        exit('Verified KYC profiles are locked against modification.');
    }

    $panApp = $panApp ? 1 : 0;
    $aadhaarApp = $aadhaarApp ? 1 : 0;
    $uanApp = $uanApp ? 1 : 0;
    $esicApp = $esicApp ? 1 : 0;

    $existingPrivate = getKycPrivateData($conn, $employeeId);
    $kycId = (int)$profile['kyc_id'];

    // Process PAN
    $panRaw = strtoupper(trim((string)$panRaw));
    $panEnc = $existingPrivate['pan_number_enc'] ?? null;
    $panHmac = $existingPrivate['pan_hmac'] ?? null;
    if ($panRaw !== '') {
        if (!preg_match('/^[A-Z]{5}[0-9]{4}[A-Z]{1}$/', $panRaw)) {
            $_SESSION['flash_error'] = 'Invalid PAN Number format (Expected format: ABCDE1234F).';
            return false;
        }
        $panHmac = generateBlindIndex($panRaw);
        // Duplicate check
        $dupStmt = $conn->prepare('SELECT employee_id FROM employee_kyc_private WHERE pan_hmac = ? AND employee_id <> ? LIMIT 1');
        $dupStmt->bind_param('si', $panHmac, $employeeId);
        $dupStmt->execute();
        if ($dupStmt->get_result()->num_rows > 0) {
            $_SESSION['flash_error'] = 'PAN Number is already associated with another employee record.';
            auditEvent($conn, 'kyc_duplicate_pan_detected', 'employee_kyc', $kycId);
            return false;
        }
        $panEnc = encryptKycField($panRaw);
    }

    // Process Aadhaar
    $aadhaarRaw = preg_replace('/\D/', '', (string)$aadhaarRaw);
    $aadhaarEnc = $existingPrivate['aadhaar_number_enc'] ?? null;
    $aadhaarHmac = $existingPrivate['aadhaar_hmac'] ?? null;
    if ($aadhaarRaw !== '') {
        if (strlen($aadhaarRaw) !== 12 || !validateVerhoeff($aadhaarRaw)) {
            $_SESSION['flash_error'] = 'Invalid Aadhaar Number (Must be 12 digits matching Verhoeff checksum).';
            return false;
        }
        $aadhaarHmac = generateBlindIndex($aadhaarRaw);
        // Duplicate check
        $dupStmt = $conn->prepare('SELECT employee_id FROM employee_kyc_private WHERE aadhaar_hmac = ? AND employee_id <> ? LIMIT 1');
        $dupStmt->bind_param('si', $aadhaarHmac, $employeeId);
        $dupStmt->execute();
        if ($dupStmt->get_result()->num_rows > 0) {
            $_SESSION['flash_error'] = 'Aadhaar Number is already associated with another employee record.';
            auditEvent($conn, 'kyc_duplicate_aadhaar_detected', 'employee_kyc', $kycId);
            return false;
        }
        $aadhaarEnc = encryptKycField($aadhaarRaw);
    }

    // Process UAN
    $uanRaw = preg_replace('/\D/', '', (string)$uanRaw);
    $uanEnc = $existingPrivate['uan_number_enc'] ?? null;
    $uanHmac = $existingPrivate['uan_hmac'] ?? null;
    if ($uanRaw !== '') {
        if (strlen($uanRaw) !== 12) {
            $_SESSION['flash_error'] = 'Invalid UAN Number (Must be 12 digits).';
            return false;
        }
        $uanHmac = generateBlindIndex($uanRaw);
        $dupStmt = $conn->prepare('SELECT employee_id FROM employee_kyc_private WHERE uan_hmac = ? AND employee_id <> ? LIMIT 1');
        $dupStmt->bind_param('si', $uanHmac, $employeeId);
        $dupStmt->execute();
        if ($dupStmt->get_result()->num_rows > 0) {
            $_SESSION['flash_error'] = 'UAN Number is already associated with another employee record.';
            auditEvent($conn, 'kyc_duplicate_uan_detected', 'employee_kyc', $kycId);
            return false;
        }
        $uanEnc = encryptKycField($uanRaw);
    }

    // Process ESIC
    $esicRaw = preg_replace('/\D/', '', (string)$esicRaw);
    $esicEnc = $existingPrivate['esic_number_enc'] ?? null;
    if ($esicRaw !== '') {
        if (strlen($esicRaw) !== 17) {
            $_SESSION['flash_error'] = 'Invalid ESIC IP Number (Must be 17 digits).';
            return false;
        }
        $esicEnc = encryptKycField($esicRaw);
    }

    if ($existingPrivate) {
        $stmt = $conn->prepare('UPDATE employee_kyc_private SET pan_applicable = ?, aadhaar_applicable = ?, uan_applicable = ?, esic_applicable = ?, pan_number_enc = ?, pan_hmac = ?, aadhaar_number_enc = ?, aadhaar_hmac = ?, uan_number_enc = ?, uan_hmac = ?, esic_number_enc = ?, updated_at = NOW() WHERE employee_id = ?');
        $stmt->bind_param('iiiisssssssi', $panApp, $aadhaarApp, $uanApp, $esicApp, $panEnc, $panHmac, $aadhaarEnc, $aadhaarHmac, $uanEnc, $uanHmac, $esicEnc, $employeeId);
        $stmt->execute();
    } else {
        $stmt = $conn->prepare('INSERT INTO employee_kyc_private (kyc_id, employee_id, pan_applicable, aadhaar_applicable, uan_applicable, esic_applicable, pan_number_enc, pan_hmac, aadhaar_number_enc, aadhaar_hmac, uan_number_enc, uan_hmac, esic_number_enc, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())');
        $stmt->bind_param('iiiiiisssssss', $kycId, $employeeId, $panApp, $aadhaarApp, $uanApp, $esicApp, $panEnc, $panHmac, $aadhaarEnc, $aadhaarHmac, $uanEnc, $uanHmac, $esicEnc);
        $stmt->execute();
    }

    auditEvent($conn, 'kyc_statutory_data_updated', 'employee_kyc', $kycId);
    return true;
}

function validateKycForSubmission($conn, $employeeId) {
    $private = getKycPrivateData($conn, $employeeId);
    $errors = [];

    if (!$private) {
        return ['KYC data is required before submission.'];
    }
    if (!$private['date_of_birth'] || !validDateValue($private['date_of_birth'])) {
        $errors[] = 'Date of Birth is required for submission.';
    }
    if (!$private['mobile_number'] || !preg_match('/^[6-9]\d{9}$/', $private['mobile_number'])) {
        $errors[] = 'Valid 10-digit mobile number is required for submission.';
    }
    if (!$private['current_address'] || trim($private['current_address']) === '') {
        $errors[] = 'Complete Current Address is required for submission.';
    }
    if ((int)$private['same_as_current'] !== 1 && (!$private['permanent_address'] || trim($private['permanent_address']) === '')) {
        $errors[] = 'Complete Permanent Address is required for submission.';
    }
    if ((int)$private['pan_applicable'] === 1 && !$private['pan_number_enc']) {
        $errors[] = 'PAN Number is required when marked applicable.';
    }
    if ((int)$private['aadhaar_applicable'] === 1 && !$private['aadhaar_number_enc']) {
        $errors[] = 'Aadhaar Number is required when marked applicable.';
    }
    if ((int)$private['uan_applicable'] === 1 && !$private['uan_number_enc']) {
        $errors[] = 'UAN Number is required when marked applicable.';
    }
    if ((int)$private['esic_applicable'] === 1 && !$private['esic_number_enc']) {
        $errors[] = 'ESIC IP Number is required when marked applicable.';
    }

    return $errors;
}

function validateVerhoeff($number) {
    $number = preg_replace('/\D/', '', (string)$number);
    if ($number === '') {
        return false;
    }

    $multiplication = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
        [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
        [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
        [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
        [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
        [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
        [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
        [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
        [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
    ];
    $permutation = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
        [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
        [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
        [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
        [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
        [2, 7, 9, 4, 8, 1, 5, 3, 6, 0],
        [7, 0, 4, 3, 9, 5, 2, 1, 6, 8]
    ];
    $inverse = [0, 4, 3, 2, 1, 5, 6, 7, 8, 9];
    $checksum = 0;
    $digits = array_reverse(array_map('intval', str_split($number)));
    foreach ($digits as $index => $digit) {
        $checksum = $multiplication[$checksum][$permutation[$index % 8][$digit]];
    }
    return $checksum === 0;
}

/**
 * Reveals an unmasked sensitive statutory field for Admin or HO Users.
 * Branch Users are DENIED. Action is logged in security_audit_log (without logging the plain value!).
 */
function revealKycField($conn, $employeeId, $fieldName) {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $liveRole = $liveUser['role_name'];

    if (!canAccessSensitiveKyc($conn, $liveUser)) {
        http_response_code(403);
        exit('KYC sensitive permission required.');
    }

    $allowedFields = ['pan', 'aadhaar', 'uan', 'esic'];
    if (!in_array($fieldName, $allowedFields, true)) {
        http_response_code(400);
        exit('Invalid field requested for reveal.');
    }

    $private = getKycPrivateData($conn, $employeeId);
    if (!$private) {
        return '';
    }

    $colMap = [
        'pan' => 'pan_number_enc',
        'aadhaar' => 'aadhaar_number_enc',
        'uan' => 'uan_number_enc',
        'esic' => 'esic_number_enc'
    ];

    $encVal = $private[$colMap[$fieldName]] ?? '';
    $decrypted = decryptKycField($encVal);

    // Audit event (NEVER log the revealed value!)
    auditEvent($conn, 'kyc_sensitive_field_revealed', 'employee_kyc', (int)$private['kyc_id'], ['field' => $fieldName]);

    return $decrypted;
}

/* ==========================================================================
   MASKING & ENCRYPTION UTILITIES
   ========================================================================== */

/**
 * Generic string masking utility for sensitive identifiers (e.g. Aadhaar, PAN, Bank AC).
 * Shows only the last $visibleSuffixCount characters.
 */
function maskIdentifier($value, $visibleSuffixCount = 4) {
    $value = trim((string)$value);
    $len = mb_strlen($value);
    if ($len === 0) {
        return '';
    }
    if ($len <= $visibleSuffixCount) {
        return str_repeat('X', $len);
    }
    $maskedCount = $len - $visibleSuffixCount;
    $suffix = mb_substr($value, -$visibleSuffixCount);
    return str_repeat('X', $maskedCount) . $suffix;
}

function maskPhone($phone) {
    $clean = preg_replace('/\D/', '', (string)$phone);
    if (strlen($clean) >= 10) {
        return 'XXXXXX' . substr($clean, -4);
    }
    return maskIdentifier($phone, 3);
}

function maskEmail($email) {
    $email = trim((string)$email);
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return '***@***';
    }
    $parts = explode('@', $email, 2);
    $name = $parts[0];
    $domain = $parts[1];
    $maskedName = (strlen($name) <= 2) ? $name[0] . '*' : $name[0] . '***' . substr($name, -1);
    return $maskedName . '@' . $domain;
}

function maskAddress($address) {
    $address = trim((string)$address);
    if ($address === '') return '';
    $parts = array_map('trim', explode(',', $address));
    if (count($parts) >= 2) {
        return '***, ' . implode(', ', array_slice($parts, -2));
    }
    return '***';
}

function getKycPrivateConfigDirectory() {
    $privateDirectory = dirname(__DIR__, 3) . '/georoster-config';
    $documentRoot = $_SERVER['DOCUMENT_ROOT'] ?? '';
    if ($documentRoot !== '') {
        $documentRoot = realpath($documentRoot) ?: $documentRoot;
        $privateRealParent = realpath(dirname($privateDirectory)) ?: dirname($privateDirectory);
        $documentRoot = rtrim($documentRoot, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR;
        $privateRealParent = rtrim($privateRealParent, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR;
        if (strpos($privateRealParent, $documentRoot) === 0) {
            failClosedKycSecret('private configuration location');
        }
    }
    return $privateDirectory;
}

function getKycSecretFromPrivateFile($fileName, $configKey) {
    $privatePath = getKycPrivateConfigDirectory() . '/' . $fileName;
    if (!is_file($privatePath) || !is_readable($privatePath)) {
        return null;
    }

    try {
        $value = include $privatePath;
    } catch (Throwable $exception) {
        return null;
    }

    if (is_array($value)) {
        $value = $value[$configKey] ?? null;
    }
    return is_string($value) ? $value : null;
}

function validateKycSecret($value) {
    if (!is_string($value) || !preg_match('/\A[0-9a-fA-F]{64}\z/', $value)) {
        return null;
    }

    $decoded = hex2bin($value);
    return ($decoded !== false && strlen($decoded) === 32) ? $decoded : null;
}

function failClosedKycSecret($secretName) {
    error_log('KYC security configuration unavailable for ' . $secretName . '.');
    throw new RuntimeException('KYC security configuration is unavailable.');
}

function getKycEncryptionKey($providedValue = null) {
    $value = $providedValue;
    if ($value === null) {
        $value = getenv('GEOROSTER_KYC_ENCRYPTION_KEY');
        if ($value === false || $value === '') {
            $value = getKycSecretFromPrivateFile('kyc_key.php', 'encryption_key');
        }
    }

    $key = validateKycSecret($value);
    if ($key === null) {
        failClosedKycSecret('encryption');
    }
    return $key;
}

function getKycHmacKey($providedValue = null) {
    $value = $providedValue;
    if ($value === null) {
        $value = getenv('GEOROSTER_KYC_HMAC_KEY');
        if ($value === false || $value === '') {
            $value = getKycSecretFromPrivateFile('kyc_hmac_key.php', 'hmac_key');
        }
    }

    $key = validateKycSecret($value);
    if ($key === null) {
        failClosedKycSecret('HMAC');
    }
    return $key;
}

/**
 * Encrypts a sensitive plaintext field using sodium or OpenSSL AES-256-GCM.
 */
function encryptKycField($plaintext, $keyHex = null) {
    $plaintext = (string)$plaintext;
    if ($plaintext === '') return '';

    $key = getKycEncryptionKey($keyHex);

    if (function_exists('sodium_crypto_secretbox')) {
        $nonce = random_bytes(SODIUM_CRYPTO_SECRETBOX_NONCEBYTES);
        $ciphertext = sodium_crypto_secretbox($plaintext, $nonce, $key);
        return 'v1:sodium:' . base64_encode($nonce . $ciphertext);
    }

    // OpenSSL fallback
    $iv = random_bytes(12);
    $tag = '';
    $ciphertext = openssl_encrypt($plaintext, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
    return 'v1:gcm:' . base64_encode($iv . $tag . $ciphertext);
}

/**
 * Decrypts a ciphertext encrypted by encryptKycField.
 */
function decryptKycField($encryptedPayload, $keyHex = null) {
    $encryptedPayload = (string)$encryptedPayload;
    if ($encryptedPayload === '') return '';

    if (strpos($encryptedPayload, 'v1:') !== 0) {
        failClosedKycSecret('encrypted payload');
    }

    $key = getKycEncryptionKey($keyHex);

    $parts = explode(':', $encryptedPayload, 3);
    $engine = $parts[1] ?? '';
    $raw = base64_decode($parts[2] ?? '', true);
    if ($raw === false) {
        failClosedKycSecret('ciphertext');
    }

    if ($engine === 'sodium' && function_exists('sodium_crypto_secretbox_open')) {
        $nonceBytes = SODIUM_CRYPTO_SECRETBOX_NONCEBYTES;
        if (strlen($raw) <= $nonceBytes) {
            failClosedKycSecret('ciphertext');
        }
        $nonce = substr($raw, 0, $nonceBytes);
        $ciphertext = substr($raw, $nonceBytes);
        $plain = sodium_crypto_secretbox_open($ciphertext, $nonce, $key);
        if ($plain === false) {
            failClosedKycSecret('decryption');
        }
        return $plain;
    }

    if ($engine === 'gcm') {
        if (strlen($raw) <= 28) {
            failClosedKycSecret('ciphertext');
        }
        $iv = substr($raw, 0, 12);
        $tag = substr($raw, 12, 16);
        $ciphertext = substr($raw, 28);
        $plain = openssl_decrypt($ciphertext, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
        if ($plain === false) {
            failClosedKycSecret('decryption');
        }
        return $plain;
    }

    failClosedKycSecret('ciphertext');
}

/**
 * Generates a keyed blind index (HMAC-SHA256) for exact-match searching on encrypted fields.
 */
function generateBlindIndex($value, $hmacKey = null) {
    $value = trim((string)$value);
    if ($value === '') return '';
    return hash_hmac('sha256', mb_strtolower($value), getKycHmacKey($hmacKey));
}

/* ==========================================================================
   KYC AMENDMENT WORKFLOW (Prompt 03C)
   ========================================================================== */

define('AMENDMENT_STATUS_REQUESTED', 'REQUESTED');
define('AMENDMENT_STATUS_DRAFT', 'DRAFT');
define('AMENDMENT_STATUS_SUBMITTED', 'SUBMITTED');
define('AMENDMENT_STATUS_UNDER_REVIEW', 'UNDER_REVIEW');
define('AMENDMENT_STATUS_APPROVED', 'APPROVED');
define('AMENDMENT_STATUS_REJECTED', 'REJECTED');
define('AMENDMENT_STATUS_CANCELLED', 'CANCELLED');

/**
 * Checks if an employee has an active amendment (states: REQUESTED, DRAFT, SUBMITTED, UNDER_REVIEW).
 * Returns the amendment array or NULL.
 */
function getKycActiveAmendment($conn, $kycId) {
    $kycId = (int)$kycId;
    $activeStates = [AMENDMENT_STATUS_REQUESTED, AMENDMENT_STATUS_DRAFT, AMENDMENT_STATUS_SUBMITTED, AMENDMENT_STATUS_UNDER_REVIEW];
    $placeholders = implode(',', array_fill(0, count($activeStates), '?'));
    $sql = "SELECT amendment_id, kyc_id, employee_id, amendment_status, request_reason, requested_by, requested_at, reviewed_by, reviewed_at, rejection_reason, approved_by, approved_at, created_at, updated_at FROM employee_kyc_amendments WHERE kyc_id = ? AND amendment_status IN ($placeholders) LIMIT 1";
    $stmt = $conn->prepare($sql);
    $types = 'i' . str_repeat('s', count($activeStates));
    $params = [$kycId];
    $params = array_merge($params, $activeStates);
    $bindParams = [$types];
    foreach ($params as $k => $v) {
        $bindParams[] = &$params[$k];
    }
    call_user_func_array([$stmt, 'bind_param'], $bindParams);
    $stmt->execute();
    $res = $stmt->get_result();
    return $res ? $res->fetch_assoc() : null;
}

function getKycLatestAmendment($conn, $kycId) {
    $kycId = (int)$kycId;
    $stmt = $conn->prepare("SELECT amendment_id, kyc_id, employee_id, amendment_status, request_reason, requested_by, requested_at, reviewed_by, reviewed_at, rejection_reason, approved_by, approved_at, created_at, updated_at FROM employee_kyc_amendments WHERE kyc_id = ? ORDER BY amendment_id DESC LIMIT 1");
    $stmt->bind_param('i', $kycId);
    $stmt->execute();
    $res = $stmt->get_result();
    return $res ? $res->fetch_assoc() : null;
}

/**
 * Requests a KYC amendment for a VERIFIED employee.
 * Creates amendment record + snapshot of current verified data into amendment_private table.
 * Sets amendment to DRAFT status for editing.
 */
function requestKycAmendment($conn, $employeeId, $reason) {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $liveRole = $liveUser['role_name'];
    $actorId = (int)$liveUser['user_id'];
    $employeeId = (int)$employeeId;

    if (!in_array($liveRole, ['Admin', 'HO User', 'Branch User'], true)) {
        http_response_code(403);
        exit('Unauthorized to request amendment.');
    }

    $reason = trim((string)$reason);
    if ($reason === '' || mb_strlen($reason) < 10) {
        $_SESSION['flash_error'] = 'Amendment reason must be at least 10 characters.';
        return false;
    }
    if (mb_strlen($reason) > 500) {
        $reason = mb_substr($reason, 0, 500);
    }

    $profile = getKycProfile($conn, $employeeId);
    if (!$profile) {
        $_SESSION['flash_error'] = 'KYC profile does not exist.';
        return false;
    }

    if ($profile['kyc_status'] !== KYC_STATUS_VERIFIED) {
        $_SESSION['flash_error'] = 'Amendment can only be requested for VERIFIED KYC profiles.';
        return false;
    }

    $kycId = (int)$profile['kyc_id'];

    // Enforce one-active-amendment rule
    $activeAmend = getKycActiveAmendment($conn, $kycId);
    if ($activeAmend) {
        $_SESSION['flash_error'] = 'An amendment is already active for this employee. Only one amendment per profile allowed.';
        return false;
    }

    $conn->begin_transaction();
    try {
        // Create amendment header record
        $insertAmend = $conn->prepare('INSERT INTO employee_kyc_amendments (kyc_id, employee_id, amendment_status, request_reason, requested_by, requested_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, NOW(), NOW(), NOW())');
        $status = AMENDMENT_STATUS_DRAFT;
        $insertAmend->bind_param('iissi', $kycId, $employeeId, $status, $reason, $actorId);
        $insertAmend->execute();
        $amendmentId = $insertAmend->insert_id;

        // Snapshot current verified private data into amendment_private
        $currentPrivate = getKycPrivateData($conn, $employeeId);
        if ($currentPrivate) {
            $insertPrivate = $conn->prepare('INSERT INTO employee_kyc_amendment_private (amendment_id, kyc_id, employee_id, date_of_birth, mobile_number, current_address, permanent_address, same_as_current, pan_applicable, aadhaar_applicable, uan_applicable, esic_applicable, pan_number_enc, pan_hmac, aadhaar_number_enc, aadhaar_hmac, uan_number_enc, uan_hmac, esic_number_enc, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())');
            $insertPrivate->bind_param('iiissssiiiiisssssss', $amendmentId, $kycId, $employeeId, $currentPrivate['date_of_birth'], $currentPrivate['mobile_number'], $currentPrivate['current_address'], $currentPrivate['permanent_address'], $currentPrivate['same_as_current'], $currentPrivate['pan_applicable'], $currentPrivate['aadhaar_applicable'], $currentPrivate['uan_applicable'], $currentPrivate['esic_applicable'], $currentPrivate['pan_number_enc'], $currentPrivate['pan_hmac'], $currentPrivate['aadhaar_number_enc'], $currentPrivate['aadhaar_hmac'], $currentPrivate['uan_number_enc'], $currentPrivate['uan_hmac'], $currentPrivate['esic_number_enc']);
            $insertPrivate->execute();
        }

        // Record history
        $histStmt = $conn->prepare('INSERT INTO employee_kyc_history (kyc_id, employee_id, actor_user_id, action, previous_status, new_status, remarks, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())');
        $action = 'amendment_requested';
        $prevStatus = KYC_STATUS_VERIFIED;
        $nextStatus = KYC_STATUS_VERIFIED; // Status doesn't change, amendment is separate lifecycle
        $remark = 'Amendment requested: ' . $reason;
        $histStmt->bind_param('iiissss', $kycId, $employeeId, $actorId, $action, $prevStatus, $nextStatus, $remark);
        $histStmt->execute();

        $conn->commit();
        auditEvent($conn, 'kyc_amendment_requested', 'employee_kyc_amendments', $amendmentId);
        return true;

    } catch (Throwable $e) {
        $conn->rollback();
        error_log('Failed to request amendment: ' . $e->getMessage());
        $_SESSION['flash_error'] = 'Error creating amendment. Please try again.';
        return false;
    }
}

/**
 * Updates basic fields in a DRAFT or REQUESTED amendment.
 */
function updateKycAmendmentBasicData($conn, $employeeId, $amendmentId, $dob, $mobile, $currentAddr, $permAddr, $sameAsCurrent) {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $liveRole = $liveUser['role_name'];
    $actorId = (int)$liveUser['user_id'];
    $amendmentId = (int)$amendmentId;
    $employeeId = (int)$employeeId;

    $amendment = getAmendmentById($conn, $amendmentId);
    if (!$amendment || (int)$amendment['employee_id'] !== $employeeId) {
        http_response_code(404);
        exit('Amendment not found or access denied.');
    }

    if (!in_array($amendment['amendment_status'], [AMENDMENT_STATUS_DRAFT, AMENDMENT_STATUS_REQUESTED], true)) {
        $_SESSION['flash_error'] = 'Cannot edit amendment in current status.';
        return false;
    }

    // Branch Users can only edit amendments for their own branch
    if ($liveRole === 'Branch User') {
        $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
        $employee = $authContext['employee'];
        if ((int)$liveUser['branch_id'] !== (int)$employee['branch_id']) {
            http_response_code(403);
            exit('Cross-branch amendment access denied.');
        }
    }

    $dob = validDateValue($dob);
    $mobile = trim((string)$mobile);
    if ($mobile !== '' && !preg_match('/^[6-9]\d{9}$/', $mobile)) {
        $_SESSION['flash_error'] = 'Invalid Indian 10-digit mobile number.';
        return false;
    }

    $currentAddr = trim((string)$currentAddr);
    $sameAsCurrent = $sameAsCurrent ? 1 : 0;
    if ($sameAsCurrent) {
        $permAddr = $currentAddr;
    } else {
        $permAddr = trim((string)$permAddr);
    }

    $stmt = $conn->prepare('UPDATE employee_kyc_amendment_private SET date_of_birth = ?, mobile_number = ?, current_address = ?, permanent_address = ?, same_as_current = ?, updated_at = NOW() WHERE amendment_id = ?');
    $stmt->bind_param('ssssii', $dob, $mobile, $currentAddr, $permAddr, $sameAsCurrent, $amendmentId);
    $stmt->execute();

    auditEvent($conn, 'kyc_amendment_basic_updated', 'employee_kyc_amendments', $amendmentId);
    return true;
}

/**
 * Updates statutory fields in a DRAFT or REQUESTED amendment.
 * Branch Users cannot edit statutory fields.
 */
function updateKycAmendmentStatutoryData($conn, $employeeId, $amendmentId, $panApp, $aadhaarApp, $uanApp, $esicApp, $panRaw, $aadhaarRaw, $uanRaw, $esicRaw) {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $liveRole = $liveUser['role_name'];
    $actorId = (int)$liveUser['user_id'];
    $amendmentId = (int)$amendmentId;
    $employeeId = (int)$employeeId;

    if (!canAccessSensitiveKyc($conn, $liveUser)) {
        http_response_code(403);
        exit('KYC sensitive permission required.');
    }

    $amendment = getAmendmentById($conn, $amendmentId);
    if (!$amendment || (int)$amendment['employee_id'] !== $employeeId) {
        http_response_code(404);
        exit('Amendment not found or access denied.');
    }

    if (!in_array($amendment['amendment_status'], [AMENDMENT_STATUS_DRAFT, AMENDMENT_STATUS_REQUESTED], true)) {
        $_SESSION['flash_error'] = 'Cannot edit amendment in current status.';
        return false;
    }

    $panApp = $panApp ? 1 : 0;
    $aadhaarApp = $aadhaarApp ? 1 : 0;
    $uanApp = $uanApp ? 1 : 0;
    $esicApp = $esicApp ? 1 : 0;

    // Validate and encrypt PAN
    $panRaw = strtoupper(trim((string)$panRaw));
    $panEnc = null;
    $panHmac = null;
    if ($panRaw !== '') {
        if (!preg_match('/^[A-Z]{5}[0-9]{4}[A-Z]{1}$/', $panRaw)) {
            $_SESSION['flash_error'] = 'Invalid PAN Number format.';
            return false;
        }
        $panHmac = generateBlindIndex($panRaw);
        // Exclude current employee from self-conflict detection
        $dupStmt = $conn->prepare('SELECT COUNT(*) as cnt FROM employee_kyc_private WHERE pan_hmac = ? AND employee_id <> ? LIMIT 1');
        $dupStmt->bind_param('si', $panHmac, $employeeId);
        $dupStmt->execute();
        $dupRes = $dupStmt->get_result()->fetch_assoc();
        if ((int)$dupRes['cnt'] > 0) {
            $_SESSION['flash_error'] = 'PAN Number is already associated with another employee.';
            return false;
        }
        $panEnc = encryptKycField($panRaw);
    }

    // Validate and encrypt Aadhaar
    $aadhaarRaw = preg_replace('/\D/', '', (string)$aadhaarRaw);
    $aadhaarEnc = null;
    $aadhaarHmac = null;
    if ($aadhaarRaw !== '') {
        if (strlen($aadhaarRaw) !== 12 || !validateVerhoeff($aadhaarRaw)) {
            $_SESSION['flash_error'] = 'Invalid Aadhaar Number.';
            return false;
        }
        $aadhaarHmac = generateBlindIndex($aadhaarRaw);
        $dupStmt = $conn->prepare('SELECT COUNT(*) as cnt FROM employee_kyc_private WHERE aadhaar_hmac = ? AND employee_id <> ? LIMIT 1');
        $dupStmt->bind_param('si', $aadhaarHmac, $employeeId);
        $dupStmt->execute();
        $dupRes = $dupStmt->get_result()->fetch_assoc();
        if ((int)$dupRes['cnt'] > 0) {
            $_SESSION['flash_error'] = 'Aadhaar Number is already associated with another employee.';
            return false;
        }
        $aadhaarEnc = encryptKycField($aadhaarRaw);
    }

    // Validate and encrypt UAN
    $uanRaw = preg_replace('/\D/', '', (string)$uanRaw);
    $uanEnc = null;
    $uanHmac = null;
    if ($uanRaw !== '') {
        if (strlen($uanRaw) !== 12) {
            $_SESSION['flash_error'] = 'Invalid UAN Number (Must be 12 digits).';
            return false;
        }
        $uanHmac = generateBlindIndex($uanRaw);
        $dupStmt = $conn->prepare('SELECT COUNT(*) as cnt FROM employee_kyc_private WHERE uan_hmac = ? AND employee_id <> ? LIMIT 1');
        $dupStmt->bind_param('si', $uanHmac, $employeeId);
        $dupStmt->execute();
        $dupRes = $dupStmt->get_result()->fetch_assoc();
        if ((int)$dupRes['cnt'] > 0) {
            $_SESSION['flash_error'] = 'UAN Number is already associated with another employee.';
            return false;
        }
        $uanEnc = encryptKycField($uanRaw);
    }

    // Validate and encrypt ESIC
    $esicRaw = preg_replace('/\D/', '', (string)$esicRaw);
    $esicEnc = null;
    if ($esicRaw !== '') {
        if (strlen($esicRaw) !== 17) {
            $_SESSION['flash_error'] = 'Invalid ESIC IP Number (Must be 17 digits).';
            return false;
        }
        $esicEnc = encryptKycField($esicRaw);
    }

    $stmt = $conn->prepare('UPDATE employee_kyc_amendment_private SET pan_applicable = ?, aadhaar_applicable = ?, uan_applicable = ?, esic_applicable = ?, pan_number_enc = ?, pan_hmac = ?, aadhaar_number_enc = ?, aadhaar_hmac = ?, uan_number_enc = ?, uan_hmac = ?, esic_number_enc = ?, updated_at = NOW() WHERE amendment_id = ?');
    $stmt->bind_param('iiiisssssssi', $panApp, $aadhaarApp, $uanApp, $esicApp, $panEnc, $panHmac, $aadhaarEnc, $aadhaarHmac, $uanEnc, $uanHmac, $esicEnc, $amendmentId);
    $stmt->execute();

    auditEvent($conn, 'kyc_amendment_statutory_updated', 'employee_kyc_amendments', $amendmentId);
    return true;
}

/**
 * Submits a DRAFT amendment for review (DRAFT -> SUBMITTED).
 * Validates the resulting KYC is complete.
 */
function submitKycAmendment($conn, $employeeId, $amendmentId) {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $liveRole = $liveUser['role_name'];
    $actorId = (int)$liveUser['user_id'];
    $amendmentId = (int)$amendmentId;
    $employeeId = (int)$employeeId;

    $amendment = getAmendmentById($conn, $amendmentId);
    if (!$amendment || (int)$amendment['employee_id'] !== $employeeId) {
        http_response_code(404);
        exit('Amendment not found or access denied.');
    }

    if ($amendment['amendment_status'] !== AMENDMENT_STATUS_DRAFT) {
        $_SESSION['flash_error'] = 'Only DRAFT amendments can be submitted.';
        return false;
    }

    // Validate amendment data completeness
    $amendPrivate = getAmendmentPrivateData($conn, $amendmentId);
    if (!$amendPrivate) {
        $_SESSION['flash_error'] = 'Amendment data is incomplete.';
        return false;
    }

    $errors = validateKycAmendmentCompletion($amendPrivate);
    if (!empty($errors)) {
        $_SESSION['flash_error'] = 'Amendment incomplete: ' . implode(' ', $errors);
        return false;
    }

    $conn->begin_transaction();
    try {
        $kycId = (int)$amendment['kyc_id'];
        $newStatus = AMENDMENT_STATUS_SUBMITTED;
        $updateStmt = $conn->prepare('UPDATE employee_kyc_amendments SET amendment_status = ?, updated_at = NOW() WHERE amendment_id = ?');
        $updateStmt->bind_param('si', $newStatus, $amendmentId);
        $updateStmt->execute();

        $histStmt = $conn->prepare('INSERT INTO employee_kyc_history (kyc_id, employee_id, actor_user_id, action, previous_status, new_status, remarks, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())');
        $action = 'amendment_submitted';
        $prevStatus = KYC_STATUS_VERIFIED;
        $nextStatus = KYC_STATUS_VERIFIED;
        $remark = 'Amendment submitted for verification review.';
        $histStmt->bind_param('iiissss', $kycId, $employeeId, $actorId, $action, $prevStatus, $nextStatus, $remark);
        $histStmt->execute();

        $conn->commit();
        auditEvent($conn, 'kyc_amendment_submitted', 'employee_kyc_amendments', $amendmentId);
        return true;

    } catch (Throwable $e) {
        $conn->rollback();
        error_log('Failed to submit amendment: ' . $e->getMessage());
        $_SESSION['flash_error'] = 'Error submitting amendment.';
        return false;
    }
}

/**
 * Starts review of a SUBMITTED amendment (SUBMITTED -> UNDER_REVIEW).
 * HO and Admin only.
 */
function startReviewKycAmendment($conn, $employeeId, $amendmentId) {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $liveRole = $liveUser['role_name'];
    $actorId = (int)$liveUser['user_id'];
    $amendmentId = (int)$amendmentId;
    $employeeId = (int)$employeeId;

    if (!in_array($liveRole, ['Admin', 'HO User'], true) && !hasKycOfficerPermission($conn, $actorId)) {
        http_response_code(403);
        exit('Only Admin and HO Users can start amendment review.');
    }

    $amendment = getAmendmentById($conn, $amendmentId);
    if (!$amendment || (int)$amendment['employee_id'] !== $employeeId) {
        http_response_code(404);
        exit('Amendment not found or access denied.');
    }

    if ($amendment['amendment_status'] !== AMENDMENT_STATUS_SUBMITTED) {
        $_SESSION['flash_error'] = 'Only SUBMITTED amendments can enter review.';
        return false;
    }

    $conn->begin_transaction();
    try {
        $kycId = (int)$amendment['kyc_id'];
        $newStatus = AMENDMENT_STATUS_UNDER_REVIEW;
        $updateStmt = $conn->prepare('UPDATE employee_kyc_amendments SET amendment_status = ?, reviewed_by = ?, reviewed_at = NOW(), updated_at = NOW() WHERE amendment_id = ?');
        $updateStmt->bind_param('sii', $newStatus, $actorId, $amendmentId);
        $updateStmt->execute();

        $histStmt = $conn->prepare('INSERT INTO employee_kyc_history (kyc_id, employee_id, actor_user_id, action, previous_status, new_status, remarks, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())');
        $action = 'amendment_under_review';
        $prevStatus = KYC_STATUS_VERIFIED;
        $nextStatus = KYC_STATUS_VERIFIED;
        $remark = 'Amendment moved to review by ' . $liveUser['full_name'];
        $histStmt->bind_param('iiissss', $kycId, $employeeId, $actorId, $action, $prevStatus, $nextStatus, $remark);
        $histStmt->execute();

        $conn->commit();
        auditEvent($conn, 'kyc_amendment_review_started', 'employee_kyc_amendments', $amendmentId);
        return true;

    } catch (Throwable $e) {
        $conn->rollback();
        error_log('Failed to start amendment review: ' . $e->getMessage());
        $_SESSION['flash_error'] = 'Error starting amendment review.';
        return false;
    }
}

/**
 * Approves and applies amendment (UNDER_REVIEW -> APPROVED).
 * Admin only. Transactional: updates live KYC data, marks amendment APPROVED.
 */
function approveKycAmendment($conn, $employeeId, $amendmentId) {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $liveRole = $liveUser['role_name'];
    $actorId = (int)$liveUser['user_id'];
    $amendmentId = (int)$amendmentId;
    $employeeId = (int)$employeeId;

    if ($liveRole !== 'Admin') {
        http_response_code(403);
        exit('Only Admin can approve amendments.');
    }

    $amendment = getAmendmentById($conn, $amendmentId);
    if (!$amendment || (int)$amendment['employee_id'] !== $employeeId) {
        http_response_code(404);
        exit('Amendment not found or access denied.');
    }

    if ($amendment['amendment_status'] !== AMENDMENT_STATUS_UNDER_REVIEW) {
        $_SESSION['flash_error'] = 'Only UNDER_REVIEW amendments can be approved.';
        return false;
    }

    $kycId = (int)$amendment['kyc_id'];
    $amendPrivate = getAmendmentPrivateData($conn, $amendmentId);
    if (!$amendPrivate) {
        $_SESSION['flash_error'] = 'Amendment data not found.';
        return false;
    }

    // Final validation
    $errors = validateKycAmendmentCompletion($amendPrivate);
    if (!empty($errors)) {
        $_SESSION['flash_error'] = 'Amendment data is incomplete or invalid.';
        return false;
    }

    $conn->begin_transaction();
    try {
        // Update live KYC private data with amendment values
        $updatePrivate = $conn->prepare('UPDATE employee_kyc_private SET date_of_birth = ?, mobile_number = ?, current_address = ?, permanent_address = ?, same_as_current = ?, pan_applicable = ?, aadhaar_applicable = ?, uan_applicable = ?, esic_applicable = ?, pan_number_enc = ?, pan_hmac = ?, aadhaar_number_enc = ?, aadhaar_hmac = ?, uan_number_enc = ?, uan_hmac = ?, esic_number_enc = ?, updated_at = NOW() WHERE employee_id = ?');
        $updatePrivate->bind_param('ssssiiiiisssssssi', $amendPrivate['date_of_birth'], $amendPrivate['mobile_number'], $amendPrivate['current_address'], $amendPrivate['permanent_address'], $amendPrivate['same_as_current'], $amendPrivate['pan_applicable'], $amendPrivate['aadhaar_applicable'], $amendPrivate['uan_applicable'], $amendPrivate['esic_applicable'], $amendPrivate['pan_number_enc'], $amendPrivate['pan_hmac'], $amendPrivate['aadhaar_number_enc'], $amendPrivate['aadhaar_hmac'], $amendPrivate['uan_number_enc'], $amendPrivate['uan_hmac'], $amendPrivate['esic_number_enc'], $employeeId);
        $updatePrivate->execute();

        // Mark amendment APPROVED
        $newStatus = AMENDMENT_STATUS_APPROVED;
        $updateAmend = $conn->prepare('UPDATE employee_kyc_amendments SET amendment_status = ?, approved_by = ?, approved_at = NOW(), updated_at = NOW() WHERE amendment_id = ?');
        $updateAmend->bind_param('sii', $newStatus, $actorId, $amendmentId);
        $updateAmend->execute();

        // Update KYC main record - ensure it remains VERIFIED
        $updateKyc = $conn->prepare('UPDATE employee_kyc SET updated_at = NOW(), updated_by = ? WHERE kyc_id = ?');
        $updateKyc->bind_param('ii', $actorId, $kycId);
        $updateKyc->execute();

        // Record history
        $histStmt = $conn->prepare('INSERT INTO employee_kyc_history (kyc_id, employee_id, actor_user_id, action, previous_status, new_status, remarks, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())');
        $action = 'amendment_approved';
        $prevStatus = KYC_STATUS_VERIFIED;
        $nextStatus = KYC_STATUS_VERIFIED;
        $remark = 'Amendment approved and applied. KYC re-verified by Admin.';
        $histStmt->bind_param('iiissss', $kycId, $employeeId, $actorId, $action, $prevStatus, $nextStatus, $remark);
        $histStmt->execute();

        $conn->commit();
        auditEvent($conn, 'kyc_amendment_approved', 'employee_kyc_amendments', $amendmentId);
        return true;

    } catch (Throwable $e) {
        $conn->rollback();
        error_log('Failed to approve amendment: ' . $e->getMessage());
        $_SESSION['flash_error'] = 'Error approving amendment.';
        return false;
    }
}

/**
 * Rejects an amendment (UNDER_REVIEW -> REJECTED).
 * Admin only. Live KYC data remains unchanged.
 */
function rejectKycAmendment($conn, $employeeId, $amendmentId, $reason) {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $liveRole = $liveUser['role_name'];
    $actorId = (int)$liveUser['user_id'];
    $amendmentId = (int)$amendmentId;
    $employeeId = (int)$employeeId;

    if ($liveRole !== 'Admin') {
        http_response_code(403);
        exit('Only Admin can reject amendments.');
    }

    $amendment = getAmendmentById($conn, $amendmentId);
    if (!$amendment || (int)$amendment['employee_id'] !== $employeeId) {
        http_response_code(404);
        exit('Amendment not found or access denied.');
    }

    if ($amendment['amendment_status'] !== AMENDMENT_STATUS_UNDER_REVIEW) {
        $_SESSION['flash_error'] = 'Only UNDER_REVIEW amendments can be rejected.';
        return false;
    }

    $reason = trim((string)$reason);
    if ($reason === '') {
        $_SESSION['flash_error'] = 'Rejection reason is required.';
        return false;
    }
    if (mb_strlen($reason) > 500) {
        $reason = mb_substr($reason, 0, 500);
    }

    $conn->begin_transaction();
    try {
        $kycId = (int)$amendment['kyc_id'];
        $newStatus = AMENDMENT_STATUS_REJECTED;
        $updateStmt = $conn->prepare('UPDATE employee_kyc_amendments SET amendment_status = ?, rejection_reason = ?, updated_at = NOW() WHERE amendment_id = ?');
        $updateStmt->bind_param('ssi', $newStatus, $reason, $amendmentId);
        $updateStmt->execute();

        $histStmt = $conn->prepare('INSERT INTO employee_kyc_history (kyc_id, employee_id, actor_user_id, action, previous_status, new_status, remarks, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())');
        $action = 'amendment_rejected';
        $prevStatus = KYC_STATUS_VERIFIED;
        $nextStatus = KYC_STATUS_VERIFIED;
        $remark = 'Amendment rejected. Live KYC unchanged. Reason: ' . $reason;
        $histStmt->bind_param('iiissss', $kycId, $employeeId, $actorId, $action, $prevStatus, $nextStatus, $remark);
        $histStmt->execute();

        $conn->commit();
        auditEvent($conn, 'kyc_amendment_rejected', 'employee_kyc_amendments', $amendmentId);
        return true;

    } catch (Throwable $e) {
        $conn->rollback();
        error_log('Failed to reject amendment: ' . $e->getMessage());
        $_SESSION['flash_error'] = 'Error rejecting amendment.';
        return false;
    }
}

/**
 * Cancels a DRAFT or REQUESTED amendment without review.
 * Requester or Admin can cancel.
 */
function cancelKycAmendment($conn, $employeeId, $amendmentId) {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $liveRole = $liveUser['role_name'];
    $actorId = (int)$liveUser['user_id'];
    $amendmentId = (int)$amendmentId;
    $employeeId = (int)$employeeId;

    $amendment = getAmendmentById($conn, $amendmentId);
    if (!$amendment || (int)$amendment['employee_id'] !== $employeeId) {
        http_response_code(404);
        exit('Amendment not found or access denied.');
    }

    if (!in_array($amendment['amendment_status'], [AMENDMENT_STATUS_DRAFT, AMENDMENT_STATUS_REQUESTED], true)) {
        $_SESSION['flash_error'] = 'Only DRAFT or REQUESTED amendments can be cancelled.';
        return false;
    }

    if ($liveRole !== 'Admin' && (int)$amendment['requested_by'] !== $actorId) {
        http_response_code(403);
        exit('Only requester or Admin can cancel amendment.');
    }

    $conn->begin_transaction();
    try {
        $kycId = (int)$amendment['kyc_id'];
        $newStatus = AMENDMENT_STATUS_CANCELLED;
        $updateStmt = $conn->prepare('UPDATE employee_kyc_amendments SET amendment_status = ?, updated_at = NOW() WHERE amendment_id = ?');
        $updateStmt->bind_param('si', $newStatus, $amendmentId);
        $updateStmt->execute();

        $histStmt = $conn->prepare('INSERT INTO employee_kyc_history (kyc_id, employee_id, actor_user_id, action, previous_status, new_status, remarks, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())');
        $action = 'amendment_cancelled';
        $prevStatus = KYC_STATUS_VERIFIED;
        $nextStatus = KYC_STATUS_VERIFIED;
        $remark = 'Amendment cancelled without being submitted for review.';
        $histStmt->bind_param('iiissss', $kycId, $employeeId, $actorId, $action, $prevStatus, $nextStatus, $remark);
        $histStmt->execute();

        $conn->commit();
        auditEvent($conn, 'kyc_amendment_cancelled', 'employee_kyc_amendments', $amendmentId);
        return true;

    } catch (Throwable $e) {
        $conn->rollback();
        error_log('Failed to cancel amendment: ' . $e->getMessage());
        $_SESSION['flash_error'] = 'Error cancelling amendment.';
        return false;
    }
}

/**
 * Re-opens a REJECTED amendment for revision (REJECTED -> DRAFT).
 * Requester or Admin only.
 */
function reviseKycAmendment($conn, $employeeId, $amendmentId) {
    $authContext = requireAuthoritativeKycAccess($conn, $employeeId);
    $liveUser = $authContext['user'];
    $liveRole = $liveUser['role_name'];
    $actorId = (int)$liveUser['user_id'];
    $amendmentId = (int)$amendmentId;
    $employeeId = (int)$employeeId;

    $amendment = getAmendmentById($conn, $amendmentId);
    if (!$amendment || (int)$amendment['employee_id'] !== $employeeId) {
        http_response_code(404);
        exit('Amendment not found or access denied.');
    }

    if ($amendment['amendment_status'] !== AMENDMENT_STATUS_REJECTED) {
        $_SESSION['flash_error'] = 'Only REJECTED amendments can be revised.';
        return false;
    }

    if ($liveRole !== 'Admin' && (int)$amendment['requested_by'] !== $actorId) {
        http_response_code(403);
        exit('Only requester or Admin can revise amendment.');
    }

    $conn->begin_transaction();
    try {
        $kycId = (int)$amendment['kyc_id'];
        $newStatus = AMENDMENT_STATUS_DRAFT;
        $updateStmt = $conn->prepare('UPDATE employee_kyc_amendments SET amendment_status = ?, updated_at = NOW() WHERE amendment_id = ?');
        $updateStmt->bind_param('si', $newStatus, $amendmentId);
        $updateStmt->execute();

        $histStmt = $conn->prepare('INSERT INTO employee_kyc_history (kyc_id, employee_id, actor_user_id, action, previous_status, new_status, remarks, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())');
        $action = 'amendment_revised';
        $prevStatus = KYC_STATUS_VERIFIED;
        $nextStatus = KYC_STATUS_VERIFIED;
        $remark = 'Rejected amendment reopened for revision.';
        $histStmt->bind_param('iiissss', $kycId, $employeeId, $actorId, $action, $prevStatus, $nextStatus, $remark);
        $histStmt->execute();

        $conn->commit();
        auditEvent($conn, 'kyc_amendment_revised', 'employee_kyc_amendments', $amendmentId);
        return true;

    } catch (Throwable $e) {
        $conn->rollback();
        error_log('Failed to revise amendment: ' . $e->getMessage());
        $_SESSION['flash_error'] = 'Error revising amendment.';
        return false;
    }
}

/**
 * Helper: Fetch amendment record by ID.
 */
function getAmendmentById($conn, $amendmentId) {
    $amendmentId = (int)$amendmentId;
    $stmt = $conn->prepare('SELECT amendment_id, kyc_id, employee_id, amendment_status, request_reason, requested_by, requested_at, reviewed_by, reviewed_at, rejection_reason, approved_by, approved_at, created_at, updated_at FROM employee_kyc_amendments WHERE amendment_id = ? LIMIT 1');
    $stmt->bind_param('i', $amendmentId);
    $stmt->execute();
    $res = $stmt->get_result();
    return $res ? $res->fetch_assoc() : null;
}

/**
 * Helper: Fetch amendment_private data by amendment_id.
 */
function getAmendmentPrivateData($conn, $amendmentId) {
    $amendmentId = (int)$amendmentId;
    $stmt = $conn->prepare('SELECT amendment_private_id, amendment_id, kyc_id, employee_id, date_of_birth, mobile_number, current_address, permanent_address, same_as_current, pan_applicable, aadhaar_applicable, uan_applicable, esic_applicable, pan_number_enc, pan_hmac, aadhaar_number_enc, aadhaar_hmac, uan_number_enc, uan_hmac, esic_number_enc, created_at, updated_at FROM employee_kyc_amendment_private WHERE amendment_id = ? LIMIT 1');
    $stmt->bind_param('i', $amendmentId);
    $stmt->execute();
    $res = $stmt->get_result();
    return $res ? $res->fetch_assoc() : null;
}

function getKycAmendmentPrivateData($conn, $amendmentId) {
    return getAmendmentPrivateData($conn, $amendmentId);
}

/**
 * Helper: Validate amendment KYC data completeness (same rules as initial KYC).
 */
function validateKycAmendmentCompletion($amendPrivate) {
    $errors = [];

    if (!$amendPrivate['date_of_birth'] || !validDateValue($amendPrivate['date_of_birth'])) {
        $errors[] = 'Date of Birth is required.';
    }
    if (!$amendPrivate['mobile_number'] || !preg_match('/^[6-9]\d{9}$/', $amendPrivate['mobile_number'])) {
        $errors[] = 'Valid 10-digit mobile number is required.';
    }
    if (!$amendPrivate['current_address'] || mb_strlen($amendPrivate['current_address']) < 5) {
        $errors[] = 'Current Address is required.';
    }
    if ((int)$amendPrivate['same_as_current'] === 0) {
        if (!$amendPrivate['permanent_address'] || mb_strlen($amendPrivate['permanent_address']) < 5) {
            $errors[] = 'Permanent Address is required when different from current.';
        }
    }

    // Conditional statutory requirements
    if ((int)$amendPrivate['pan_applicable'] === 1) {
        if (!$amendPrivate['pan_number_enc'] || !$amendPrivate['pan_hmac']) {
            $errors[] = 'PAN Number is required when marked applicable.';
        }
    }
    if ((int)$amendPrivate['aadhaar_applicable'] === 1) {
        if (!$amendPrivate['aadhaar_number_enc'] || !$amendPrivate['aadhaar_hmac']) {
            $errors[] = 'Aadhaar Number is required when marked applicable.';
        }
    }
    if ((int)$amendPrivate['uan_applicable'] === 1) {
        if (!$amendPrivate['uan_number_enc'] || !$amendPrivate['uan_hmac']) {
            $errors[] = 'UAN Number is required when marked applicable.';
        }
    }
    if ((int)$amendPrivate['esic_applicable'] === 1) {
        if (!$amendPrivate['esic_number_enc']) {
            $errors[] = 'ESIC IP Number is required when marked applicable.';
        }
    }

    return $errors;
}

/**
 * Helper: Fetch operational review queue items for Admin/HO.
 * Returns safe columns only (no sensitive data).
 */
function getKycReviewQueue($conn, $userRole, $userBranchId) {
    $userBranchId = (int)$userBranchId;

    if ($userRole === 'Admin') {
        // Admin sees all
        $sql = "
            SELECT
                e.employee_id,
                e.employee_no,
                e.employee_name,
                e.branch_id,
                b.branch_name,
                e.employee_category AS employee_category,
                CASE
                    WHEN ka.amendment_id IS NOT NULL THEN 'AMENDMENT'
                    ELSE 'INITIAL'
                END AS workflow_type,
                COALESCE(ka.amendment_status, kp.kyc_status) AS status,
                COALESCE(ka.requested_at, kp.submitted_at, kp.created_at) AS submitted_at,
                COALESCE(ka.updated_at, kp.updated_at) AS updated_at,
                kp.kyc_id,
                ka.amendment_id
            FROM employees e
            LEFT JOIN branches b ON e.branch_id = b.branch_id
            LEFT JOIN employee_kyc kp ON e.employee_id = kp.employee_id
            LEFT JOIN employee_kyc_amendments ka ON kp.kyc_id = ka.kyc_id
                AND ka.amendment_status IN ('REQUESTED', 'DRAFT', 'SUBMITTED', 'UNDER_REVIEW')
            WHERE kp.kyc_id IS NOT NULL
                AND (kp.kyc_status IN ('SUBMITTED', 'UNDER_REVIEW', 'REJECTED')
                    OR ka.amendment_id IS NOT NULL)
            ORDER BY COALESCE(ka.updated_at, kp.updated_at) DESC
        ";
        $stmt = $conn->prepare($sql);
    } else {
        // HO sees their branch queue
        $sql = "
            SELECT
                e.employee_id,
                e.employee_no,
                e.employee_name,
                e.branch_id,
                b.branch_name,
                e.employee_category AS employee_category,
                CASE
                    WHEN ka.amendment_id IS NOT NULL THEN 'AMENDMENT'
                    ELSE 'INITIAL'
                END AS workflow_type,
                COALESCE(ka.amendment_status, kp.kyc_status) AS status,
                COALESCE(ka.requested_at, kp.submitted_at, kp.created_at) AS submitted_at,
                COALESCE(ka.updated_at, kp.updated_at) AS updated_at,
                kp.kyc_id,
                ka.amendment_id
            FROM employees e
            LEFT JOIN branches b ON e.branch_id = b.branch_id
            LEFT JOIN employee_kyc kp ON e.employee_id = kp.employee_id
            LEFT JOIN employee_kyc_amendments ka ON kp.kyc_id = ka.kyc_id
                AND ka.amendment_status IN ('REQUESTED', 'DRAFT', 'SUBMITTED', 'UNDER_REVIEW')
            WHERE e.branch_id = ?
                AND kp.kyc_id IS NOT NULL
                AND (kp.kyc_status IN ('SUBMITTED', 'UNDER_REVIEW', 'REJECTED')
                    OR ka.amendment_id IS NOT NULL)
            ORDER BY COALESCE(ka.updated_at, kp.updated_at) DESC
        ";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param('i', $userBranchId);
    }

    $stmt->execute();
    $res = $stmt->get_result();
    $items = [];
    while ($row = $res->fetch_assoc()) {
        $items[] = $row;
    }
    return $items;
}

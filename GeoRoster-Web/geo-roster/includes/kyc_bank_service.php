<?php

require_once __DIR__ . '/kyc_service.php';

const KYC_BANK_ACCOUNT_TYPES = ['SAVINGS', 'CURRENT', 'SALARY', 'OTHER'];

function normalizeBankAccountNumber($value) {
    $value = preg_replace('/[\s-]+/', '', trim((string)$value));
    return $value === null ? '' : $value;
}

function validateBankAccountNumber($value) {
    $value = normalizeBankAccountNumber($value);
    return $value !== '' && preg_match('/^[0-9]{6,24}$/', $value) === 1;
}

function normalizeIfscCode($value) {
    return preg_replace('/\s+/', '', strtoupper(trim((string)$value)));
}

function validateIfscCode($value) {
    return preg_match('/^[A-Z]{4}0[A-Z0-9]{6}$/', normalizeIfscCode($value)) === 1;
}

function normalizeBankBranchName($value) {
    return preg_replace('/\s+/', ' ', trim((string)$value));
}

function validateBankAccountType($value) {
    return in_array((string)$value, KYC_BANK_ACCOUNT_TYPES, true);
}

function validateKycBankDetails($accountNumber, $confirmAccountNumber, $ifscCode, $accountType, $branchName, $allowBlank = true) {
    $accountNumber = normalizeBankAccountNumber($accountNumber);
    $confirmAccountNumber = normalizeBankAccountNumber($confirmAccountNumber);
    $ifscCode = normalizeIfscCode($ifscCode);
    $accountType = trim((string)$accountType);
    $branchName = normalizeBankBranchName($branchName);
    $hasAny = $accountNumber !== '' || $ifscCode !== '' || $accountType !== '' || $branchName !== '';

    if (!$hasAny && $allowBlank) {
        return ['valid' => true, 'has_any' => false, 'account_number' => '', 'ifsc_code' => '', 'account_type' => '', 'branch_name' => ''];
    }
    if (!$hasAny) {
        return ['valid' => false, 'error' => 'All bank details are required.'];
    }
    if (!validateBankAccountNumber($accountNumber)) {
        return ['valid' => false, 'error' => 'Bank account number must contain 6 to 24 digits.'];
    }
    if ($confirmAccountNumber !== $accountNumber) {
        return ['valid' => false, 'error' => 'Bank account number confirmation does not match.'];
    }
    if (!validateIfscCode($ifscCode)) {
        return ['valid' => false, 'error' => 'IFSC code format is invalid.'];
    }
    if (!validateBankAccountType($accountType)) {
        return ['valid' => false, 'error' => 'Bank account type is invalid.'];
    }
    if ($branchName === '' || mb_strlen($branchName) > 150) {
        return ['valid' => false, 'error' => 'Bank branch name is required and must be at most 150 characters.'];
    }

    return ['valid' => true, 'has_any' => true, 'account_number' => $accountNumber, 'ifsc_code' => $ifscCode, 'account_type' => $accountType, 'branch_name' => $branchName];
}

function maskBankAccountNumber($value) {
    $value = normalizeBankAccountNumber($value);
    if ($value === '') {
        return 'Not Set';
    }
    return str_repeat('X', max(0, strlen($value) - 4)) . substr($value, -4);
}

function getKycBankDetails($conn, $employeeId) {
    $employeeId = (int)$employeeId;
    $stmt = $conn->prepare('SELECT bank_detail_id, kyc_id, employee_id, account_number_enc, account_number_hmac, ifsc_code, account_type, branch_name, created_by, created_at, updated_by, updated_at FROM employee_kyc_bank_private WHERE employee_id = ? LIMIT 1');
    $stmt->bind_param('i', $employeeId);
    $stmt->execute();
    return $stmt->get_result()->fetch_assoc() ?: null;
}

function getKycBankAmendmentDetails($conn, $amendmentId) {
    $amendmentId = (int)$amendmentId;
    $stmt = $conn->prepare('SELECT bank_amendment_private_id, amendment_id, kyc_id, employee_id, account_number_enc, account_number_hmac, ifsc_code, account_type, branch_name, created_at, updated_at FROM employee_kyc_bank_amendment_private WHERE amendment_id = ? LIMIT 1');
    $stmt->bind_param('i', $amendmentId);
    $stmt->execute();
    return $stmt->get_result()->fetch_assoc() ?: null;
}

function requireKycBankAccess($conn, $employeeId) {
    $auth = requireAuthoritativeKycAccess($conn, $employeeId);
    if (empty($auth['can_sensitive'])) {
        http_response_code(403);
        exit('KYC sensitive permission required.');
    }
    return $auth;
}

function saveKycBankDetails($conn, $employeeId, $accountNumber, $confirmAccountNumber, $ifscCode, $accountType, $branchName) {
    $auth = requireKycBankAccess($conn, $employeeId);
    $employeeId = (int)$employeeId;
    $profile = getKycProfile($conn, $employeeId);
    if (!$profile) {
        $_SESSION['flash_error'] = 'KYC profile does not exist.';
        return false;
    }
    if ($profile['kyc_status'] === KYC_STATUS_VERIFIED) {
        $_SESSION['flash_error'] = 'Verified KYC bank details can only be changed through an amendment.';
        return false;
    }

    $existing = getKycBankDetails($conn, $employeeId);
    if ($existing && normalizeBankAccountNumber($accountNumber) === '' && normalizeBankAccountNumber($confirmAccountNumber) === '' && ($ifscCode !== '' || $accountType !== '' || $branchName !== '')) {
        $accountNumber = decryptKycField($existing['account_number_enc']);
        $confirmAccountNumber = $accountNumber;
    }
    $validated = validateKycBankDetails($accountNumber, $confirmAccountNumber, $ifscCode, $accountType, $branchName);
    if (!$validated['valid']) {
        $_SESSION['flash_error'] = $validated['error'];
        return false;
    }
    if (!$validated['has_any']) {
        if (!$existing) {
            return true;
        }
        $_SESSION['flash_message'] = 'Existing bank details preserved.';
        return true;
    }

    $accountNumber = $validated['account_number'];
    $accountEnc = encryptKycField($accountNumber);
    $accountHmac = generateBlindIndex($accountNumber);
    $kycId = (int)$profile['kyc_id'];
    $actorId = (int)$auth['user']['user_id'];
    $stmt = $conn->prepare('INSERT INTO employee_kyc_bank_private (kyc_id, employee_id, account_number_enc, account_number_hmac, ifsc_code, account_type, branch_name, created_by, updated_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE account_number_enc = VALUES(account_number_enc), account_number_hmac = VALUES(account_number_hmac), ifsc_code = VALUES(ifsc_code), account_type = VALUES(account_type), branch_name = VALUES(branch_name), updated_by = VALUES(updated_by), updated_at = NOW()');
    $stmt->bind_param('iisssssii', $kycId, $employeeId, $accountEnc, $accountHmac, $validated['ifsc_code'], $validated['account_type'], $validated['branch_name'], $actorId, $actorId);
    if (!$stmt->execute()) {
        $_SESSION['flash_error'] = 'Unable to save bank details.';
        return false;
    }
    auditEvent($conn, $existing ? 'kyc_bank_details_updated' : 'kyc_bank_details_created', 'employee_kyc', $kycId, ['employee_id' => $employeeId, 'kyc_id' => $kycId]);
    return true;
}

function revealKycBankAccount($conn, $employeeId) {
    $auth = requireKycBankAccess($conn, $employeeId);
    $details = getKycBankDetails($conn, $employeeId);
    $value = $details ? decryptKycField($details['account_number_enc']) : '';
    auditEvent($conn, 'kyc_bank_account_revealed', 'employee_kyc', (int)($details['kyc_id'] ?? 0), ['employee_id' => (int)$employeeId, 'kyc_id' => (int)($details['kyc_id'] ?? 0)]);
    return $value;
}

function snapshotKycBankDetailsForAmendment($conn, $amendmentId, $kycId, $employeeId) {
    $current = getKycBankDetails($conn, $employeeId);
    $accountEnc = $current['account_number_enc'] ?? null;
    $accountHmac = $current['account_number_hmac'] ?? null;
    $ifscCode = $current['ifsc_code'] ?? null;
    $accountType = $current['account_type'] ?? null;
    $branchName = $current['branch_name'] ?? null;
    $stmt = $conn->prepare('INSERT INTO employee_kyc_bank_amendment_private (amendment_id, kyc_id, employee_id, account_number_enc, account_number_hmac, ifsc_code, account_type, branch_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
    $stmt->bind_param('iiisssss', $amendmentId, $kycId, $employeeId, $accountEnc, $accountHmac, $ifscCode, $accountType, $branchName);
    return $stmt->execute();
}

function updateKycBankAmendmentDetails($conn, $employeeId, $amendmentId, $accountNumber, $confirmAccountNumber, $ifscCode, $accountType, $branchName) {
    $auth = requireKycBankAccess($conn, $employeeId);
    $amendment = getAmendmentById($conn, $amendmentId);
    if (!$amendment || (int)$amendment['employee_id'] !== (int)$employeeId) {
        http_response_code(404);
        exit('Amendment not found or access denied.');
    }
    if (!in_array($amendment['amendment_status'], [AMENDMENT_STATUS_DRAFT, AMENDMENT_STATUS_REQUESTED], true)) {
        $_SESSION['flash_error'] = 'Cannot edit amendment in current status.';
        return false;
    }
    $existing = getKycBankAmendmentDetails($conn, $amendmentId);
    if ($existing && normalizeBankAccountNumber($accountNumber) === '' && normalizeBankAccountNumber($confirmAccountNumber) === '' && ($ifscCode !== '' || $accountType !== '' || $branchName !== '')) {
        $accountNumber = decryptKycField($existing['account_number_enc'] ?? '');
        $confirmAccountNumber = $accountNumber;
    }
    $validated = validateKycBankDetails($accountNumber, $confirmAccountNumber, $ifscCode, $accountType, $branchName);
    if (!$validated['valid']) {
        $_SESSION['flash_error'] = $validated['error'];
        return false;
    }
    if (!$existing) {
        $_SESSION['flash_error'] = 'Amendment bank data is unavailable.';
        return false;
    }
    if (!$validated['has_any']) {
        return true;
    }
    $accountNumber = $validated['account_number'];
    $accountEnc = encryptKycField($accountNumber);
    $accountHmac = generateBlindIndex($accountNumber);
    $stmt = $conn->prepare('UPDATE employee_kyc_bank_amendment_private SET account_number_enc = ?, account_number_hmac = ?, ifsc_code = ?, account_type = ?, branch_name = ?, updated_at = NOW() WHERE amendment_id = ?');
    $amendmentId = (int)$amendmentId;
    $stmt->bind_param('sssssi', $accountEnc, $accountHmac, $validated['ifsc_code'], $validated['account_type'], $validated['branch_name'], $amendmentId);
    if (!$stmt->execute()) {
        $_SESSION['flash_error'] = 'Unable to save amendment bank details.';
        return false;
    }
    auditEvent($conn, 'kyc_bank_amendment_updated', 'employee_kyc_amendments', $amendmentId, ['employee_id' => (int)$employeeId, 'kyc_id' => (int)$amendment['kyc_id']]);
    return true;
}

function validateKycBankStoredData($details) {
    if (!$details || empty($details['account_number_enc']) && empty($details['ifsc_code']) && empty($details['account_type']) && empty($details['branch_name'])) {
        return true;
    }
    return !empty($details['account_number_enc']) && !empty($details['account_number_hmac']) && validateIfscCode($details['ifsc_code'] ?? '') && validateBankAccountType($details['account_type'] ?? '') && normalizeBankBranchName($details['branch_name'] ?? '') !== '' && mb_strlen(normalizeBankBranchName($details['branch_name'] ?? '')) <= 150;
}

function applyKycBankAmendment($conn, $employeeId, $amendmentId, $actorId) {
    $details = getKycBankAmendmentDetails($conn, $amendmentId);
    if (!$details || !validateKycBankStoredData($details)) {
        throw new RuntimeException('Amendment bank details are incomplete or invalid.');
    }
    if (empty($details['account_number_enc']) && empty($details['ifsc_code']) && empty($details['account_type']) && empty($details['branch_name'])) {
        return;
    }
    $accountEnc = $details['account_number_enc'];
    $accountHmac = $details['account_number_hmac'];
    $ifscCode = $details['ifsc_code'];
    $accountType = $details['account_type'];
    $branchName = $details['branch_name'];
    $kycId = (int)$details['kyc_id'];
    $employeeId = (int)$employeeId;
    $actorId = (int)$actorId;
    $stmt = $conn->prepare('INSERT INTO employee_kyc_bank_private (kyc_id, employee_id, account_number_enc, account_number_hmac, ifsc_code, account_type, branch_name, created_by, updated_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE account_number_enc = VALUES(account_number_enc), account_number_hmac = VALUES(account_number_hmac), ifsc_code = VALUES(ifsc_code), account_type = VALUES(account_type), branch_name = VALUES(branch_name), updated_by = VALUES(updated_by), updated_at = NOW()');
    $stmt->bind_param('iisssssii', $kycId, $employeeId, $accountEnc, $accountHmac, $ifscCode, $accountType, $branchName, $actorId, $actorId);
    if (!$stmt->execute()) {
        throw new RuntimeException('Unable to apply amendment bank details.');
    }
    auditEvent($conn, 'kyc_bank_amendment_applied', 'employee_kyc_amendments', $amendmentId, ['employee_id' => $employeeId, 'kyc_id' => $kycId]);
}

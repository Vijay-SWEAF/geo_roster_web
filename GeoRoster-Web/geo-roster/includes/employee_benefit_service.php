<?php

require_once __DIR__ . '/kyc_service.php';

const GROUP_MEDICAL_NOT_SET = null;
const GROUP_MEDICAL_NOT_COVERED = 0;
const GROUP_MEDICAL_COVERED = 1;

function normalizeGroupMedicalCoverage($value) {
    if ($value === null || $value === '' || $value === 'NOT_SET') {
        return null;
    }
    if ($value === 'COVERED' || $value === '1' || $value === 1) {
        return 1;
    }
    if ($value === 'NOT_COVERED' || $value === '0' || $value === 0) {
        return 0;
    }
    return false;
}

function groupMedicalCoverageLabel($value) {
    $value = normalizeGroupMedicalCoverage($value);
    if ($value === 1) {
        return 'Covered';
    }
    if ($value === 0) {
        return 'Not Covered';
    }
    return 'Not Set';
}

function groupMedicalCoverageStatusCode($value) {
    $value = normalizeGroupMedicalCoverage($value);
    if ($value === 1) {
        return 'COVERED';
    }
    if ($value === 0) {
        return 'NOT_COVERED';
    }
    return 'NOT_SET';
}

function canManageEmployeeBenefits($conn, $user = null) {
    if ($user === null) {
        $userId = (int)($_SESSION['user_id'] ?? 0);
        $user = getAuthoritativeUser($conn, $userId);
    }
    return $user && (int)$user['is_active'] === 1 && (
        $user['role_name'] === 'Admin' || hasKycOfficerPermission($conn, (int)$user['user_id'])
    );
}

function requireEmployeeBenefitsAccess($conn, $employeeId) {
    $auth = requireAuthoritativeKycAccess($conn, $employeeId);
    if (!canManageEmployeeBenefits($conn, $auth['user'])) {
        http_response_code(403);
        exit('Employee benefit information is restricted.');
    }
    return $auth;
}

function getEmployeeBenefitStatus($conn, $employeeId) {
    requireEmployeeBenefitsAccess($conn, $employeeId);
    $employeeId = (int)$employeeId;
    $stmt = $conn->prepare('SELECT benefit_status_id, employee_id, group_medical_covered, updated_by, updated_at, created_by, created_at FROM employee_benefit_status WHERE employee_id = ? LIMIT 1');
    $stmt->bind_param('i', $employeeId);
    $stmt->execute();
    return $stmt->get_result()->fetch_assoc() ?: null;
}

function saveGroupMedicalCoverage($conn, $employeeId, $coverage) {
    $auth = requireEmployeeBenefitsAccess($conn, $employeeId);
    $coverage = normalizeGroupMedicalCoverage($coverage);
    if ($coverage === false) {
        $_SESSION['flash_error'] = 'Invalid group medical insurance coverage status.';
        return false;
    }

    $previous = getEmployeeBenefitStatus($conn, $employeeId);
    $previousCode = groupMedicalCoverageStatusCode($previous['group_medical_covered'] ?? null);
    $newCode = groupMedicalCoverageStatusCode($coverage);
    $actorId = (int)$auth['user']['user_id'];
    $employeeId = (int)$employeeId;
    if ($coverage === null) {
        $stmt = $conn->prepare('INSERT INTO employee_benefit_status (employee_id, group_medical_covered, created_by, updated_by) VALUES (?, NULL, ?, ?) ON DUPLICATE KEY UPDATE group_medical_covered = NULL, updated_by = VALUES(updated_by), updated_at = NOW()');
        $stmt->bind_param('iii', $employeeId, $actorId, $actorId);
    } else {
        $stmt = $conn->prepare('INSERT INTO employee_benefit_status (employee_id, group_medical_covered, created_by, updated_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE group_medical_covered = VALUES(group_medical_covered), updated_by = VALUES(updated_by), updated_at = NOW()');
        $stmt->bind_param('iiii', $employeeId, $coverage, $actorId, $actorId);
    }
    if (!$stmt->execute()) {
        $_SESSION['flash_error'] = 'Unable to save employee benefit status.';
        return false;
    }

    auditEvent($conn, 'group_medical_coverage_updated', 'employee_benefit_status', $employeeId, [
        'employee_id' => $employeeId,
        'previous_status' => $previousCode,
        'new_status' => $newCode
    ]);
    return true;
}

function getBenefitReportBranches($conn) {
    $result = $conn->query('SELECT branch_id, branch_name FROM branches ORDER BY branch_name');
    $branches = [];
    while ($result && ($row = $result->fetch_assoc())) {
        $branches[] = $row;
    }
    return $branches;
}

function getGroupMedicalCoverageReport($conn, $filters = []) {
    $userId = (int)($_SESSION['user_id'] ?? 0);
    $user = getAuthoritativeUser($conn, $userId);
    if (!canManageEmployeeBenefits($conn, $user)) {
        http_response_code(403);
        exit('Employee benefit information is restricted.');
    }

    $branchId = isset($filters['branch_id']) && $filters['branch_id'] !== '' ? (int)$filters['branch_id'] : null;
    $coverage = $filters['coverage'] ?? 'ALL';
    $active = $filters['active'] ?? 'ACTIVE';
    $allowedCoverage = ['ALL', 'COVERED', 'NOT_COVERED', 'NOT_SET'];
    $allowedActive = ['ACTIVE', 'INACTIVE', 'ALL'];
    if (!in_array($coverage, $allowedCoverage, true)) {
        $coverage = 'ALL';
    }
    if (!in_array($active, $allowedActive, true)) {
        $active = 'ACTIVE';
    }

    $params = [];
    $types = '';
    $where = [];
    if ($user['role_name'] === 'Branch User' || ($user['role_name'] !== 'Admin' && $user['branch_id'] !== null && (int)$user['branch_id'] > 0)) {
        $branchId = (int)$user['branch_id'];
    }
    if ($branchId !== null && $branchId > 0) {
        $where[] = 'e.branch_id = ?';
        $params[] = $branchId;
        $types .= 'i';
    }
    if ($active === 'ACTIVE') {
        $where[] = 'e.is_active = 1';
    } elseif ($active === 'INACTIVE') {
        $where[] = 'e.is_active = 0';
    }
    if ($coverage === 'COVERED') {
        $where[] = 'bs.group_medical_covered = 1';
    } elseif ($coverage === 'NOT_COVERED') {
        $where[] = 'bs.group_medical_covered = 0';
    } elseif ($coverage === 'NOT_SET') {
        $where[] = 'bs.employee_id IS NULL';
    }

    $sql = 'SELECT e.employee_id, e.employee_no, e.employee_name, b.branch_name, bl.location_name AS sub_location, e.designation, e.employee_category, e.is_active, bs.group_medical_covered, bs.updated_at FROM employees e LEFT JOIN branches b ON b.branch_id = e.branch_id LEFT JOIN branch_locations bl ON bl.location_id = e.location_id LEFT JOIN employee_benefit_status bs ON bs.employee_id = e.employee_id';
    if ($where) {
        $sql .= ' WHERE ' . implode(' AND ', $where);
    }
    $sql .= ' ORDER BY b.branch_name, e.employee_no';
    $stmt = $conn->prepare($sql);
    if ($types !== '') {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();
    $rows = [];
    $counts = ['total' => 0, 'covered' => 0, 'not_covered' => 0, 'not_set' => 0];
    while ($row = $result->fetch_assoc()) {
        $row['coverage_label'] = groupMedicalCoverageLabel($row['group_medical_covered']);
        $rows[] = $row;
        $counts['total']++;
        if ($row['group_medical_covered'] === null) {
            $counts['not_set']++;
        } elseif ((int)$row['group_medical_covered'] === 1) {
            $counts['covered']++;
        } else {
            $counts['not_covered']++;
        }
    }
    return ['rows' => $rows, 'counts' => $counts, 'filters' => ['branch_id' => $branchId, 'coverage' => $coverage, 'active' => $active], 'user' => $user];
}

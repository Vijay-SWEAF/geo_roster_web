<?php

set_exception_handler(function (Throwable $exception) {
    error_log('Unhandled GeoRoster exception: ' . $exception->getMessage());
    if (!headers_sent()) {
        http_response_code(500);
    }
    exit('An unexpected error occurred.');
});

function startSecureSession() {
    if (session_status() === PHP_SESSION_ACTIVE) {
        return;
    }

    $secure = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';
    session_set_cookie_params([
        'lifetime' => 0,
        'path' => '/',
        'secure' => $secure,
        'httponly' => true,
        'samesite' => 'Lax'
    ]);
    session_start();

    $now = time();
    if (!empty($_SESSION['last_activity']) && $now - $_SESSION['last_activity'] > 1800) {
        $_SESSION = [];
        session_destroy();
        header('Location: /geo-roster/auth/login.php');
        exit;
    }
    if (!empty($_SESSION['session_started']) && $now - $_SESSION['session_started'] > 28800) {
        $_SESSION = [];
        session_destroy();
        header('Location: /geo-roster/auth/login.php');
        exit;
    }
    $_SESSION['last_activity'] = $now;
    $_SESSION['session_started'] = $_SESSION['session_started'] ?? $now;
}

function applySecurityHeaders() {
    if (headers_sent()) {
        return;
    }

    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: SAMEORIGIN');
    header('Referrer-Policy: strict-origin-when-cross-origin');
    header('Permissions-Policy: camera=(), microphone=(), geolocation=()');
}

function csrfToken() {
    startSecureSession();
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function csrfField() {
    return '<input type="hidden" name="csrf_token" value="' .
        htmlspecialchars(csrfToken(), ENT_QUOTES, 'UTF-8') . '">';
}

function requireCsrf() {
    startSecureSession();
    $submitted = $_POST['csrf_token'] ?? '';
    if (!is_string($submitted) || $submitted === '' ||
        empty($_SESSION['csrf_token']) ||
        !hash_equals($_SESSION['csrf_token'], $submitted)) {
        http_response_code(403);
        exit('Invalid request token.');
    }
}

function requirePostWithCsrf() {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        header('Allow: POST');
        exit('Method not allowed.');
    }
    requireCsrf();
}

function requireRole(array $roles) {
    $role = $_SESSION['role'] ?? '';
    if (!in_array($role, $roles, true)) {
        $_SESSION['flash_error'] = 'Access denied.';
        header('Location: ' . (strpos($_SERVER['PHP_SELF'] ?? '', '/admin/') !== false ? '../dashboard.php' : 'dashboard.php'));
        exit;
    }
}

function currentUserBranchId($conn) {
    $userId = (int)($_SESSION['user_id'] ?? 0);
    $stmt = $conn->prepare('SELECT branch_id FROM users WHERE user_id = ? LIMIT 1');
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    return isset($row['branch_id']) ? (int)$row['branch_id'] : 0;
}

function requireBranchAccess($conn, $branchId) {
    $branchId = filter_var($branchId, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
    if (!$branchId) {
        http_response_code(400);
        exit('Invalid branch.');
    }

    if (($_SESSION['role'] ?? '') === 'Branch User' && $branchId !== currentUserBranchId($conn)) {
        http_response_code(403);
        exit('Access denied.');
    }
    return $branchId;
}

function employeeForScope($conn, $employeeId) {
    $stmt = $conn->prepare('SELECT employee_id, branch_id, location_id, is_active FROM employees WHERE employee_id = ? LIMIT 1');
    $stmt->bind_param('i', $employeeId);
    $stmt->execute();
    return $stmt->get_result()->fetch_assoc() ?: null;
}

function requireEmployeeAccess($conn, $employeeId) {
    $employee = employeeForScope($conn, $employeeId);
    if (!$employee) {
        http_response_code(404);
        exit('Employee not found.');
    }
    requireBranchAccess($conn, (int)$employee['branch_id']);
    return $employee;
}

function validPositiveInt($value) {
    $value = filter_var($value, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
    return $value === false ? null : $value;
}

function validDateValue($value) {
    if (!is_string($value) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $value)) {
        return null;
    }
    $date = DateTime::createFromFormat('!Y-m-d', $value);
    return $date && $date->format('Y-m-d') === $value ? $value : null;
}

function validMonthValue($value) {
    if (!is_string($value) || !preg_match('/^\d{4}-\d{2}$/', $value)) {
        return null;
    }
    $date = DateTime::createFromFormat('!Y-m-d', $value . '-01');
    return $date ? $value : null;
}

function auditEvent($conn, $action, $entityType = '', $entityId = null, array $metadata = []) {
    try {
        $stmt = $conn->prepare('INSERT INTO security_audit_log (actor_user_id, action, entity_type, entity_id, metadata, created_at) VALUES (?, ?, ?, ?, ?, NOW())');
    } catch (Throwable $exception) {
        error_log('Audit log preparation failed: ' . $exception->getMessage());
        return;
    }
    if (!$stmt) {
        error_log('Audit log preparation failed: ' . $conn->error);
        return;
    }
    $actor = (int)($_SESSION['user_id'] ?? 0);
    $encoded = json_encode($metadata, JSON_UNESCAPED_SLASHES);
    $stmt->bind_param('issis', $actor, $action, $entityType, $entityId, $encoded);
    if (!$stmt->execute()) {
        error_log('Audit log write failed: ' . $stmt->error);
    }
}

function exportSafeText($value) {
    $value = (string)$value;
    if ($value !== '' && in_array($value[0], ['=', '+', '-', '@'], true)) {
        return "'" . $value;
    }
    return $value;
}

function preparedResult($conn, $sql, $types = '', array $params = []) {
    $stmt = $conn->prepare($sql);
    if ($types !== '') {
        $references = [$types];
        foreach ($params as $key => $value) {
            $references[] = &$params[$key];
        }
        call_user_func_array([$stmt, 'bind_param'], $references);
    }
    $stmt->execute();
    return $stmt->get_result();
}
<?php
require_once __DIR__ . '/security.php';

function getBranchName($conn, $branch_id) {
    $branch_id = (int)$branch_id;

    $stmt = $conn->prepare("SELECT branch_name FROM branches WHERE branch_id = ? LIMIT 1");
    $stmt->bind_param("i", $branch_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result && $result->num_rows > 0) {
        $row = $result->fetch_assoc();
        return $row['branch_name'] ?? '';
    }

    return '';
}

function getLeaveTypes($conn) {
    $data = [];

    $result = $conn->query("
        SELECT leave_type_id, leave_code, leave_name
        FROM leave_types
        WHERE is_active = 1
        ORDER BY leave_code
    ");

    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $data[] = $row;
        }
    }

    return $data;
}

function getEmployeesByBranch($conn, $branch_id, $category = '') {
    $data = [];
    $branch_id = (int)$branch_id;
    $sql = "
        SELECT 
            e.employee_id,
            e.employee_no,
            e.employee_name,
            e.employee_category,
            e.branch_id,
            e.designation,
            b.branch_name
        FROM employees e
        LEFT JOIN branches b ON e.branch_id = b.branch_id
        WHERE e.branch_id = ?
        " . (($category === 'Staff' || $category === 'Labour') ? " AND e.employee_category = ?" : "") . "
        ORDER BY 
            CASE 
                WHEN e.employee_category = 'Staff' THEN 1
                WHEN e.employee_category = 'Labour' THEN 2
                ELSE 3
            END,
            e.employee_name
    ";

    $result = ($category === 'Staff' || $category === 'Labour')
        ? preparedResult($conn, $sql, 'is', [$branch_id, $category])
        : preparedResult($conn, $sql, 'i', [$branch_id]);

    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $data[] = $row;
        }
    }

    return $data;
}
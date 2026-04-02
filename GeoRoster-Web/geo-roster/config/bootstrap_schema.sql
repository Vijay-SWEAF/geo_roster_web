-- GeoRoster local bootstrap schema
-- Safe to run multiple times.

CREATE DATABASE IF NOT EXISTS attendance_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE attendance_db;

CREATE TABLE IF NOT EXISTS branches (
  branch_id INT AUTO_INCREMENT PRIMARY KEY,
  branch_code VARCHAR(20) NOT NULL,
  branch_name VARCHAR(120) NOT NULL,
  location_city VARCHAR(120) DEFAULT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_branches_code (branch_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS branch_locations (
  location_id INT AUTO_INCREMENT PRIMARY KEY,
  branch_id INT NOT NULL,
  location_name VARCHAR(150) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  is_ot_enabled TINYINT(1) NOT NULL DEFAULT 1,
  is_expense_enabled TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_branch_location_name (branch_id, location_name),
  KEY idx_branch_locations_branch (branch_id),
  CONSTRAINT fk_branch_locations_branch
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS users (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(150) NOT NULL,
  username VARCHAR(80) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role_name VARCHAR(40) NOT NULL,
  branch_id INT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_users_username (username),
  KEY idx_users_branch (branch_id),
  CONSTRAINT fk_users_branch
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS employees (
  employee_id INT AUTO_INCREMENT PRIMARY KEY,
  employee_no VARCHAR(50) NOT NULL,
  employee_name VARCHAR(150) NOT NULL,
  branch_id INT NOT NULL,
  location_id INT NULL,
  designation VARCHAR(120) DEFAULT NULL,
  employee_category VARCHAR(20) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_employee_no (employee_no),
  KEY idx_employees_branch (branch_id),
  KEY idx_employees_location (location_id),
  CONSTRAINT fk_employees_branch
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_employees_location
    FOREIGN KEY (location_id) REFERENCES branch_locations(location_id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS leave_types (
  leave_type_id INT AUTO_INCREMENT PRIMARY KEY,
  leave_code VARCHAR(10) NOT NULL,
  leave_name VARCHAR(100) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_leave_type_code (leave_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS leave_policy (
  policy_id INT AUTO_INCREMENT PRIMARY KEY,
  policy_year INT NOT NULL,
  employee_category VARCHAR(20) NOT NULL,
  leave_type_id INT NOT NULL,
  entitled_days DECIMAL(6,2) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_leave_policy (policy_year, employee_category, leave_type_id),
  KEY idx_leave_policy_type (leave_type_id),
  CONSTRAINT fk_leave_policy_type
    FOREIGN KEY (leave_type_id) REFERENCES leave_types(leave_type_id)
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS leave_entries (
  leave_id INT AUTO_INCREMENT PRIMARY KEY,
  employee_category VARCHAR(20) NOT NULL,
  leave_type_id INT NOT NULL,
  from_date DATE NOT NULL,
  to_date DATE NOT NULL,
  remarks VARCHAR(255) DEFAULT NULL,
  entered_by INT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_leave_entries_type (leave_type_id),
  KEY idx_leave_entries_entered_by (entered_by),
  CONSTRAINT fk_leave_entries_type
    FOREIGN KEY (leave_type_id) REFERENCES leave_types(leave_type_id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_leave_entries_user
    FOREIGN KEY (entered_by) REFERENCES users(user_id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS attendance_entries (
  attendance_id INT AUTO_INCREMENT PRIMARY KEY,
  attendance_date DATE NOT NULL,
  branch_id INT NOT NULL,
  location_id INT NULL,
  employee_id INT NOT NULL,
  status_code VARCHAR(5) NOT NULL,
  leave_type_id INT NULL,
  ot_hours DECIMAL(6,2) NOT NULL DEFAULT 0,
  other_expense DECIMAL(10,2) NOT NULL DEFAULT 0,
  remarks VARCHAR(255) DEFAULT NULL,
  entered_by INT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_attendance_employee_date (employee_id, attendance_date),
  KEY idx_attendance_date (attendance_date),
  KEY idx_attendance_branch (branch_id),
  KEY idx_attendance_location (location_id),
  KEY idx_attendance_leave_type (leave_type_id),
  KEY idx_attendance_entered_by (entered_by),
  CONSTRAINT fk_attendance_branch
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_attendance_location
    FOREIGN KEY (location_id) REFERENCES branch_locations(location_id)
    ON DELETE SET NULL,
  CONSTRAINT fk_attendance_employee
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
    ON DELETE RESTRICT,
  CONSTRAINT fk_attendance_leave_type
    FOREIGN KEY (leave_type_id) REFERENCES leave_types(leave_type_id)
    ON DELETE SET NULL,
  CONSTRAINT fk_attendance_user
    FOREIGN KEY (entered_by) REFERENCES users(user_id)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO branches (branch_code, branch_name, location_city)
VALUES ('HO', 'Head Office', 'Main City')
ON DUPLICATE KEY UPDATE branch_name = VALUES(branch_name), location_city = VALUES(location_city);

INSERT INTO leave_types (leave_code, leave_name, is_active)
VALUES
  ('CL', 'Casual Leave', 1),
  ('SL', 'Sick Leave', 1),
  ('EL', 'Earned Leave', 1),
  ('WO', 'Weekly Off', 1)
ON DUPLICATE KEY UPDATE leave_name = VALUES(leave_name), is_active = VALUES(is_active);

INSERT INTO users (full_name, username, password_hash, role_name, branch_id, is_active)
SELECT 'System Admin', 'admin', '$2y$12$UX01GO9ZEsXpVPcBhAYxy.Bn/7zJGO/tHcj2OvHyqL7y7K5GovGou', 'Admin', NULL, 1
WHERE NOT EXISTS (
  SELECT 1 FROM users WHERE username = 'admin'
);

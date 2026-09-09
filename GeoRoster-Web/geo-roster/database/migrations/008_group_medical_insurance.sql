-- GeoRoster Prompt 03H: group medical insurance enrollment status.
-- Additive only. This records coverage status, not medical or health information.

CREATE TABLE IF NOT EXISTS employee_benefit_status (
    benefit_status_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    group_medical_covered TINYINT(1) NULL DEFAULT NULL,
    updated_by INT NOT NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_employee_benefit_status_employee (employee_id),
    CONSTRAINT chk_group_medical_covered CHECK (group_medical_covered IS NULL OR group_medical_covered IN (0, 1)),
    CONSTRAINT fk_employee_benefit_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE RESTRICT,
    CONSTRAINT fk_employee_benefit_created_by FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE RESTRICT,
    CONSTRAINT fk_employee_benefit_updated_by FOREIGN KEY (updated_by) REFERENCES users(user_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

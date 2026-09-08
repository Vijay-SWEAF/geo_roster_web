-- GeoRoster production migration 005.
-- MANUAL EXECUTION ONLY after migrations 001-004 verification and owner approval.
-- Additive KYC permission table; no existing rows or role_name values are modified.

CREATE TABLE IF NOT EXISTS user_kyc_permissions (
    permission_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    permission_code VARCHAR(50) NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    granted_by INT NOT NULL,
    granted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by INT NOT NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_user_kyc_permission (user_id, permission_code),
    KEY idx_user_kyc_permission_active (user_id, permission_code, is_active),
    CONSTRAINT fk_user_kyc_permission_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_user_kyc_permission_granted_by FOREIGN KEY (granted_by) REFERENCES users(user_id) ON DELETE RESTRICT,
    CONSTRAINT fk_user_kyc_permission_updated_by FOREIGN KEY (updated_by) REFERENCES users(user_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

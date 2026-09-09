-- GeoRoster Prompt 03G: secure employee KYC bank details.
-- Additive only; bank account numbers are encrypted and never stored plaintext.

CREATE TABLE IF NOT EXISTS employee_kyc_bank_private (
    bank_detail_id INT AUTO_INCREMENT PRIMARY KEY,
    kyc_id INT NOT NULL,
    employee_id INT NOT NULL,
    account_number_enc VARCHAR(255) NOT NULL,
    account_number_hmac CHAR(64) NOT NULL,
    ifsc_code CHAR(11) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    branch_name VARCHAR(150) NOT NULL,
    created_by INT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by INT NOT NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_kyc_bank_kyc (kyc_id),
    UNIQUE KEY uq_kyc_bank_employee (employee_id),
    KEY idx_kyc_bank_account_hmac (account_number_hmac),
    CONSTRAINT chk_kyc_bank_account_type CHECK (account_type IN ('SAVINGS', 'CURRENT', 'SALARY', 'OTHER')),
    CONSTRAINT fk_kyc_bank_kyc FOREIGN KEY (kyc_id) REFERENCES employee_kyc(kyc_id) ON DELETE RESTRICT,
    CONSTRAINT fk_kyc_bank_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE RESTRICT,
    CONSTRAINT fk_kyc_bank_created_by FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE RESTRICT,
    CONSTRAINT fk_kyc_bank_updated_by FOREIGN KEY (updated_by) REFERENCES users(user_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS employee_kyc_bank_amendment_private (
    bank_amendment_private_id INT AUTO_INCREMENT PRIMARY KEY,
    amendment_id INT NOT NULL,
    kyc_id INT NOT NULL,
    employee_id INT NOT NULL,
    account_number_enc VARCHAR(255) DEFAULT NULL,
    account_number_hmac CHAR(64) DEFAULT NULL,
    ifsc_code CHAR(11) DEFAULT NULL,
    account_type VARCHAR(20) DEFAULT NULL,
    branch_name VARCHAR(150) DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_kyc_bank_amendment (amendment_id),
    CONSTRAINT chk_kyc_bank_amendment_account_type CHECK (account_type IS NULL OR account_type IN ('SAVINGS', 'CURRENT', 'SALARY', 'OTHER')),
    CONSTRAINT fk_kyc_bank_amendment FOREIGN KEY (amendment_id) REFERENCES employee_kyc_amendments(amendment_id) ON DELETE RESTRICT,
    CONSTRAINT fk_kyc_bank_amendment_kyc FOREIGN KEY (kyc_id) REFERENCES employee_kyc(kyc_id) ON DELETE RESTRICT,
    CONSTRAINT fk_kyc_bank_amendment_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

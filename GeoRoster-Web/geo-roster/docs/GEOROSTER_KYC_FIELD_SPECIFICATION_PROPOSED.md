# GeoRoster Proposed Employee KYC Field Specification

> **Document Version:** 1.0  
> **Status:** PROPOSED — PENDING PRODUCT OWNER APPROVAL  
> **Phase:** Prompt 03B-A — Requirements & Product Owner Decision Gate  
> **Target Migration:** `database/migrations/003_employee_kyc_fields.sql` (Deferred to Prompt 03B)  

---

## 1. Overview & Field Architecture

This specification details the technical attributes, validation rules, storage types, encryption parameters, and role-based permissions for all current and proposed employee KYC fields in GeoRoster.

To maintain architectural cleanliness:
1. **Existing Master Fields** (`employees` table) remain `APPROVED` and authoritative.
2. **Proposed KYC Fields** (`employee_kyc_private` table) remain `PROPOSED` until formal product owner sign-off.
3. **No Database Migration 003 or Sensitive Input Forms** are created in Prompt 03B-A.

---

## 2. Master Data Integration (Read-Only Context in KYC)

The following fields are owned by **Employee Master** (`employees`) and displayed in read-only context on KYC screens.

| Internal Field Key | Display Label | Source Table & Column | SQL Type | Sensitivity | Admin Access | HO Access | Branch Access | Status |
|---|---|---|---|---|---|---|---|---|
| `employee_id` | Internal ID | `employees.employee_id` | `INT PK` | Low | Full | Full | Scoped | `APPROVED` |
| `employee_no` | Employee No | `employees.employee_no` | `VARCHAR(50)` | Low | Full | Full | Scoped | `APPROVED` |
| `employee_name` | Employee Name | `employees.employee_name` | `VARCHAR(150)` | Low | Full | Full | Scoped | `APPROVED` |
| `branch_id` | Branch | `employees.branch_id` | `INT FK` | Low | Full | Full | Scoped | `APPROVED` |
| `location_id` | Sub-Location | `employees.location_id` | `INT FK` | Low | Full | Full | Scoped | `APPROVED` |
| `designation` | Designation | `employees.designation` | `VARCHAR(120)` | Low | Full | Full | Scoped | `APPROVED` |
| `employee_category` | Category | `employees.employee_category` | `VARCHAR(20)` | Low | Full | Full | Scoped | `APPROVED` |
| `is_active` | Active Status | `employees.is_active` | `TINYINT(1)` | Low | Full | Full | Scoped | `APPROVED` |

---

## 3. Comprehensive Proposed Field Specification Matrix

The table below specifies all proposed candidate fields for future table `employee_kyc_private`:

| Field Key | Display Label | Proposed SQL Type | Nullable? | Draft Req? | Submit Req? | Normalization Rule | Validation Pattern / Regex | Sensitivity | Encryption | Masking Rule | Duplicate Index? | Admin Access | HO Access | Branch Access | Audit Log? | Export Allowed? | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `date_of_birth` | Date of Birth | `DATE` | YES | Optional | Staff: YES, Labour: YES | Format `YYYY-MM-DD` | Age >= 18 years | Medium | None | `DD/MM/XXXX` | No | Full | Full | Masked | YES | NO | `PROPOSED` |
| `gender` | Gender | `VARCHAR(10)` | YES | Optional | Optional | Trim, Capitalize | `^(Male\|Female\|Other)$` | Low | None | None | No | Full | Full | Full | YES | NO | `PROPOSED` |
| `mobile_number` | Mobile Number | `VARCHAR(15)` | YES | Optional | Staff: YES, Labour: YES | Strip spaces/dashes | `^[6-9]\d{9}$` | Medium | None | `XXXXXX1234` | Blind Index | Full | Full | Masked | YES | NO | `PROPOSED` |
| `alt_mobile_number` | Alt Mobile No | `VARCHAR(15)` | YES | Optional | Optional | Strip spaces/dashes | `^[6-9]\d{9}$` | Low | None | `XXXXXX1234` | No | Full | Full | Masked | YES | NO | `PROPOSED` |
| `email_address` | Email Address | `VARCHAR(150)` | YES | Optional | Staff: YES, Labour: NO | Trim, Lowercase | Valid Email (`filter_var`) | Low | None | `u***r@domain.com` | No | Full | Full | Full | YES | NO | `PROPOSED` |
| `current_address` | Current Address | `VARCHAR(500)` | YES | Optional | Staff: YES, Labour: YES | Trim, Clean spaces | Min 10 chars, Max 500 | Medium | None | Mask street address | No | Full | Full | Full | YES | NO | `PROPOSED` |
| `permanent_address` | Permanent Address | `VARCHAR(500)` | YES | Optional | Staff: YES, Labour: YES | Trim, Clean spaces | Min 10 chars, Max 500 | Medium | None | Mask street address | No | Full | Full | Full | YES | NO | `PROPOSED` |
| `pan_number_enc` | PAN Number | `VARCHAR(255)` | YES | Optional | Staff: YES, Labour: Cond. | Trim, Uppercase | `^[A-Z]{5}[0-9]{4}[A-Z]{1}$` | High | **AES-256/Sodium** | `XXXXX1234X` | Blind Index (`pan_hmac`) | Full | Full | Masked | YES | NO | `PROPOSED` |
| `aadhaar_number_enc` | Aadhaar Number | `VARCHAR(255)` | YES | Optional | Staff: YES, Labour: Opt. | Strip non-digits | `^\d{12}$` + Verhoeff Check | **Critical** | **AES-256/Sodium** | `XXXX XXXX 1234` | Blind Index (`aadhaar_hmac`) | Full (Reveal Logged) | Full (Reveal Logged) | Masked Only | YES | NO | `PROPOSED` |
| `uan_number` | UAN (EPF) | `VARCHAR(20)` | YES | Optional | Conditional (PF) | Strip non-digits | `^\d{12}$` | High | None | `XXXX XXXX 1234` | Blind Index (`uan_hmac`) | Full | Full | Masked | YES | NO | `PROPOSED` |
| `esic_number` | ESIC IP Number | `VARCHAR(25)` | YES | Optional | Conditional (ESIC) | Strip non-digits | `^\d{17}$` | Medium | None | `XXXX XXXX 1234` | No | Full | Full | Masked | YES | NO | `PROPOSED` |
| `bank_name` | Bank Name | `VARCHAR(100)` | YES | Optional | Conditional (Salary) | Trim, Title Case | Min 3 chars | Low | None | None | No | Full | Full | Full | YES | NO | `PROPOSED` |
| `bank_account_holder` | Account Holder Name | `VARCHAR(150)` | YES | Optional | Conditional (Salary) | Trim, Title Case | Min 3 chars | Medium | None | None | No | Full | Full | Full | YES | NO | `PROPOSED` |
| `bank_account_no_enc` | Bank Account No | `VARCHAR(255)` | YES | Optional | Conditional (Salary) | Strip non-alphanumeric | `^[A-Za-z0-9]{9,18}$` | High | **AES-256/Sodium** | `XXXXXX1234` | Blind Index (`bank_ac_hmac`) | Full (Reveal Logged) | Full (Reveal Logged) | Masked Only | YES | NO | `PROPOSED` |
| `bank_ifsc_code` | Bank IFSC Code | `VARCHAR(15)` | YES | Optional | Conditional (Salary) | Trim, Uppercase | `^[A-Z]{4}0[A-Z0-9]{6}$` | Low | None | None | No | Full | Full | Full | YES | NO | `PROPOSED` |

---

## 4. Normalization and Format Validation Rules

When proposed fields are implemented in Prompt 03B, server-side normalization and validation will execute in `includes/kyc_service.php` prior to encrypted storage:

1. **Date of Birth (`date_of_birth`):**
   - Normalization: Extracted as `YYYY-MM-DD`.
   - Validation: Must be a valid calendar date and candidate age must be $\ge 18$ years on the date of entry.

2. **PAN Number (`pan_number_enc`):**
   - Normalization: Stripped of whitespace and converted to uppercase (e.g. `abcde1234f` $\rightarrow$ `ABCDE1234F`).
   - Validation: Must strictly match `^[A-Z]{5}[0-9]{4}[A-Z]{1}$`.

3. **Aadhaar Number (`aadhaar_number_enc`):**
   - Normalization: All spaces, dashes, and non-digit characters stripped (e.g. `1234-5678-9012` $\rightarrow$ `123456789012`).
   - Validation: Must be exactly 12 numeric digits and pass the **Verhoeff Checksum Algorithm**.

4. **Bank Account Number (`bank_account_no_enc`):**
   - Normalization: Stripped of spaces and special characters.
   - Validation: Must be 9 to 18 alphanumeric characters (`^[A-Za-z0-9]{9,18}$`).

5. **IFSC Code (`bank_ifsc_code`):**
   - Normalization: Converted to uppercase.
   - Validation: Must match 11-character Indian Financial System Code format (`^[A-Z]{4}0[A-Z0-9]{6}$`).

---

## 5. Security & Encryption Specification

1. **Authenticated Encryption:**
   - High-sensitivity fields (`pan_number_enc`, `aadhaar_number_enc`, `bank_account_no_enc`) are encrypted using `encryptKycField()`.
   - Payload format: `v1:sodium:<nonce+ciphertext>` or `v1:gcm:<iv+tag+ciphertext>`.

2. **Key Management:**
   - Key loaded via `GEOROSTER_KYC_ENCRYPTION_KEY` environment variable or `../georoster-config/kyc_key.php`.
   - Keys are **NEVER** stored in database tables or committed to version control.

3. **Blind Indexing for Duplicate Prevention:**
   - Exact duplicate checks for encrypted fields utilize `generateBlindIndex($value, $hmacKey)`.
   - Stored in separate indexed columns (`pan_hmac`, `aadhaar_hmac`, `bank_ac_hmac`).

---

## 6. Submission Validation Function Spec (`validateKycForSubmission`)

The proposed submission validator function signature for Prompt 03B:

```php
/**
 * Validates complete KYC profile prior to state transition from DRAFT to SUBMITTED.
 * Returns array of missing/invalid field error messages, or empty array if valid.
 */
function validateKycForSubmission($conn, $employeeId) {
    $errors = [];
    $employee = getEmployeeDetails($conn, $employeeId);
    $category = $employee['employee_category']; // 'Staff' or 'Labour'
    $kycData = getKycPrivateData($conn, $employeeId);

    // Common Requirements for all employees
    if (empty($kycData['date_of_birth'])) {
        $errors[] = "Date of Birth is required for submission.";
    }
    if (empty($kycData['mobile_number']) || !preg_match('/^[6-9]\d{9}$/', $kycData['mobile_number'])) {
        $errors[] = "Valid 10-digit Mobile Number is required for submission.";
    }
    if (empty($kycData['current_address']) || strlen($kycData['current_address']) < 10) {
        $errors[] = "Complete Current Address is required for submission.";
    }

    // Category Specific Requirements: Staff
    if ($category === 'Staff') {
        if (empty($kycData['pan_number_enc'])) {
            $errors[] = "PAN Number is mandatory for Staff category.";
        }
        if (empty($kycData['aadhaar_number_enc'])) {
            $errors[] = "Aadhaar Number is mandatory for Staff category.";
        }
    }

    // Banking Details (If Salary Direct Deposit enabled)
    if (!empty($kycData['bank_account_no_enc']) && empty($kycData['bank_ifsc_code'])) {
        $errors[] = "Bank IFSC Code is required when Bank Account Number is provided.";
    }

    return $errors;
}
```

---

## 7. Export and Search Isolation Rules

- **Attendance / Payroll / Leave Exports:**
  `export_monthly_register.php`, `export_payroll.php`, and `export_leave_balance.php` MUST remain 100% isolated from `employee_kyc_private`. No statutory or banking field will be joined or exported.
- **Search Isolation:**
  Searches on `admin/employees.php` or `kyc/employee_kyc.php` MUST NOT search against encrypted or masked PAN/Aadhaar/Bank fields.

---

*Document prepared for GeoRoster Prompt 03B-A Specification Gate.*

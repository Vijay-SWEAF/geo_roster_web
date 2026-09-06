# GeoRoster Approved Employee KYC Field Specification

> **Document Version:** 2.0 (Frozen for Prompt 03B-B Implementation)  
> **Status:** APPROVED & FROZEN BY PRODUCT OWNER  
> **Phase:** Prompt 03B-B — Approved Employee KYC Fields & Secure Data Entry  
> **Migration:** `database/migrations/003_employee_kyc_fields.sql`  

---

## 1. Overview & Approved Field Architecture

This specification defines the approved technical attributes, validation rules, storage types, encryption parameters, and role-based permissions for all MVP employee KYC fields implemented in Prompt 03B-B.

- **Master Data Fields** (`employees` table): Approved and read-only on KYC screens.
- **Approved Structured Fields** (`employee_kyc_private` table): Implemented in Migration 003.
- **Deferred Fields** (Gender, Email, Alternate Mobile, Banking, Emergency, Nominees, Documents): Strictly **DEFERRED** and excluded from schema, code, and UI.

---

## 2. Master Data Integration (Read-Only Context in KYC)

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

## 3. Comprehensive Approved Field Specification Matrix

The table below specifies all approved fields in table `employee_kyc_private`:

| Field Key | Display Label | Proposed SQL Type | Nullable? | Draft Req? | Submit Req? | Normalization Rule | Validation Pattern / Regex | Sensitivity | Encryption | Masking Rule | Duplicate Index? | Admin Access | HO Access | Branch Access | Audit Log? | Export Allowed? | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `date_of_birth` | Date of Birth | `DATE` | YES | Optional | YES | Format `YYYY-MM-DD` | Valid Date (Not Future) | Medium | None | `DD/MM/XXXX` | No | Full | Full | Full | YES | NO | `APPROVED` |
| `mobile_number` | Mobile Number | `VARCHAR(15)` | YES | Optional | YES | Strip spaces/dashes | `^[6-9]\d{9}$` | Medium | None | `XXXXXX1234` | No | Full | Full | Full | YES | NO | `APPROVED` |
| `current_address` | Current Address | `VARCHAR(500)` | YES | Optional | YES | Trim, Clean spaces | Non-empty | Medium | None | Mask street address | No | Full | Full | Full | YES | NO | `APPROVED` |
| `permanent_address` | Permanent Address | `VARCHAR(500)` | YES | Optional | YES | Trim, Clean spaces | Non-empty | Medium | None | Mask street address | No | Full | Full | Full | YES | NO | `APPROVED` |
| `same_as_current` | Same Address? | `TINYINT(1)` | NO | Optional | Optional | Boolean 0/1 | `^[01]$` | Low | None | None | No | Full | Full | Full | YES | NO | `APPROVED` |
| `pan_applicable` | PAN Applicable | `TINYINT(1)` | NO | Optional | Optional | Boolean 0/1 | `^[01]$` | Low | None | None | No | Full | Full | View Only | YES | NO | `APPROVED` |
| `aadhaar_applicable` | Aadhaar App. | `TINYINT(1)` | NO | Optional | Optional | Boolean 0/1 | `^[01]$` | Low | None | None | No | Full | Full | View Only | YES | NO | `APPROVED` |
| `uan_applicable` | UAN Applicable | `TINYINT(1)` | NO | Optional | Optional | Boolean 0/1 | `^[01]$` | Low | None | None | No | Full | Full | View Only | YES | NO | `APPROVED` |
| `esic_applicable` | ESIC Applicable | `TINYINT(1)` | NO | Optional | Optional | Boolean 0/1 | `^[01]$` | Low | None | None | No | Full | Full | View Only | YES | NO | `APPROVED` |
| `pan_number_enc` | PAN Number | `VARCHAR(255)` | YES | Optional | Conditional | Trim, Uppercase | `^[A-Z]{5}[0-9]{4}[A-Z]{1}$` | High | **AES-256/Sodium** | `XXXXX1234X` | Blind Index (`pan_hmac`) | Full (Reveal Logged) | Full (Reveal Logged) | Masked Only | YES | NO | `APPROVED` |
| `aadhaar_number_enc` | Aadhaar Number | `VARCHAR(255)` | YES | Optional | Conditional | Strip non-digits | `^\d{12}$` + Verhoeff Check | **Critical** | **AES-256/Sodium** | `XXXX XXXX 1234` | Blind Index (`aadhaar_hmac`) | Full (Reveal Logged) | Full (Reveal Logged) | Masked Only | YES | NO | `APPROVED` |
| `uan_number_enc` | UAN (EPF) | `VARCHAR(255)` | YES | Optional | Conditional | Strip non-digits | `^\d{12}$` | High | **AES-256/Sodium** | `XXXX XXXX 1234` | Blind Index (`uan_hmac`) | Full (Reveal Logged) | Full (Reveal Logged) | Masked Only | YES | NO | `APPROVED` |
| `esic_number_enc` | ESIC IP Number | `VARCHAR(255)` | YES | Optional | Conditional | Strip non-digits | `^\d{17}$` | Medium | **AES-256/Sodium** | `XXXX XXXX 1234` | No | Full (Reveal Logged) | Full (Reveal Logged) | Masked Only | YES | NO | `APPROVED` |

---

## 4. Explicitly Deferred Fields (Excluded from Scope)

The following fields are strictly **DEFERRED** and MUST NOT appear in Migration 003, PHP code, or HTML forms:

- `gender`
- `email_address`
- `alt_mobile_number`
- `bank_name`, `bank_account_holder`, `bank_account_no_enc`, `bank_ifsc_code`
- `emergency_contact_name`, `emergency_contact_phone`, `emergency_relationship`
- `nominee_name`, `nominee_relationship`
- All document upload/storage tables or handlers

---

## 5. Submission Completeness Rules (`validateKycForSubmission`)

When `transitionKycStatus($conn, $employeeId, KYC_STATUS_SUBMITTED, ...)` is called:
1. `date_of_birth` MUST NOT be null or empty.
2. `mobile_number` MUST be a valid 10-digit number (`^[6-9]\d{9}$`).
3. `current_address` MUST NOT be empty.
4. `permanent_address` MUST NOT be empty (unless `same_as_current == 1`).
5. If `pan_applicable == 1`: `pan_number_enc` MUST NOT be empty.
6. If `aadhaar_applicable == 1`: `aadhaar_number_enc` MUST NOT be empty.
7. If `uan_applicable == 1`: `uan_number_enc` MUST NOT be empty.
8. If `esic_applicable == 1`: `esic_number_enc` MUST NOT be empty.

---

## 6. Export and Search Isolation Rules

- **General Exports:** `export_monthly_register.php`, `export_payroll.php`, and `export_leave_balance.php` MUST NOT join or include `employee_kyc_private`.
- **Search Isolation:** Searches on Employee Master or KYC list views MUST search by `employee_no`, `employee_name`, or `branch_id`. Searching by full Aadhaar, PAN, or UAN is prohibited.
- **URL Privacy:** Query strings contain only integer `employee_id` values. No personal identifiers appear in URLs.

---

*Document approved for GeoRoster Prompt 03B-B Implementation.*

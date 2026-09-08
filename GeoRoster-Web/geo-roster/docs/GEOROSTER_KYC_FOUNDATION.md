# GeoRoster Employee KYC Foundation Architecture Guide

> **Document Version:** 1.0  
> **Status:** IMPLEMENTED IN DEVELOPMENT WORKSPACE (PROMPT 03A)  
> **Gate:** `KYC FOUNDATION GATE: READY FOR KYC FOUNDATION` | `PRODUCTION KYC GATE: NOT READY`  

---

## 1. Purpose

The Employee KYC (Know Your Customer / Employee) foundation introduces a controlled, auditable, and secure compliance identity workflow to GeoRoster for **Surge Marine Services Pvt. Ltd.**

In GeoRoster, the **Employee Master** remains the authoritative source for organizational and operational attributes (Employee No, Employee Name, Branch, Sub-Location, Designation, Category, Active Status). The **KYC Foundation** extends the Employee Master with a 1:1 compliance lifecycle that tracks identity verification states, review actions, and an immutable business audit history without altering core attendance, leave, or payroll logic.

---

## 2. Scope

### Implemented in Prompt 03A
- 1:1 `employee_kyc` profile domain model and database table.
- Append-only `employee_kyc_history` business audit trail.
- Strict 6-state KYC lifecycle (`NOT_STARTED`, `DRAFT`, `SUBMITTED`, `UNDER_REVIEW`, `VERIFIED`, `REJECTED`).
- Authoritative database-backed authorization checks (re-verifying user active status, role, and branch live from database on every KYC operation).
- Centralized service layer (`includes/kyc_service.php`).
- Output masking utilities (`maskIdentifier`, `maskPhone`, `maskEmail`, `maskAddress`).
- Authenticated sodium/AES-256 encryption helpers (`encryptKycField`, `decryptKycField`).
- Minimal Foundation UI:
  - KYC Status badge and KYC action link on Employee Master (`admin/employees.php`).
  - Dedicated foundation status & workflow page (`kyc/employee_kyc.php`).
- Database migration script (`database/migrations/002_employee_kyc_foundation.sql`).
- Comprehensive automated security, authorization, transaction, and workflow regression test suite.

### Explicitly NOT Implemented in Prompt 03A
- Document uploads, storage, or downloads.
- Document tables (`employee_kyc_documents`).
- Physical identity card images (Aadhaar, PAN, Bank passbook, photographs).
- OCR or automated scanning.
- DigiLocker, eSign, or government API integrations (UIDAI / NSDL / Income Tax APIs).
- Email / SMS notifications.
- KYC Excel export integrations.
- Production deployment or production database execution.

---

## 3. Existing GeoRoster Integration

The KYC foundation integrates cleanly into GeoRoster's existing plain-PHP architecture:

```text
  ┌─────────────────────────────────────────────────────────────┐
  │                      employees                              │
  │ (employee_id, employee_no, employee_name, branch_id, ...)   │
  └──────────────────────────────┬──────────────────────────────┘
                                 │ 1:1
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │                    employee_kyc                             │
  │ (kyc_id, employee_id, kyc_status, submitted_*, verified_*)   │
  └──────────────────────────────┬──────────────────────────────┘
                                 │ 1:Many
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │                 employee_kyc_history                        │
  │ (history_id, kyc_id, employee_id, actor_user_id, action)   │
  └─────────────────────────────────────────────────────────────┘
```

- **Authentication & Sessions:** Standard session check (`includes/auth_check.php`) combined with `startSecureSession()` and `applySecurityHeaders()`.
- **Authoritative Authorization:** Every KYC request invokes `requireAuthoritativeKycAccess()`, which re-queries the `users` table live to enforce active account status, role, and branch assignment.
- **CSRF Protection:** All state transitions require `requireCsrf()` with session-backed tokens.
- **Security Audit Log:** Major security events trigger `auditEvent()` in `security_audit_log` in addition to `employee_kyc_history`.

---

## 4. Database Architecture

### Entity Relationship Model

```text
  User (actor) ───► performs KYC action ───► employee_kyc_history
                                                    │
  Employee (1) ───► has one (1) ───────────► employee_kyc
```

### Table Definitions

1. **`employee_kyc`**
   - `kyc_id` INT AUTO_INCREMENT PRIMARY KEY
   - `employee_id` INT NOT NULL UNIQUE KEY (`uq_employee_kyc_employee`)
   - `kyc_status` VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
   - `submitted_at` DATETIME NULL, `submitted_by` INT NULL
   - `verified_at` DATETIME NULL, `verified_by` INT NULL
   - `rejected_at` DATETIME NULL, `rejected_by` INT NULL
   - `rejection_reason` VARCHAR(500) NULL
   - `created_at` DATETIME NOT NULL, `created_by` INT NULL
   - `updated_at` DATETIME NOT NULL, `updated_by` INT NULL
   - Foreign Keys: `fk_employee_kyc_employee` → `employees(employee_id)`, `fk_employee_kyc_submitted_by` → `users(user_id)`, `fk_employee_kyc_verified_by` → `users(user_id)`, `fk_employee_kyc_rejected_by` → `users(user_id)`.

2. **`employee_kyc_history`**
   - `history_id` INT AUTO_INCREMENT PRIMARY KEY
   - `kyc_id` INT NOT NULL
   - `employee_id` INT NOT NULL
   - `actor_user_id` INT NULL
   - `action` VARCHAR(50) NOT NULL
   - `previous_status` VARCHAR(20) NOT NULL
   - `new_status` VARCHAR(20) NOT NULL
   - `remarks` VARCHAR(500) NULL
   - `created_at` DATETIME NOT NULL
   - Foreign Keys: `fk_kyc_history_kyc` → `employee_kyc(kyc_id)`, `fk_kyc_history_employee` → `employees(employee_id)`, `fk_kyc_history_actor` → `users(user_id)`.

---

## 5. KYC Status Lifecycle

```text
 [NOT_STARTED] ──(Start KYC)──► [DRAFT] ──(Submit)──► [SUBMITTED]
                                  ▲                       │
                                  │                 (Start Review)
                             (Re-open)                    │
                                  │                       ▼
                             [REJECTED] ◄──(Reject)── [UNDER_REVIEW] ──(Verify)──► [VERIFIED]
```

### Allowed State Transitions

| From Status | Allowed To Status | Allowed Roles | Description |
|---|---|---|---|
| `NOT_STARTED` | `DRAFT` | Admin, HO, Branch User (own branch) | Creates the initial `employee_kyc` row and first history event. |
| `DRAFT` | `SUBMITTED` | Admin, HO, Branch User (own branch) | Employee or branch submits profile for verification review. |
| `SUBMITTED` | `UNDER_REVIEW` | Admin, HO User | Reviewer opens the profile and marks it under review. |
| `UNDER_REVIEW` | `VERIFIED` | Admin, HO User | Reviewer approves and internally verifies the profile. |
| `UNDER_REVIEW` | `REJECTED` | Admin, HO User | Reviewer rejects the profile with a mandatory reason. |
| `REJECTED` | `DRAFT` | Admin, HO, Branch User (own branch) | Profile is re-opened for corrections. |
| `VERIFIED` | Locked | None | Verified profiles are immutable in Prompt 03A. Re-opening requires explicit owner-approved amendment workflow. |

---

## 6. Authorization Model

| Action | Admin | HO User | Branch User |
|---|---|---|---|
| View KYC Status in Employee Master | All Employees | Permitted Branches | Own Branch Employees Only |
| View KYC Profile Page | All Employees | Permitted Branches | Own Branch Employees Only |
| Start KYC (`NOT_STARTED` → `DRAFT`) | Allowed | Allowed | Own Branch Employees Only |
| Edit Draft Metadata | Allowed | Allowed | Own Branch Employees Only |
| Submit KYC (`DRAFT` → `SUBMITTED`) | Allowed | Allowed | Own Branch Employees Only |
| Start Review (`SUBMITTED` → `UNDER_REVIEW`) | Allowed | Allowed | **DENIED** |
| Verify KYC (`UNDER_REVIEW` → `VERIFIED`) | Allowed | Allowed | **DENIED** |
| Reject KYC (`UNDER_REVIEW` → `REJECTED`) | Allowed | Allowed | **DENIED** |
| Re-open Rejected (`REJECTED` → `DRAFT`) | Allowed | Allowed | Own Branch Employees Only |
| View History Log | All | Permitted Branches | Own Branch Employees Only |
| View Unmasked Sensitive Identifiers | Admin Only | Configurable | **DENIED (Masked Always)** |

---

## 7. Authoritative Authorization

Previous testing revealed that standard application sessions retain cached session variables (`$_SESSION["role"]`, `$_SESSION["branch_id"]`). To ensure KYC security:

`requireAuthoritativeKycAccess($conn, $employeeId)` re-queries the `users` table live on **every single KYC operation**:
1. Checks that the authenticated user account is still `is_active = 1`.
2. Fetches the user's **current** `role_name` and `branch_id` from the database.
3. Loads the target employee's `branch_id`.
4. Enforces branch isolation: if the live user role is `Branch User`, the target employee's branch MUST match the live user branch in the database.
5. If the user account was deactivated or transferred to another branch after login, KYC access is **immediately denied**.

---

## 8. Data Classification Reference

Refer to [docs/GEOROSTER_KYC_DATA_CLASSIFICATION.md](docs/GEOROSTER_KYC_DATA_CLASSIFICATION.md) for the full data classification matrix.

---

## 9. Encryption Architecture

1. **Algorithm:** Authenticated Encryption via Sodium (`sodium_crypto_secretbox`) or OpenSSL AES-256-GCM.
2. **Key Storage:** Encryption keys MUST be supplied via environment variables (`GEOROSTER_KYC_ENCRYPTION_KEY`) or an un-tracked private config file (`../georoster-config/kyc_key.php`). Keys MUST NEVER be committed to version control or stored in database tables.
3. **Key Rotation Concept:** Every encrypted ciphertext includes a key-version prefix (e.g. `v1:<nonce>:<ciphertext>`), allowing seamless re-encryption under new keys.
4. **Masking Utility:** `maskIdentifier($value)` provides safe output formatting (e.g., `XXXX XXXX 1234`) for UI display without decrypting full values unnecessarily.

---

## 10. KYC Audit / History

GeoRoster separates security-level events from business-level KYC history:
- **`security_audit_log`:** High-level security event trail (e.g. `kyc_profile_started`, `kyc_status_changed`, `kyc_access_denied`).
- **`employee_kyc_history`:** Domain-specific business audit log storing previous status, new status, actor ID, action name, and rejection reasons.

---

## 11. Transaction Strategy

All status transition operations in `includes/kyc_service.php` execute within a database transaction (`$conn->begin_transaction()`):
1. Lock the `employee_kyc` row for update.
2. Verify allowed status transition and role permissions.
3. Update `employee_kyc` status and actor timestamps.
4. Insert record into `employee_kyc_history`.
5. If history insertion or status update fails for any reason, perform `$conn->rollback()` so the profile status and history log never diverge.
6. Commit transaction (`$conn->commit()`).

---

## 12. Privacy Principles

- **Data Minimization:** Unapproved statutory/banking fields are omitted from Prompt 03A.
- **Least Privilege:** Branch Users cannot verify profiles or view unmasked identifiers.
- **Export Separation:** General attendance, monthly register, and payroll exports MUST NOT include KYC information.
- **URL Privacy:** Query strings contain only integer `employee_id` values. No personal identifiers appear in URLs.
- **Log Privacy:** No sensitive identity values appear in error logs or audit metadata.

---

## 13. Document Security Reference

Refer to [docs/GEOROSTER_KYC_DOCUMENT_SECURITY_DESIGN.md](docs/GEOROSTER_KYC_DOCUMENT_SECURITY_DESIGN.md) for document security specifications.

```text
DOCUMENT FUNCTIONALITY IS NOT IMPLEMENTED IN PROMPT 03A.
```

---

## 14. Deployment Requirements

Before deploying KYC to production:
1. Set private DB credentials and `GEOROSTER_KYC_ENCRYPTION_KEY`.
2. Rotate the previously exposed production DB credential.
3. Execute `database/migrations/001_security_audit_log_and_integrity.sql` and `002_employee_kyc_foundation.sql` on production DB after preflight verification.
4. Ensure production server uses HTTPS and `display_errors = Off`.

---

## 15. Known Deferred Decisions

- Product owner sign-off on mandatory vs optional personal/statutory KYC fields.
- Decision on whether HO Users have verification authority.
- KYC document retention schedule and expiry policy.
- Verified profile amendment / re-opening policy.

---

## 16. Testing Evidence

All 71 pre-KYC verification tests plus 20 new KYC foundation unit and integration tests passed (91/91 total tests passing). See `docs/GEOROSTER_KYC_FOUNDATION_VERIFICATION.md` for detailed results.

---

## 17. Next Recommended Phase

**Prompt 03B — Approved Employee KYC Fields & Data Entry** (to be executed only after product owner sign-off on data classification).

---

*Document prepared for GeoRoster Prompt 03A Foundation Phase.*

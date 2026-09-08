# GeoRoster Employee KYC Product Owner Decision Gate

> **Document Version:** 2.0 (Frozen for Prompt 03B-B Implementation)
> **Status:** APPROVED & FROZEN BY PRODUCT OWNER
> **Phase:** Prompt 03B-B — Approved Employee KYC Fields & Secure Data Entry
> **Current Technical Gate:** `KYC DATA ENTRY IMPLEMENTATION: PASS` | `PRODUCTION KYC GATE: NOT READY`

---

## 1. Executive Summary & Frozen Scope

The Product Owner for **Surge Marine Services Pvt. Ltd. (SMSPL)** has reviewed and approved the decision matrix below. These decisions are **FROZEN** for the Prompt 03B-B implementation phase.

GeoRoster enforces **Data Minimization** and **Privacy by Design**:
- Only approved MVP fields are collected in `employee_kyc_private`.
- Non-essential fields (Gender, Email, Banking, Emergency contacts, Documents) remain strictly **DEFERRED**.
- Existing Employee Master attributes (`employees`) remain the single source of truth for organizational identifiers.

---

## 2. Frozen Product Owner Decision Matrix

| Decision ID | Topic / Candidate Area | Options Considered | Frozen Product Owner Decision & Implementation Rule | Status |
|---|---|---|---|---|
| **KYC-DEC-001** | **Basic Personal Data** | **A.** DOB, Gender, Mobile, Email, Addresses.<br>**B.** DOB, Mobile, Current & Permanent Address.<br>**C.** DOB and Mobile only. | **APPROVED OPTION B**: DOB, Mobile, Current Address, and Permanent Address (with `Same as Current` control). Gender, Email, and Alt Mobile are **DEFERRED**. | `APPROVED & FROZEN` |
| **KYC-DEC-002** | **Aadhaar Number Collection** | **A.** Mandatory for all.<br>**B.** Conditional via applicability control.<br>**C.** Do not collect. | **APPROVED OPTION B**: Conditional via `aadhaar_applicable` flag. Encrypted at rest (Sodium/AES-256-GCM), masked as `XXXX XXXX 1234`, blind index duplicate review (`aadhaar_hmac`). | `APPROVED & FROZEN` |
| **KYC-DEC-003** | **PAN (Tax Identifier)** | **A.** Mandatory for all.<br>**B.** Conditional via applicability control.<br>**C.** Optional for all. | **APPROVED OPTION B**: Conditional via `pan_applicable` flag. Uppercase normalized, 10-char format check, encrypted at rest, masked as `XXXXX1234X`, blind index duplicate review (`pan_hmac`). | `APPROVED & FROZEN` |
| **KYC-DEC-004** | **UAN (EPF Identifier)** | **A.** Mandatory for all.<br>**B.** Conditional via applicability control.<br>**C.** Do not collect. | **APPROVED OPTION B**: Conditional via `uan_applicable` flag. 12-digit numeric format check, encrypted at rest, masked as `XXXX XXXX 1234`, blind index duplicate review (`uan_hmac`). | `APPROVED & FROZEN` |
| **KYC-DEC-005** | **ESIC / IP Number** | **A.** Mandatory for Labour.<br>**B.** Conditional via applicability control.<br>**C.** Do not collect. | **APPROVED OPTION B**: Conditional via `esic_applicable` flag. 17-digit numeric format check, encrypted at rest, masked as `XXXX XXXX 1234`. Applicability set by Admin/HO (no hardcoded wage ceiling in code). | `APPROVED & FROZEN` |
| **KYC-DEC-006** | **Banking Information** | **A.** Collect Account & IFSC.<br>**B.** Defer banking data. | **APPROVED OPTION B (DEFERRED)**: Banking details are **DEFERRED**. No bank columns, tables, encryption, or forms created in 03B-B. | `DEFERRED` |
| **KYC-DEC-007** | **Emergency & Nominee Data** | **A.** Include in KYC.<br>**B.** Defer to future HR Profile. | **APPROVED OPTION B (DEFERRED)**: Emergency contacts and Nominee details are **DEFERRED** to a future Employee Profile/HR module. | `DEFERRED` |
| **KYC-DEC-008** | **Branch User Data-Entry Authority** | **A.** Branch Users manage basic data for own branch.<br>**B.** Branch Users view status only. | **APPROVED OPTION A**: Branch Users can enter/edit basic data (DOB, Mobile, Address) for employees in their **own branch only**. Branch Users CANNOT edit statutory fields or applicability flags. | `APPROVED & FROZEN` |
| **KYC-DEC-009** | **KYC Verification Authority** | **A.** Admin only.<br>**B.** Admin + HO Users.<br>**C.** Dedicated Reviewer role. | **APPROVED OPTION A**: Final `VERIFIED` and `REJECTED` transitions are **ADMIN-ONLY**. HO Users can review (`UNDER_REVIEW`), but cannot issue final verification or rejection. | `APPROVED & FROZEN` |
| **KYC-DEC-010** | **Verified Record Editing Policy** | **A.** Verified records are locked.<br>**B.** Admin can edit directly. | **APPROVED OPTION A**: Verified KYC profiles are **LOCKED** (read-only). Editing attempts are blocked with HTTP 403 / notice. Amendment workflow deferred to future phase. | `APPROVED & FROZEN` |
| **KYC-DEC-011** | **Expiry & Renewal Policy** | **A.** Annual mandatory KYC expiry.<br>**B.** No expiry for core KYC identity. | **APPROVED OPTION B**: Core identity records do not expire. Document-level expiry will be handled in the future Document Phase. | `APPROVED & FROZEN` |
| **KYC-DEC-012** | **Document Proof Requirements** | **A.** Document upload in 03B.<br>**B.** Structured data in 03B, documents deferred. | **APPROVED OPTION B (DEFERRED)**: Physical document uploads (Aadhaar/PAN/Bank proof images) remain **DEFERRED** to a separate Document Phase. | `DEFERRED` |
| **KYC-DEC-013** | **Data Retention Policy** | **A.** Automated purge scripts.<br>**B.** Manual policy required. | **APPROVED OPTION B**: Retention automation deferred. Marked: `HR/LEGAL POLICY REQUIRED — NOT YET IMPLEMENTED`. | `DEFERRED` |
| **KYC-DEC-014** | **Sensitive Field Duplicate Detection** | **A.** Hard UNIQUE DB constraint.<br>**B.** Keyed blind index duplicate review. | **APPROVED OPTION B**: Duplicate entries detected via HMAC-SHA256 blind indexes (`pan_hmac`, `aadhaar_hmac`, `uan_hmac`). Duplicate entry triggers a warning and blocks submission for review. | `APPROVED & FROZEN` |
| **KYC-DEC-015** | **Full-Value Visibility Matrix** | **A.** Show unmasked values.<br>**B.** Masked by default; POST+CSRF reveal for Admin/HO. | **APPROVED OPTION B**: All sensitive fields masked by default. Branch Users have NO reveal authority. Admin and HO Users can reveal unmasked values via POST+CSRF, which logs a `kyc_sensitive_field_revealed` audit event without logging plaintext. | `APPROVED & FROZEN` |

## 3. Product Owner Decision Matrix

| Decision ID | Topic / Candidate Area | Options Considered | Technical & Business Recommendation | Current Status / Owner Decision |
|---|---|---|---|---|
| **KYC-DEC-001** | **Basic Personal Data** | **A.** Collect DOB, Gender, Mobile, Email, Current & Permanent Address.<br>**B.** Collect DOB, Mobile, and Addresses only.<br>**C.** Collect DOB and Mobile only. | **Recommend Option B**: DOB, Mobile, Current Address, and Permanent Address (with a `Same as Current Address` checkbox). Gender and Email should remain optional. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-002** | **Aadhaar Number Collection** | **A.** Mandatory for all employees.<br>**B.** Mandatory for Staff, Optional for Labour.<br>**C.** Optional for all.<br>**D.** Do not collect. | **Recommend Option B**: Mandatory for Staff, Optional for Labour. Store using AES-256/Sodium authenticated encryption with `XXXX XXXX 1234` masking. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-003** | **PAN (Tax Identifier)** | **A.** Mandatory for all.<br>**B.** Mandatory for Staff, Conditional for Labour if taxable.<br>**C.** Optional for all. | **Recommend Option B**: Mandatory for Staff, Conditional/Optional for Labour. Store encrypted with `XXXXX1234X` masking. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-004** | **UAN (EPF Identifier)** | **A.** Mandatory for all eligible employees.<br>**B.** Conditional on PF applicability.<br>**C.** Do not collect in GeoRoster. | **Recommend Option B**: Conditional on Provident Fund applicability. 12-digit format validation. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-005** | **ESIC / IP Number** | **A.** Mandatory for Labour category.<br>**B.** Conditional on wage threshold.<br>**C.** Do not collect. | **Recommend Option B**: Conditional based on statutory ESIC wage ceiling limits. 17-digit format validation. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-006** | **Banking Information** | **A.** Collect Account Holder, Bank Name, Account Number, IFSC.<br>**B.** Collect Account Number and IFSC only.<br>**C.** Defer banking data entirely. | **Recommend Option A**: Collect full banking details if GeoRoster is used to generate direct-deposit bank advice files. Account Number MUST be encrypted at rest and masked. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-007** | **Emergency & Nominee Data** | **A.** Include in Employee KYC.<br>**B.** Defer to a future Employee Profile/HR module.<br>**C.** Do not collect. | **Recommend Option B**: Defer Emergency Contact and Nominee details to a separate HR Profile module to keep KYC strictly focused on statutory identity compliance. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-008** | **Branch User Data-Entry Authority** | **A.** Branch Users can enter/edit Drafts and Submit.<br>**B.** Branch Users can view status only; HO/Admin collects data.<br>**C.** Branch Users enter basic data, no statutory IDs. | **Recommend Option A**: Branch Users enter Draft data and Submit for their own branch employees. Access is strictly branch-scoped and masked by default. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-009** | **KYC Verification Authority** | **A.** Admin only.<br>**B.** Admin + HO Users.<br>**C.** Create dedicated KYC Reviewer role. | **Recommend Option B**: Admin and HO Users can Review, Verify, or Reject profiles. Avoid creating new roles unless required by organizational policy. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-010** | **Verified Record Editing Policy** | **A.** Verified records are locked; changes require explicit Re-open/Amendment request.<br>**B.** Admin can edit Verified records directly.<br>**C.** Re-verify on any edit. | **Recommend Option A**: Verified profiles are immutable. Editing a Verified profile moves it to `AMENDMENT_PENDING` / `DRAFT` and requires re-verification by Admin/HO. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-011** | **Expiry & Renewal Policy** | **A.** Annual mandatory KYC re-verification.<br>**B.** No expiry for core KYC identity; expiry tracked at document level only.<br>**C.** Expiry for address proof every 3 years. | **Recommend Option B**: Statutory identifiers (Aadhaar/PAN/UAN) do not expire. Document-level expiry (e.g. driving license/passport) will be handled in the Document Phase. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-012** | **Document Proof Requirements** | **A.** Mandatory document upload for every field.<br>**B.** Optional document proof.<br>**C.** Data entry first (Prompt 03B), document proof in separate Document Phase. | **Recommend Option C**: Implement structured data collection in Prompt 03B first. Physical document upload/storage will be delivered in the subsequent Document Phase. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-013** | **Data Retention Policy** | **A.** Retain KYC data indefinitely.<br>**B.** Retain 7 years post-employment termination.<br>**C.** Purge rejected drafts after 90 days. | **Recommend Option B & C**: Retain active/verified records for 7 years post-employment for statutory audit compliance; purge un-submitted rejected drafts after 90 days. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-014** | **Sensitive Field Duplicate Detection** | **A.** Allow duplicates.<br>**B.** Block duplicate Aadhaar/PAN/Account No across employees using Keyed Blind Indexes (HMAC-SHA256). | **Recommend Option B**: Block duplicate statutory/bank entries using a blind index (`generateBlindIndex`) to prevent multiple employees sharing the same Aadhaar/PAN/Account No without storing plaintext. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |
| **KYC-DEC-015** | **Full-Value Visibility Matrix** | **A.** Show unmasked values to all authorized users.<br>**B.** Mask sensitive values for Branch Users always; show full values to Admin/HO only on explicit click with audit logging. | **Recommend Option B**: Branch Users see masked values (`XXXX XXXX 1234`) always. Admin and HO Users see masked values by default, with a "Reveal" button that logs a security audit event. | `AWAITING PRODUCT OWNER KYC FIELD APPROVAL` |

---

## 4. Staff vs. Labour Applicability Matrix

Surge Marine Services manages both office/technical **Staff** and marine/depot **Labour**. Statutory requirements differ significantly between these categories:

| Field | Staff Category | Labour Category | Conditional Rule | Validation / Format Rule |
|---|---|---|---|---|
| **Date of Birth** | Mandatory | Mandatory | Always Required | Standard Date (`YYYY-MM-DD`), Age >= 18 |
| **Mobile Number** | Mandatory | Mandatory | Always Required | 10-digit Indian Mobile (`^[6-9]\d{9}$`) |
| **Current Address** | Mandatory | Mandatory | Always Required | Minimum 10 characters, State/City required |
| **Permanent Address** | Mandatory | Mandatory | Copy from Current if checked | Minimum 10 characters |
| **PAN Number** | Mandatory | Conditional | Required for Labour if taxable income | 10-char Alphanumeric (`^[A-Z]{5}[0-9]{4}[A-Z]{1}$`) |
| **Aadhaar Number** | Mandatory | Optional / Preferred | Mandatory for Staff | 12-digit Numeric (`^\d{12}$`) + Verhoeff Checksum |
| **UAN (EPF)** | Mandatory | Conditional | Required if EPF contribution applies | 12-digit Numeric (`^\d{12}$`) |
| **ESIC Number** | Conditional | Mandatory | Required if monthly wage <= ESIC ceiling | 17-digit Numeric (`^\d{17}$`) |
| **Bank Account No** | Mandatory | Mandatory | Required for direct salary credit | 9–18 digit Alphanumeric (`^[A-Za-z0-9]{9,18}$`) |
| **Bank IFSC Code** | Mandatory | Mandatory | Required for direct salary credit | 11-char Alphanumeric (`^[A-Z]{4}0[A-Z0-9]{6}$`) |

---

## 5. Draft Completeness & Submission Validation Architecture

To allow flexible data collection without compromising data quality, GeoRoster enforces a **Two-Tier Validation Strategy**:

1. **Draft Save (Permissive):**
   - Allows partial or incomplete data entry so Branch/HO Users can save work in progress (`KYC_STATUS_DRAFT`).
   - Validates format/regex only for fields actually supplied (e.g. if PAN is typed, it must match PAN format).
   - Does NOT block saving if required statutory fields are still missing.

2. **Submission Validation (`validateKycForSubmission($conn, $employeeId)`):**
   - Triggered when the user attempts `DRAFT -> SUBMITTED`.
   - Performs strict completeness checks based on Employee Category (Staff vs Labour).
   - If mandatory fields are missing or invalid, submission is **blocked** with an explicit list of missing items.

```text
               ┌─────────────────────────────────────────┐
               │         KYC DATA ENTRY (DRAFT)          │
               └────────────────────┬────────────────────┘
                                    │
                                    ▼
                      Save Draft Clicked?
                       ├── YES ──► Save Partial Values (Format Checked if present)
                       │
                       └─ SUBMIT CLICKED
                                    │
                                    ▼
                   Execute validateKycForSubmission()
                     ├── Incomplete ──► Return 400 Bad Request + Missing Field List
                     │
                     └── Complete ───► Transition Status to SUBMITTED + Audit Log
```

---

## 6. Field-Level Access, Masking & Encryption Strategy

To prevent unauthorized exposure or data exfiltration:

### Access Rules
- **Branch Users:** Can enter/edit Draft data for employees in their **own branch only**. Can view masked status. Cannot view full Aadhaar, PAN, or Bank Account numbers.
- **HO Users:** Can view, review, verify, or reject KYC for authorized branches. Can view unmasked values via explicit reveal controls.
- **Admin Users:** Global access to view, edit, verify, reject, or re-open all KYC profiles.

### Encryption Specifications
- **Algorithm:** Authenticated Encryption via Sodium (`sodium_crypto_secretbox`) or OpenSSL AES-256-GCM.
- **Encrypted Columns:** `aadhaar_number_enc`, `pan_number_enc`, `bank_account_no_enc`.
- **Key Location:** Loaded via `GEOROSTER_KYC_ENCRYPTION_KEY` environment variable or `../georoster-config/kyc_key.php`. Keys MUST NEVER be committed to Git or stored in database tables.

### Masking Rules
- **PAN:** `XXXXX1234X` (shows only the 4 numeric digits and last letter).
- **Aadhaar:** `XXXX XXXX 1234` (shows only the final 4 digits).
- **Bank Account:** `XXXXXX1234` (shows only the final 4 digits).
- **Mobile Number:** `XXXXXX1234` (shows only the final 4 digits).

---

## 7. Duplicate Detection & Blind Index Architecture

To enforce uniqueness on encrypted fields (e.g. preventing two employees from sharing the same PAN or Aadhaar number) without storing plaintext values:

1. **HMAC-SHA256 Blind Indexes:**
   When a sensitive field is saved, a deterministic keyed hash is computed:
   $$\text{BlindIndex} = \text{HMAC-SHA256}(\text{NormalizedValue}, \text{GEOROSTER\_KYC\_HMAC\_KEY})$$
2. **Database Table:**
   Blind indexes are stored in indexed columns (e.g. `pan_blind_index`, `aadhaar_blind_index`) with `UNIQUE` constraints.
3. **Exact Matching:**
   To check if a newly entered PAN already exists in the system, the application computes its blind index and executes a fast, exact-match query against the database without decrypting any records.

---

## 8. Definition of "VERIFIED" Status

In GeoRoster, the status `VERIFIED` carries a strict internal meaning:

```text
"VERIFIED" MEANS THAT AN AUTHORIZED SURGE MARINE SERVICES REVIEWER (ADMIN OR HO USER)
HAS REVIEWED THE SUBMITTED KYC INFORMATION AGAINST INTERNAL COMPANY HR STANDARDS.

IT DOES NOT IMPLY OR CLAIM GOVERNMENT-LEVEL AUTHENTICATION, UIDAI AADHAAR VERIFICATION,
INCOME TAX PAN AUTHENTICATION, OR DIRECT BANK ACCOUNT VERIFICATION.
```

To eliminate ambiguity on user interfaces and reports, the UI displays:

$$\text{Status Label:} \quad \mathbf{\text{Internally Verified}}$$

---

## 9. Search and Export Privacy Policies

1. **No KYC Data in General Exports:**
   Existing monthly register, payroll sheet, and leave balance exports (`export_monthly_register.php`, `export_payroll.php`, `export_leave_balance.php`) MUST remain completely isolated from KYC data. They will **NEVER** output PAN, Aadhaar, bank accounts, or addresses.

2. **No Sensitive Identifiers in Search / URLs:**
   Searches on Employee Master or KYC list views MUST search by `employee_no`, `employee_name`, or `branch_id`. Searching by full Aadhaar or Bank Account number is **prohibited**.

3. **URL Privacy:**
   All KYC routes use opaque integer IDs (`employee_id=12`). Sensitive numbers or names MUST NEVER appear in query strings.

---

## 10. Summary of Required Product Owner Approvals

Before proceeding to Prompt 03B code implementation, the Product Owner must review and approve:

1. [ ] **MVP Field List**: Approval of basic personal, statutory, and banking candidates (§3).
2. [ ] **Staff vs Labour Rules**: Approval of conditional PAN/Aadhaar/UAN rules for Labour category (§4).
3. [ ] **HO Verification Role**: Confirmation that HO Users are authorized to Verify/Reject (§3, KYC-DEC-009).
4. [ ] **Branch User Masking**: Confirmation that Branch Users see masked sensitive values only (§3, KYC-DEC-015).
5. [ ] **Verified Profile Lock**: Confirmation that Verified profiles are locked and require an explicit re-open workflow (§3, KYC-DEC-010).

---

*Document prepared for GeoRoster Prompt 03B-A Decision Checkpoint.*

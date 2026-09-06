# GeoRoster Employee KYC Data Classification Guide

> **Document Version:** 1.0  
> **Status:** PROPOSED — OWNER APPROVAL REQUIRED FOR UNAPPROVED FIELDS  
> **Phase:** Prompt 03A — Foundation Phase  

---

## 1. Overview & Data Minimization Principles

This document defines the classification, sensitivity, storage requirements, masking rules, and role-based access controls for all current and proposed employee data fields in GeoRoster.

GeoRoster adheres to **Privacy by Design** and **Data Minimization**:
1. Only data necessary for legitimate HR, attendance, payroll, and statutory compliance is collected.
2. Unapproved sensitive fields remain **PROPOSED** and are **NOT** stored or collected in Prompt 03A.
3. Access to sensitive identifiers is restricted by role and branch scope.
4. Sensitive values are masked by default on user interfaces and excluded from general attendance and payroll exports.

---

## 2. Comprehensive Data Classification Matrix

| Field / Data Group | Status | Purpose | Sensitivity | Storage | Masking Rule | Encryption | Roles with View Access | MVP Recommendation | Owner Approval |
|---|---|---|---|---|---|---|---|---|---|
| **Employee No** | APPROVED | Primary HR Identifier | Public / Low | Database (`employees.employee_no`) | None | None | Admin, HO, Branch | Include in MVP | Approved (Existing) |
| **Employee Name** | APPROVED | Personal Identification | Low | Database (`employees.employee_name`) | None | None | Admin, HO, Branch | Include in MVP | Approved (Existing) |
| **Branch & Sub-Location** | APPROVED | Organizational Assignment | Low | Database (`employees.branch_id`, `location_id`) | None | None | Admin, HO, Branch | Include in MVP | Approved (Existing) |
| **Designation & Category** | APPROVED | HR Classification (Staff/Labour) | Low | Database (`employees.designation`, `employee_category`) | None | None | Admin, HO, Branch | Include in MVP | Approved (Existing) |
| **Date of Birth** | PROPOSED | Verification & Statutory Compliance | Medium | Database (`employee_kyc_private`) | `DD/MM/XXXX` | Optional | Admin, HO | Defer to Prompt 03B | **Pending Approval** |
| **Gender** | PROPOSED | HR Records | Low | Database (`employee_kyc_private`) | None | None | Admin, HO | Defer to Prompt 03B | **Pending Approval** |
| **Mobile Number** | PROPOSED | Contact / Emergency | Medium | Database (`employee_kyc_private`) | `XXXXXX1234` | Optional | Admin, HO, Branch (Scoped) | Defer to Prompt 03B | **Pending Approval** |
| **Email Address** | PROPOSED | Official / Personal Contact | Low | Database (`employee_kyc_private`) | `u***r@domain.com` | None | Admin, HO, Branch (Scoped) | Defer to Prompt 03B | **Pending Approval** |
| **Current / Permanent Address** | PROPOSED | Residence Proof & Statutory Verification | Medium | Database (`employee_kyc_private`) | Mask street, show City/State | Optional | Admin, HO | Defer to Prompt 03B | **Pending Approval** |
| **PAN (Permanent Account Number)** | PROPOSED | Income Tax & Statutory Audit | High | Database (`employee_kyc_private`) | `XXXXX1234X` | **Recommended (AES-256/Sodium)** | Admin, HO (Masked for Branch) | Defer to Prompt 03B | **Pending Approval** |
| **Aadhaar Number** | PROPOSED | Identity Proof (Indian Compliance) | **Critical / Confidential** | Database (`employee_kyc_private`) | `XXXX XXXX 1234` | **Mandatory (AES-256/Sodium)** | Admin, HO (Masked by default) | Defer to Prompt 03B | **Pending Approval** |
| **UAN (Universal Account Number)** | PROPOSED | Provident Fund (EPFO) | High | Database (`employee_kyc_private`) | `XXXX XXXX 1234` | Optional | Admin, HO | Defer to Prompt 03B | **Pending Approval** |
| **ESIC / IP Number** | PROPOSED | Employee State Insurance | Medium | Database (`employee_kyc_private`) | `XXXX XXXX 1234` | Optional | Admin, HO | Defer to Prompt 03B | **Pending Approval** |
| **Bank Account Holder Name** | PROPOSED | Payroll Salary Transfer | Medium | Database (`employee_kyc_private`) | None | None | Admin, HO | Defer to Prompt 03B | **Pending Approval** |
| **Bank Name & IFSC Code** | PROPOSED | Payroll Routing | Low | Database (`employee_kyc_private`) | None | None | Admin, HO | Defer to Prompt 03B | **Pending Approval** |
| **Bank Account Number** | PROPOSED | Direct Deposit | High | Database (`employee_kyc_private`) | `XXXX XXXX 1234` | **Recommended (AES-256/Sodium)** | Admin, HO | Defer to Prompt 03B | **Pending Approval** |
| **Emergency Contact Details** | PROPOSED | Workplace Safety | Medium | Database (`employee_kyc_private`) | `XXXXXX1234` | None | Admin, HO, Branch | Defer to Prompt 03B | **Pending Approval** |
| **Nominee Information** | PROPOSED | Statutory Benefits / PF | High | Database (`employee_kyc_private`) | Mask Relationship/Contact | Optional | Admin, HO | Defer to Later Phase | **Pending Approval** |
| **Identity / Address / Bank Documents** | PROPOSED | Verification Proof | **Confidential Files** | Protected Filesystem (Outside Webroot) | N/A (Streaming Download) | Storage Encryption / Access Control | Admin, HO | Defer to Document Phase | **Pending Approval** |

---

## 3. Strict Classification Definitions

1. **APPROVED/EXISTING**:
   Fields currently present in `employees` table. These form the base for Employee Master and are authorized for attendance, leave, and payroll operations.

2. **PROPOSED — OWNER APPROVAL REQUIRED**:
   All statutory, banking, and personal identity fields. **None of these fields are collected or stored in Prompt 03A.** Prompt 03A implements only the workflow status lifecycle, audit history, service layer, and security architecture.

3. **Data Protection Rules for Proposed Sensitive Data**:
   - **Aadhaar Rule:** Raw Aadhaar numbers MUST NEVER be stored unencrypted or displayed in full on any UI or report. Always display masked as `XXXX XXXX 1234`.
   - **Bank Account Rule:** Account numbers MUST be masked on general screens (`XXXX XXXX 1234`) and accessible only to authorized Admin/HO users during payroll verification.
   - **No Sensitive Data in Logs or URLs:** PAN, Aadhaar, bank numbers, and dates of birth MUST NEVER be passed as URL query parameters or printed into `error_log` or audit metadata.
   - **No Sensitive Data in Exports:** General attendance, monthly register, and payroll exports MUST NOT include statutory or banking identifiers.

---

*Document generated for GeoRoster Prompt 03A Foundation Phase.*

# GeoRoster KYC Amendment and Review

## 1. Purpose

This feature provides a controlled change path for a VERIFIED employee KYC profile. A verified profile remains the approved point-in-time record. Proposed changes are stored separately, reviewed, and applied only after Admin approval.

No document upload, document download, banking, retention automation, or production deployment is included.

## 2. Amendment Architecture

The amendment model uses two tables:

- `employee_kyc_amendments` stores workflow metadata, reason, actors, timestamps, status, and rejection details.
- `employee_kyc_amendment_private` stores the proposed basic and statutory values separately from `employee_kyc_private`.

The amendment private row is initialized from the current verified private row. Encrypted statutory fields remain encrypted and blind indexes are retained for duplicate review. The current verified private row is not changed while the amendment is being prepared or reviewed.

## 3. Status Lifecycle

The allowed amendment statuses are:

`REQUESTED`, `DRAFT`, `SUBMITTED`, `UNDER_REVIEW`, `REJECTED`, `APPROVED`, and `CANCELLED`.

The current implementation creates a requested amendment in `DRAFT`, which allows the requester to complete and submit the snapshot. Rejected amendments can be explicitly revised back to `DRAFT`. Only one active amendment (`REQUESTED`, `DRAFT`, `SUBMITTED`, or `UNDER_REVIEW`) is allowed for a KYC profile.

## 4. Permissions

- Branch Users can request amendments for employees in their current live branch and edit basic fields only.
- HO Users can request, edit basic fields and authorized statutory fields, and start review.
- Admin users can request, edit all approved fields, start review, reject, approve, and reveal sensitive values through the existing audited mechanism.
- Final amendment approval and rejection are Admin-only.

Permissions are checked against the current database user record on every operation. Session role and branch snapshots are not trusted.

## 5. Verified Data Preservation

`employee_kyc.kyc_status` remains `VERIFIED` while an amendment exists. Ordinary basic and statutory update functions reject direct edits to a VERIFIED profile. Approval updates the current private row only inside the final approval transaction.

The UI presents the current verified data separately from the pending amendment and provides a changed/unchanged summary without displaying old/new sensitive values.

## 6. Amendment Data Protection

PAN, Aadhaar, UAN, and ESIC values in amendment storage use the same field encryption and blind-index helpers as the current KYC data. Queue views and history metadata do not contain plaintext statutory values. Branch Users have no reveal action.

## 7. Duplicate Detection

When statutory values are entered, the service validates format, creates a blind index, and checks the current KYC private table for another employee using the same index. The employee's own current record is excluded from the conflict query. Approval repeats completion validation before applying the amendment.

## 8. Review Queue

`kyc/review_queue.php` is restricted to Admin and HO User accounts. The list exposes only employee number, employee name, branch, category, workflow type, status, timestamps, and a detail link. It supports branch, workflow, status, and employee search filters. No KYC private field is selected by the queue query.

HO queue visibility is restricted to the user's current live branch. The detail page performs its own authoritative access check; filters and links are not authorization boundaries.

## 9. Difference Display

The KYC detail page compares basic values and statutory applicability/blind-index state. It displays `Changed` or `Unchanged` rather than decrypted before/after values. Existing masked statutory display and audited Admin/HO reveal behavior remain separate from the difference summary.

## 10. Admin Final Approval

Admin approval requires an amendment in `UNDER_REVIEW`, current Admin authorization, complete proposed data, and a final transaction. The transaction updates current private data, marks the amendment `APPROVED`, keeps the KYC status `VERIFIED`, and records a history event. Failures roll back the database transaction.

## 11. Transaction Strategy

Request creation, submission, review start, rejection, cancellation, revision, and approval use transactions for their header/history mutations. Migration 004 adds a generated active slot and unique key to enforce one active amendment per KYC profile at the database layer.

## 12. Audit History

Business events are written to `employee_kyc_history`; privileged events are also sent to the existing security audit mechanism. Reasons may be recorded, but sensitive plaintext values and ciphertext are not placed in history metadata.

## 13. Security Model

All mutation forms use POST and the existing CSRF guard. Employee, KYC, and amendment identifiers are checked against the employee and current authorization context. Inactive users, changed roles, and changed branch assignments are re-evaluated from the database immediately.

## 14. Deferred Documents

Document upload, download, file storage, OCR, identity scans, photos, and document expiry are explicitly deferred to Prompt 03D.

## 15. Deferred Retention

No retention or purge automation is implemented. Retention remains subject to HR and legal policy.

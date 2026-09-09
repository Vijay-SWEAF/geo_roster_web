# GeoRoster KYC Bank Details

## Prompt 03G approval

Banking was previously deferred. Product Owner approval in Prompt 03G adds four Employee KYC fields only: Bank Account Number, IFSC Code, Account Type, and Bank Branch Name.

Bank Account Number is HIGH / FINANCIAL / SENSITIVE. IFSC, Account Type, and Branch Name are medium sensitivity. Bank data is visible only to Admin and KYC Officer users within their live employee scope. Regular HO and Branch users receive no bank content.

## Storage

Migration 007 adds `employee_kyc_bank_private` and `employee_kyc_bank_amendment_private`. Account numbers are normalized as strings, encrypted with the existing `encryptKycField()` framework, and indexed only by a non-unique HMAC blind index. Plaintext account numbers are never stored or logged. No bank field is added to `employees`, payroll, attendance, or generic search.

## Validation and UI

Account numbers trim and remove spaces/hyphens, preserve leading zeroes, and require 6-24 digits. New entries require an exact normalized confirmation. IFSC is uppercase, internal whitespace is removed, and the format is `^[A-Z]{4}0[A-Z0-9]{6}$`. Account Type is allowlisted to SAVINGS, CURRENT, SALARY, and OTHER. Branch Name is trimmed, whitespace-collapsed, HTML-escaped on output, and limited to 150 characters.

Banking is optional for KYC. A blank optional section creates no row; any partial entry is rejected. Existing account data is preserved when replacement account fields are blank. Values are masked to the last four digits by default. Explicit account reveal uses POST, CSRF, live authorization, and safe audit metadata only.

## Workflow and authorization

Unverified KYC can be maintained directly by Admin or KYC Officer. Verified KYC is immutable for direct bank edits. A verified profile must use the existing amendment workflow. Amendment creation snapshots the current bank row, amendment edits remain encrypted and masked, and Admin approval applies the amendment bank row in the same transaction as the existing KYC approval. Rejection and cancellation leave live bank data unchanged.

## Migration and rollout

`database/migrations/007_kyc_bank_details.sql` is additive. `database/production/007_PRODUCTION.sql` is a preparation pack only and has not been executed. `database/production/007_VERIFY.sql` is read-only and checks tables, columns, indexes, foreign keys, delete rules, and zero initial rows. No production database, FTP deployment, or database backfill is part of Prompt 03G.

## Scope exclusions

No Bank Name, Account Holder Name, SWIFT, MICR, UPI, beneficiary data, BANK_PROOF document type, payroll export change, general export change, or search-index change is included.

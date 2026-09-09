# GeoRoster KYC Bank Details Verification

Prompt 03G verification covers the approved four-field bank component. Synthetic-only validation tests cover normalization, leading zero preservation, confirmation matching, account length and character rules, IFSC, account type, branch normalization, optional blank sections, encryption round trip, wrong-key rejection, HMAC non-disclosure, and masking.

The implementation uses `employee_kyc_bank_private` and `employee_kyc_bank_amendment_private`, existing KYC encryption/HMAC helpers, live authoritative authorization, POST + CSRF routes, and audit events without plaintext account data. Direct edits are denied for VERIFIED KYC; amendment approval is Admin-only and transactionally applies bank data. Regular HO and Branch users do not receive bank details.

Before production rollout, apply the additive migration only through the approved change process, run `007_VERIFY.sql`, confirm both tables and all `RESTRICT` foreign keys, and verify zero initial rows. Prompt 03G does not execute production SQL or modify FTP.

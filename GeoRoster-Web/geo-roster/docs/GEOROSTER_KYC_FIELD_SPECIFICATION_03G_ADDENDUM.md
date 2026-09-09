# GeoRoster KYC Field Specification: Prompt 03G Addendum

Banking approved in Prompt 03G; previously deferred.

Approved fields only:

- Bank Account Number: HIGH / FINANCIAL / SENSITIVE; encrypted and HMAC-indexed, never plaintext.
- IFSC Code: MEDIUM; normalized uppercase and validated locally.
- Account Type: MEDIUM; SAVINGS, CURRENT, SALARY, or OTHER.
- Bank Branch Name: MEDIUM; trimmed, whitespace-collapsed, maximum 150 characters.

Regular HO and Branch users cannot see bank content. Admin and KYC Officer access remains live, scope-aware, CSRF-protected, and audit logged. Verified KYC changes use amendments and Admin approval. Payroll and generic exports remain unchanged.

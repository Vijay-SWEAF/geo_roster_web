# GeoRoster KYC Document Vault Deployment

## Status

Preparation only. Do not execute Migration 006 or create the production vault as part of this implementation.

## Future GoDaddy setup

After separate approval and backup review, create:

`/home/j3r2yhyocro4/georoster-kyc-vault/`

outside `public_html`. Prefer directory mode `0700`; do not use `0777`. The PHP process must be able to read and write the directory without changing it to world-writable. Encrypted objects should use mode `0600`.

The application should receive `GEOROSTER_KYC_VAULT_PATH` through private hosting configuration, or use the safe fallback derived from the application path. Verify the resolved canonical path is outside `DOCUMENT_ROOT` and outside the public GeoRoster tree.

Do not place the vault under `public_html`, `uploads`, the Git repository, or the database. Do not store encryption or HMAC key files in the vault.

## Deployment order later

1. Back up the production database and FTP tree.
2. Run a read-only preflight against the intended GoDaddy MariaDB.
3. Review and separately approve `database/production/006_PRODUCTION.sql`.
4. Execute Migration 006 manually only after approval.
5. Run `006_VERIFY.sql` and confirm zero initial document rows.
6. Create and permission the vault directory outside webroot.
7. Configure `GEOROSTER_KYC_VAULT_PATH` privately if desired.
8. Upload the matching PHP release only after database and vault checks pass.
9. Run controlled KYC document smoke tests with synthetic files.
10. Preserve backups and evidence.

No FTP or production database action was performed by this phase.

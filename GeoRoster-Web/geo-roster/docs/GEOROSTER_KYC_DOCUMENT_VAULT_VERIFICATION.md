# GeoRoster KYC Document Vault Verification

## Repository checkpoint

- Branch: `feature/kyc-document-vault`
- Hardening branch: `feature/kyc-document-vault`
- Production database: not modified
- FTP: not modified
- GitHub push: not performed

## Implemented surface

- Additive metadata migration 006.
- Private vault root resolution and webroot/path guard.
- Document-specific HKDF key derivation and authenticated encryption envelope.
- Strict PDF/JPEG/PNG upload validation and 5 MB limit.
- Random sharded storage keys and encrypted original filenames.
- Immutable version metadata and current/superseded lifecycle.
- Explicit `superseded_by` lineage for replaced documents.
- Content-HMAC verification before any document stream response.
- Admin/KYC Officer scoped upload/view/download.
- POST + CSRF upload and stream controllers.
- Safe document page and KYC profile entry point.
- Pending amendment promotion/rejection hooks.
- No mandatory document submission checklist.

## Tests planned/executed

- Migration chain 001-006 on disposable MariaDB: PASS; migration 006 rerun: PASS.
- Document table, five foreign keys, three uniqueness indexes, and delete rules: PASS.
- PHP lint: PASS for all repository PHP files.
- `git diff --check`: PASS.
- First-upload shard path creation and outside-webroot guard: PASS with a disposable `/tmp` vault.
- Authenticated encryption round trip: PASS.
- Content HMAC integrity primitive: PASS.
- Wrong-key and tampered-envelope rejection: PASS.
- Random storage key contains no employee or document identifiers: PASS.
- Development fallback/public-vault/static-secret scan: PASS.

Browser upload/stream UAT remains a Product Owner activity and was not claimed by this implementation. The HTTP controllers use POST + CSRF and the same live Admin/KYC Officer scope checks as the service layer. A live authenticated first-upload/version-replacement UAT was not run in this local hardening pass.

Required disposable tests include valid PDF/JPEG/PNG, fake extensions, double extensions, HTML/SVG/script content, oversize/empty files, traversal names, encryption round trip, wrong/tampered/truncated ciphertext, version replacement, authorization scope, revoke/deactivation, CSRF, and verified-amendment promotion/rejection.

## Production gate

- Migration 006 production execution: NOT PERFORMED.
- Production vault directory: NOT CREATED BY AGENT.
- Production FTP: NOT MODIFIED.
- Production KYC data: NOT MODIFIED.
- Retention automation: NOT IMPLEMENTED.
- Delete document UI: NOT IMPLEMENTED.

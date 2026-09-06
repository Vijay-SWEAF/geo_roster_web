# GeoRoster Production KYC Secret Setup

## Status

This is a safe configuration guide only. No production secrets were generated, printed, stored, or verified. No GoDaddy connection, FTP upload, or production database operation was performed.

The runtime now fails closed when either required KYC secret is absent or malformed. Production KYC use remains pending private secret configuration and Product Owner verification.

## Exact loader behavior

`includes/kyc_service.php` loads the encryption secret in this order:

1. `GEOROSTER_KYC_ENCRYPTION_KEY` from the process environment.
2. `getKycPrivateConfigDirectory() . '/kyc_key.php'`, where the helper resolves `dirname(__DIR__, 3) . '/georoster-config'`.
3. No fallback. Missing or invalid configuration raises a generic runtime failure and does not encrypt or store a value.

For a production application at `/home/<account>/public_html/geo-roster`, `__DIR__` is `/home/<account>/public_html/geo-roster/includes`. The helper resolves `dirname(__DIR__, 3)` to `/home/<account>`, so the private path is:

`/home/<account>/georoster-config/kyc_key.php`

This is outside `public_html` and is not directly web-served when GoDaddy is configured normally.

The HMAC secret is loaded in the matching order:

1. `GEOROSTER_KYC_HMAC_KEY` from the process environment.
2. `getKycPrivateConfigDirectory() . '/kyc_hmac_key.php'`.
3. No fallback. Missing or invalid configuration raises a generic runtime failure and does not produce a blind index.

## Current accepted representation

### Encryption key

The loader validates the value before calling `hex2bin()`.

- Required production representation: exactly 64 hexadecimal characters.
- Required decoded length: exactly 32 bytes.
- Empty, short, long, non-hex, malformed, or failed `hex2bin()` values are rejected.
- Weak values are not expanded and long values are not truncated.
- Encryption engine: Sodium secretbox when available; otherwise AES-256-GCM.
- No base64 or raw-byte representation should be supplied to the current loader. Use 64 hex characters.

### HMAC key

The loader validates the value before passing the decoded 32-byte key to `hash_hmac('sha256', ...)`.

- Required production representation: exactly 64 hexadecimal characters.
- Required decoded length: exactly 32 bytes.
- Empty, short, long, non-hex, malformed, or failed `hex2bin()` values are rejected.
- Base64 and raw-byte values are rejected.

## Safe templates only

Do not replace placeholders with real values in Git or this document.

### Private encryption file

Create this file outside `public_html` with a real operator-generated secret substituted only on the server. The loader resolves it through `getKycPrivateConfigDirectory()`:

```php
<?php
return '<ENCRYPTION_KEY_HERE>';
```

The placeholder must be replaced with exactly 64 hexadecimal characters. The example above intentionally contains a marker only; do not copy it as a production key. The final production file should return a PHP string containing the 64-character hex value and no output.

A cleaner operator template is:

```php
<?php
return '<64_HEX_ENCRYPTION_KEY_HERE>';
```

### HMAC configuration

Create this file outside `public_html` at `/home/<account>/georoster-config/kyc_hmac_key.php`:

```php
<?php
return '<64_HEX_HMAC_KEY_HERE>';
```

The environment alternative is:

```text
GEOROSTER_KYC_HMAC_KEY=<64_HEX_HMAC_KEY_HERE>
```

The encryption environment alternative is:

```text
GEOROSTER_KYC_ENCRYPTION_KEY=<64_HEX_ENCRYPTION_KEY_HERE>
```

Do not put either value in `config/database.php`, public PHP, SQL, Git, page output, logs, URLs, or MySQL.

## Permissions and placement

- Keep `georoster-config` outside `public_html`.
- Restrict the directory and files to the hosting account/PHP process owner where GoDaddy permits it.
- Do not make the key file world-writable.
- Do not place secrets under `uploads/`.
- Do not email or commit the values.
- Preserve the encryption key permanently; losing it may make encrypted KYC data unrecoverable.
- Keep the HMAC key stable; changing it changes blind-index computation and duplicate detection for future values.
- Key rotation is not part of this release.

## Verification procedure

The Product Owner/operator should verify privately, without printing secret values:

1. Confirm PHP can load the encryption file with a one-time local CLI or hosting diagnostic that checks only `is_string($value)` and `strlen($value) === 64` plus a hexadecimal-format check.
2. Confirm the environment exposes both variables to the same PHP SAPI used by the web application.
3. Confirm no command prints the actual values.
4. Request the private path over HTTP and confirm it is not reachable. A direct request must return 404/403, never PHP source or the returned key.
5. Confirm the public `config/database.php` contains no secret values and remains the production-controlled loader/configuration.
6. Perform a controlled KYC encryption/decryption test only after Product Owner approval; inspect ciphertext presence without recording plaintext in logs.

The current runtime enforces the 64-character checks and fails closed when either value is absent or invalid. It never falls back to a development or static key.

## Non-KYC operations

Login, attendance, payroll, leave, and existing export paths do not require `includes/kyc_service.php` or the KYC secret variables in the current dependency graph. Their database configuration still must remain valid. A KYC secret configuration failure should not inherently take down those ordinary paths, although a global PHP/bootstrap configuration error could affect the whole site.

## Fail-closed assessment

Current implementation: **PASS for code behavior; production configuration remains NOT VERIFIED**.

- Missing encryption key: rejected with a generic error; no encryption proceeds.
- Missing HMAC key: rejected with a generic error; no blind index proceeds.
- Reveal/decryption with missing or wrong key: rejected safely; no plaintext fallback.
- Tampered ciphertext: rejected safely.
- Secret details exposed to end users: no key values or private paths are returned.

## Final pre-FTP checklist

- [ ] Production database backup exists and is verified.
- [ ] Production FTP backup exists and is verified.
- [ ] Migrations 001–004 are verified on the intended production database.
- [ ] Private production DB configuration is preserved.
- [ ] Encryption key is configured privately and its value is not exposed.
- [ ] HMAC key is configured privately and its value is not exposed.
- [ ] Private key configuration is inaccessible through HTTP.
- [ ] All 34 deployment files are verified against `docs/GEOROSTER_GODADDY_RELEASE_CHECKSUMS.md`.
- [ ] No SQL, documentation, dumps, uploads, logs, or backups are included in the FTP payload.
- [ ] Existing GeoRoster and controlled KYC smoke-test checklists are ready.
- [ ] Fail-closed runtime correction has been reviewed and released.

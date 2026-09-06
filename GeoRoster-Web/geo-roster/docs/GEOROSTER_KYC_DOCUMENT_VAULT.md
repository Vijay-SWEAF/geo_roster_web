# GeoRoster Secure KYC Document Vault

## Scope

Prompt 03F adds private, encrypted KYC document storage and audited authenticated streaming. It does not add a mandatory document checklist, deletion UI, retention automation, banking, or production deployment.

## Vault

The vault root is selected from `GEOROSTER_KYC_VAULT_PATH` first. The fallback is `dirname(__DIR__, 3) . '/georoster-kyc-vault'` from `includes/kyc_document_service.php`. For `/home/<account>/public_html/geo-roster/includes`, this resolves to `/home/<account>/georoster-kyc-vault`.

The service fails closed if the root is missing, unreadable, unwritable for upload, not canonicalizable, inside `DOCUMENT_ROOT`, or inside the public application tree. It never falls back to `uploads/`.

Create the production directory manually outside `public_html`, preferably with mode `0700`. Encrypted objects are created with mode `0600` where the hosting filesystem permits it. No key file is stored in the vault.

## Formats and types

Allowed content is PDF, JPEG, or PNG, validated with server-side MIME detection, magic bytes, extension matching, and image dimensions. Maximum plaintext size is 5 MB. Employee photos allow JPEG/PNG only. Document types are the centralized allowlist: PAN_CARD, AADHAAR_CARD, UAN_PROOF, ESIC_CARD, ADDRESS_PROOF, EMPLOYEE_PHOTO, and OTHER_KYC.

Original filenames are encrypted metadata. Physical storage keys are random sharded names and contain no employee, identifier, branch, or document-type data. Dangerous double extensions and unsupported formats are rejected.

## Encryption

Document bytes are encrypted with an authenticated versioned envelope using a document-specific HKDF-SHA256 subkey derived from the existing KYC encryption key. The document HMAC uses a separate HKDF context derived from the existing KYC HMAC key. Wrong keys, tampered bytes, truncated bytes, and malformed envelopes fail closed.

## Metadata and versions

MySQL stores metadata only. Each document has an immutable version and random unique storage key. Replacement creates a new version and marks the previous current version SUPERSEDED. Physical historical objects are never deleted.

Unverified KYC uploads can be ACTIVE/current. VERIFIED KYC requires an active amendment for replacement; those uploads are PENDING_AMENDMENT until Admin amendment approval. Approval promotes them and supersedes the prior current version. Rejection/cancellation marks pending rows rejected/cancelled and leaves the verified version current.

Documents are not required for KYC submission in this phase.

## Authorization and streaming

Admin and active KYC Officers may upload, view, download, and inspect history within current role/branch scope. Regular HO and Branch users receive only a safe managed-by-Officer indicator. Every operation re-queries the current user, active state, role, branch, and KYC Officer permission. Document content is streamed only through POST + CSRF authenticated PHP, never by public URL.

Stream responses use validated MIME, safe generic filenames, `nosniff`, `SAMEORIGIN`, and no-store cache headers. Decrypted bytes are not written to public_html or a decrypted temporary file.

## Auditing and deferred policy

Upload, view, download, promotion, denial, and relevant lifecycle actions are audited without plaintext names, document bytes, identifiers, paths, keys, or ciphertext. No delete control or retention automation is included. Retention remains OWNER / HR / LEGAL POLICY REQUIRED.

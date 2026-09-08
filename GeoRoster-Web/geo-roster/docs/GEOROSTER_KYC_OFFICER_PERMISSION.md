# GeoRoster KYC Officer Permission

## Purpose

KYC Officer is a secondary capability, not a new `users.role_name` value. It allows a selected active HO User or Branch User to perform sensitive KYC operations within the scope already granted by that user's current base role and branch.

Admin has the capability intrinsically and does not need a permission row.

## Data model

Migration 005 creates `user_kyc_permissions` with one unique `KYC_OFFICER` row per user. It stores the active flag, grant/revoke actor, and timestamps. It references `users.user_id` for the target, granting actor, and updating actor. It does not modify existing user rows or `role_name`.

## Authority and scope

Every KYC access request re-queries the current user, active state, role, branch, and KYC Officer permission. Permission is never cached as authority in the session.

- Admin: global KYC access and final actions.
- HO User + KYC Officer: existing HO branch/organizational scope, as currently represented by the live branch assignment.
- Branch User + KYC Officer: current branch only.
- Regular HO/Branch User: status/basic operational visibility, with no sensitive statutory edit or reveal.

Changing a user's branch changes the effective KYC Officer scope immediately. Changing the role contracts the scope to the new role. Deactivation removes all KYC access on the next request. Revocation takes effect immediately without logout.

## Sensitive operations

Admin or active KYC Officer is required for statutory applicability, PAN/Aadhaar/UAN/ESIC edits, sensitive reveal, statutory amendment edits, and sensitive review operations. Server-side checks enforce this policy.

Regular users cannot gain sensitive access by changing POST identifiers or workflow actions. Final KYC Verify/Reject and final amendment approval/rejection remain Admin-only.

## Review queue

Admin sees the global queue. A KYC Officer sees the queue through the existing base-role branch scope. Regular HO and Branch Users are denied the operational review queue. Queue columns remain operational and do not expose sensitive values.

## Grant and revoke

Only an active Admin may grant or revoke. Grant targets must be active `HO User` or `Branch User` accounts. Admin targets are rejected because Admin authority is intrinsic. Grant and revoke use POST + CSRF, update the additive permission row, and write security audit events without sensitive data.

## Masking and reveal

All users see masked/status information only where the existing KYC page permits it. KYC Officers still need the existing explicit POST + CSRF reveal action. Reveals are live-authorized and audited; plaintext values never enter URLs, history metadata, or audit metadata.

## Migration and deployment

Migration 005 is additive and has not been executed against production by this implementation task. Review `database/production/005_PRODUCTION.sql` and `005_VERIFY.sql` separately against the live GoDaddy MariaDB schema before any future execution. No FTP upload or production database change is part of this phase.

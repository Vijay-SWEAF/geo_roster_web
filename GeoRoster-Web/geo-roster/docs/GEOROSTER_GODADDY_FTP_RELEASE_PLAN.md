# GeoRoster GoDaddy FTP Release Plan

## Release gate

This is a release-planning document only. Production database migrations 001–004 are reported as already executed and verified by the Product Owner. This task did not connect to GoDaddy, modify the live database, or upload through FTP.

Local release candidate:

- Branch: `feature/employee-kyc-foundation`
- HEAD: `79eb2f2aae0840aa88639b30118b88c9fa53ed23`
- Prompt 03C implementation commit: `dba97ab51468f3748d13dda3cbde7329cafa29a5`
- Local worktree: contains the pre-existing untracked `godaddyDB/` database-dump directory; it is not part of the FTP release.
- Live baseline compared read-only: `/Users/vijay/Downloads/Projects/GeoRoster_LIVE_2026-09-06:/` (the actual directory has a trailing colon; the requested no-colon path was absent).
- Comparison result: 41 common runtime files, 9 identical, 31 changed application/config files, 4 new deployment-relevant runtime files, and no filtered production-only runtime files. After the comparison, only `includes/kyc_service.php` changed; it remains new in the preserved live baseline and its checksum was regenerated.

The Product Owner must confirm that the trailing-colon directory is the intended fresh GoDaddy FTP download. No upload is authorized until all changed files are reviewed for client customization.

## Baseline comparison procedure

1. Download the complete current GoDaddy application folder to a separate local directory outside this repository.
2. Preserve its file timestamps and permissions where possible.
3. Exclude credentials, uploads, logs, backups, and private configuration from any upload candidate list.
4. Compare the live copy against this Git worktree using paths and content hashes.
5. For every differing file classify the difference as `old application version`, `local production configuration`, `client customization`, or `unknown`.
6. Stop on `client customization` or `unknown`; obtain Product Owner approval before replacing it.
7. Do not use the database dump directory as the live FTP baseline.

## A. MUST DEPLOY

These are the exact changed/new runtime files required to avoid mixing the live older application with the verified hardened/KYC release. They remain subject to Product Owner review for client customization.

### Ordered application upload list

Upload to a staging/temporary FTP location first when GoDaddy supports it. After comparison and approval, publish in this order:

1. `includes/security.php`
2. `includes/auth_check.php`
3. `includes/functions.php`
4. `includes/header.php`
5. `includes/kyc_service.php`
6. `admin/branch_locations.php`
7. `admin/branches.php`
8. `admin/create_user.php`
9. `admin/edit_employee.php`
10. `admin/edit_user.php`
11. `admin/employees.php`
12. `admin/leave_entry.php`
13. `admin/leave_policy.php`
14. `admin/reset_user_password.php`
15. `admin/toggle_employee.php`
16. `admin/toggle_user_status.php`
17. `admin/user_management.php`
18. `attendance_entry.php`
19. `auth/login.php`
20. `change_password.php`
21. `dashboard.php`
22. `export_leave_balance.php`
23. `export_monthly_register.php`
24. `export_payroll.php`
25. `kyc/employee_kyc.php`
26. `kyc/review_queue.php`
27. `leave_balance.php`
28. `logout.php`
29. `management_dashboard.php`
30. `monthly_register.php`
31. `payroll_sheet.php`
32. `profile.php`
33. `save_attendance.php`
34. `update_password.php`

The live baseline is older in all 31 changed application/config files. The changed files include prepared-query, CSRF, session, error-handling, authentication, and KYC integration changes. Uploading only the five KYC-facing files would mix old and new security behavior.

The four new runtime files absent from live are `includes/security.php`, `includes/kyc_service.php`, `kyc/employee_kyc.php`, and `kyc/review_queue.php`.

## B. OPTIONAL / DOCS / DEVELOPMENT ONLY

Do not upload these to the public runtime:

- `docs/GEOROSTER_GODADDY_FTP_RELEASE_PLAN.md`
- `docs/GEOROSTER_FTP_DEPLOYMENT_MANIFEST.md`
- `docs/GEOROSTER_GODADDY_PRODUCTION_DEPLOYMENT_CHECKLIST.md`
- `docs/GEOROSTER_PRODUCTION_MIGRATION_RECOVERY.md`
- `docs/GEOROSTER_PRODUCTION_MIGRATION_SAFETY_REPORT.md`
- all files under `docs/` unless separately approved for a private operator archive
- all files under `database/`
- `godaddyDB/`
- `/tmp` verification files or local test harnesses
- `config/database.example.php`
- `.gitignore`
- `.htaccess` unless separately approved; it is new and not required by the KYC PHP dependency closure
- development-only SQL exports, logs, backups, and test databases

The production migration scripts are operator artifacts only. The database is already migrated; do not upload or execute SQL as part of this FTP release.

## C. ENVIRONMENT-SPECIFIC / NEVER OVERWRITE BLINDLY

Never replace these with local copies:

- `config/database.php` if it contains or loads GoDaddy-specific configuration
- private `../georoster-config/database.php`
- private `../georoster-config/kyc_key.php`
- environment variables and hosting control-panel configuration
- `GEOROSTER_KYC_ENCRYPTION_KEY`
- `GEOROSTER_KYC_HMAC_KEY`
- `.env` files
- `uploads/`
- `error_log` files
- backups and SQL dumps
- client-customized templates, branding, or hosting-specific bootstrap files

`config/database.php` in Git is a loader. Production must retain its private DB host, database name, username, and password outside the public webroot or use GoDaddy environment configuration. Do not upload local credentials.

## Runtime dependency trace

### `kyc/employee_kyc.php`

Direct dependencies:

- `includes/auth_check.php`: session authentication and security headers
- `config/database.php`: MySQL connection and private configuration loader
- `includes/security.php`: POST/CSRF helpers, sessions, audit helper transitively
- `includes/functions.php`: `getBranchName()` and validation helpers
- `includes/kyc_service.php`: all KYC status, encryption, amendment, authorization, duplicate, history, and review logic
- `includes/header.php`: shared page shell, CSS, logo, role display, flash messages
- `includes/footer.php`: shared closing markup and JS assets
- `assets/css/main.css`: page/layout/status/button styling
- `assets/img/geo-roster.png`: header logo
- `assets/js/attendance.js` and `assets/js/management_dashboard.js`: loaded globally by footer; verify compatibility even though this page does not require attendance behavior

### `kyc/review_queue.php`

Uses the same authentication, database, security, functions, KYC service, header/footer, CSS, logo, and globally loaded footer JS closure. Its service query depends on `branches`, `employees`, `employee_kyc`, and `employee_kyc_amendments` tables, which are already reported migrated.

### `includes/kyc_service.php`

Directly requires `includes/security.php`. It also requires the database connection supplied by its callers and uses:

- `getAuthoritativeUser()` against `users`
- employees/branches against `employees` and `branches`
- KYC tables from migrations 002–004
- `auditEvent()` from `security.php`, which writes `security_audit_log`
- `validPositiveInt()`, `validDateValue()`, and related helpers from `security.php`
- production `GEOROSTER_KYC_ENCRYPTION_KEY` and `GEOROSTER_KYC_HMAC_KEY`

### `admin/employees.php`

Requires `includes/auth_check.php`, `config/database.php`, `includes/security.php`, `includes/header.php`, `includes/footer.php`, and the `employees`, `branches`, and `branch_locations` tables. It links to `kyc/employee_kyc.php`; its hardened version also exposes KYC status/action links.

### `dashboard.php`

Requires `includes/auth_check.php`, `includes/header.php`, `includes/footer.php`, and links to the review queue. Its current role-specific navigation must match the deployed KYC route.

### CSS/JS classification

No KYC-specific JavaScript bundle is required by the current pages. `main.css`, logo, and the two footer-loaded JS files are shared application dependencies and should be compared, not automatically overwritten. `assets/css/style.css` is empty in the local workspace and is not a required KYC dependency.

## Live-difference classification

The actual trailing-colon live baseline was compared by hash. The 31 changed application/config files are classified as the older live application version versus the hardened Git release, subject to manual client-customization review. The live `config/database.php` is classified as environment-specific and must remain live. The four new KYC/security runtime files are classified as NEW FILE / MUST DEPLOY. No filtered production-only runtime files were found.

- `local production configuration`: database loader, private config, keys, environment files
- `old application version`: runtime file differs and lacks the committed hardened/KYC behavior
- `client customization`: branding, templates, wording, or business-specific changes not present in Git
- `unknown`: any unexplained difference or missing provenance

Only old-version files with no client customization may be replaced after approval. `client customization` and `unknown` require manual merge/review. The exact evidence is recorded in `docs/GEOROSTER_GODADDY_LIVE_DIFF_REPORT.md`.

## Production secrets

The runtime requires:

- `GEOROSTER_KYC_ENCRYPTION_KEY`: 64-character hex key or approved equivalent accepted by the existing loader. Do not generate or print a production key here.
- `GEOROSTER_KYC_HMAC_KEY`: private HMAC secret used for blind indexes. Do not generate or print a production key here.

Load both through GoDaddy's private environment/configuration facility outside the public webroot, or through an untracked private configuration mechanism protected from web access. Keep the same values stable for existing encrypted data and blind indexes. Do not store either value in Git, SQL, page source, URLs, logs, or MySQL.

## FTP upload order

1. Product Owner confirms `/Users/vijay/Downloads/Projects/GeoRoster_LIVE_2026-09-06:/` is the intended backup.
2. Back up the complete live FTP folder locally.
3. Resolve every client-customized/unknown difference.
4. Confirm migrations 001–004 are complete; do not run SQL from this task.
5. Confirm private DB/encryption/HMAC configuration is present and unchanged.
6. Upload `includes/security.php`.
7. Upload `includes/auth_check.php`.
8. Upload `includes/functions.php`.
9. Upload `includes/header.php`.
10. Upload `includes/kyc_service.php`.
11. Upload the `admin/*.php` files listed above, in listed order.
12. Upload `attendance_entry.php`, `auth/login.php`, `change_password.php`, and `dashboard.php`.
13. Upload the export, KYC, leave, logout, management, payroll, profile, attendance-save, and password-update files listed above, in listed order.
14. Do not upload identical CSS, JS, logo, footer, or index files.
15. Clear approved PHP opcode/cache if required by GoDaddy.
16. Run the smoke-test order below.
17. Keep the previous FTP backup until production approval is complete.

## Smoke-test order

Run read-only/non-destructive checks first. Use a controlled employee and approved synthetic/non-sensitive values only.

1. Login and logout for Admin, HO User, and Branch User.
2. Admin dashboard, employee master, branch master, sub-location master, and user management.
3. Branch User sees only permitted branch employees; confirm branch isolation.
4. Attendance current branch/date load; do not create destructive test attendance.
5. Monthly register, payroll sheet, leave balance, and management dashboard.
6. Monthly register, payroll, and leave exports; confirm no KYC fields appear.
7. KYC status/action link on Employee Master.
8. Start KYC draft and save basic fields.
9. Test applicability controls and approved statutory handling with controlled data only.
10. Confirm masked values and audited reveal permissions.
11. Submit initial KYC, start review, Admin verify, and confirm verified lock.
12. Open Admin/HO review queue and confirm safe columns only.
13. Branch User requests an amendment for an own-branch verified employee.
14. Edit basic amendment fields; confirm Branch User cannot edit statutory values.
15. Submit amendment; HO starts review; confirm HO cannot final approve/reject.
16. Admin approves one controlled amendment and confirm KYC remains VERIFIED.
17. Repeat with controlled rejection, revision, cancellation, and one-active-amendment checks if business approval permits.
18. Confirm no sensitive values appear in queue HTML, URLs, logs, or history metadata.

## Stop conditions

Stop and do not upload if the live FTP copy is unavailable, a production file differs with unknown/client customization, private configuration would be overwritten, required shared dependency versions cannot be established, KYC secrets are not privately configured, or any smoke test fails.

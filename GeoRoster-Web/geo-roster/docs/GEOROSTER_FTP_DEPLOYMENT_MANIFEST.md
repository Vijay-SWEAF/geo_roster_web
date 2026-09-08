# GeoRoster FTP Deployment Manifest

## Status

`LIVE BASELINE COMPARISON COMPLETE - FTP DEPLOYMENT NOT AUTHORIZED`

Source of truth:

- Runtime release commit: `79eb2f2aae0840aa88639b30118b88c9fa53ed23`
- Live baseline compared read-only: `/Users/vijay/Downloads/Projects/GeoRoster_LIVE_2026-09-06:/`
- Comparison report: `docs/GEOROSTER_GODADDY_LIVE_DIFF_REPORT.md`
- Release plan: `docs/GEOROSTER_GODADDY_FTP_RELEASE_PLAN.md`

The requested no-colon live path was absent; the available trailing-colon directory was used and must be confirmed by the Product Owner before any upload. The original comparison found 9 identical common files, 31 changed application/config files, and 4 new deployment-relevant runtime files. After that comparison, only `includes/kyc_service.php` changed; the preserved live baseline still lacks that new file, so the live diff remains valid for this runtime change.

## Exact MUST DEPLOY list

These 34 runtime files are the exact ordered list from the reconciled release plan. They represent the hardened application and KYC dependency closure; do not upload only the five KYC-facing files.

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

Every path above was cross-checked against the development workspace and the live baseline. The four new runtime files absent from live are:

- `includes/security.php`
- `includes/kyc_service.php`
- `kyc/employee_kyc.php`
- `kyc/review_queue.php`

## Identical / DO NOT DEPLOY

These files are byte-identical in both trees and should remain live:

- `assets/css/dashboard.css`
- `assets/css/main.css`
- `assets/css/style.css`
- `assets/img/SWEAF_R_Logo.png`
- `assets/img/geo-roster.png`
- `assets/js/attendance.js`
- `assets/js/management_dashboard.js`
- `includes/footer.php`
- `index.php`

## Environment-specific / KEEP LIVE

`config/database.php` = **ENVIRONMENT-SPECIFIC / DO NOT OVERWRITE BLINDLY**.

The live file contains GoDaddy database configuration. Never replace it with the development copy. Preserve or manually merge only after a credential-safe review.

Also keep production-controlled and never overwrite blindly:

- private `../georoster-config/database.php`
- private `../georoster-config/kyc_key.php`
- `GEOROSTER_DB_HOST`, `GEOROSTER_DB_NAME`, `GEOROSTER_DB_USER`, `GEOROSTER_DB_PASSWORD`
- `.env` files and hosting control-panel configuration
- `uploads/`
- error logs
- backups and SQL dumps
- client-customized branding/templates

## New or development-only files not for public deployment

Do not upload:

- `.gitignore`
- `.htaccess` without separate Product Owner approval
- `config/database.example.php`
- all files under `database/`
- all files under `docs/`
- `godaddyDB/`
- local test harnesses or temporary files

No SQL migration packs, documentation, logs, uploads, backups, database dumps, or local configuration files belong in the public FTP release.

## Production KYC secret prerequisites

Before any KYC use, GoDaddy must privately configure:

- `GEOROSTER_KYC_ENCRYPTION_KEY`
- `GEOROSTER_KYC_HMAC_KEY`

Production secret values were not generated, printed, stored, or verified by this task. Load them through GoDaddy private environment configuration or an untracked private file outside the public webroot. Keep the values stable for encrypted KYC data and blind indexes. Never store them in Git, SQL, MySQL, URLs, page source, or logs.

## Upload order

1. Confirm the trailing-colon live directory is the intended baseline.
2. Back up the complete live FTP folder.
3. Review all changed files for client customizations or unknown differences.
4. Confirm migrations 001–004 are already complete; do not run SQL from this manifest.
5. Confirm production database configuration and both KYC secrets are present and unchanged.
6. Upload the 34 MUST DEPLOY files in the exact order listed above.
7. Do not upload identical files, environment-specific files, SQL, docs, logs, uploads, backups, or database dumps.
8. Run the approved production smoke-test checklist.

## Final gate

- Production KYC secrets configured: `NO / NOT VERIFIED`
- FTP deployment authorized: `NO`
- FTP deployment performed: `NO`
- Live FTP modified: `NO`
- Production database modified: `NO`

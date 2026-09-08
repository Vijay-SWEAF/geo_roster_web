# GeoRoster GoDaddy Live FTP Baseline Diff Report

## Comparison scope

- Requested live path: `/Users/vijay/Downloads/Projects/GeoRoster_LIVE_2026-09-06/` (not present).
- Actual available baseline used read-only: `/Users/vijay/Downloads/Projects/GeoRoster_LIVE_2026-09-06:/` (trailing colon is part of the directory name).
- Development path: `/Users/vijay/Downloads/Projects/geo-roster/`.
- Development runtime release commit: `79eb2f2aae0840aa88639b30118b88c9fa53ed23`.
- Comparison method: relative path inventory, SHA-256 hashes, file sizes, and targeted content diff.
- Live baseline modification: none.
- Development tree modification during comparison: none except this report/release-plan documentation.

After the original comparison, only `includes/kyc_service.php` changed. A read-only post-fix check against the preserved live baseline confirmed that the file is still absent from live as expected for the NEW FILE classification. No other deployment runtime file changed.

The supplied expected path and the actual trailing-colon path are not identical. The Product Owner should confirm that the trailing-colon directory is the intended fresh GoDaddy FTP download before upload.

## Inventory

Deployment comparison excluded `.git`, `docs`, `database`, `godaddyDB`, `uploads`, logs, SQL files, backups, and `.DS_Store` from the runtime hash set.

- Live runtime comparison files: 41
- Development runtime comparison files: 48
- Common files: 41
- Identical common files: 9
- Changed common files: 32 before excluding `.DS_Store`; 31 application/config files
- Development-only files: 7, including four deployment-relevant new runtime files and three local metadata/config files
- Production-only runtime files: none in the filtered set

## Identical files

These common files have identical SHA-256 content and do not require deployment:

- `assets/css/dashboard.css`
- `assets/css/main.css`
- `assets/css/style.css`
- `assets/img/SWEAF_R_Logo.png`
- `assets/img/geo-roster.png`
- `assets/js/attendance.js`
- `assets/js/management_dashboard.js`
- `includes/footer.php`
- `index.php`

## Changed files

The live copy is older/different for all of the following application files. The content review shows the development versions contain the hardened prepared-query, CSRF, validation, security-header, error-handling, authentication, KYC-link, or operational hardening changes needed for the verified release. These are the exact runtime files in the MUST DEPLOY set, subject to Product Owner approval for any client customization found during review:

- `admin/branch_locations.php`
- `admin/branches.php`
- `admin/create_user.php`
- `admin/edit_employee.php`
- `admin/edit_user.php`
- `admin/employees.php`
- `admin/leave_entry.php`
- `admin/leave_policy.php`
- `admin/reset_user_password.php`
- `admin/toggle_employee.php`
- `admin/toggle_user_status.php`
- `admin/user_management.php`
- `attendance_entry.php`
- `auth/login.php`
- `change_password.php`
- `dashboard.php`
- `export_leave_balance.php`
- `export_monthly_register.php`
- `export_payroll.php`
- `includes/auth_check.php`
- `includes/functions.php`
- `includes/header.php`
- `leave_balance.php`
- `logout.php`
- `management_dashboard.php`
- `monthly_register.php`
- `payroll_sheet.php`
- `profile.php`
- `save_attendance.php`
- `update_password.php`

These files must be treated as one hardened application release. Uploading only the five obvious KYC files would mix new KYC code with old authentication, CSRF, helper, layout, and operational code.

## New files

New in development and absent from the live baseline:

### MUST DEPLOY after schema verification

- `includes/security.php`
- `includes/kyc_service.php`
- `kyc/employee_kyc.php`
- `kyc/review_queue.php`

### Do not deploy

- `.gitignore`
- `.htaccess` requires explicit Product Owner review because it is absent from the live baseline and contains hosting/path behavior.
- `config/database.example.php`

The KYC page files require migrations 001–004, which the Product Owner reports are already executed and verified.

## Production-only and excluded files

No production-only application file appeared in the filtered runtime set. The live baseline contains these excluded artifacts and they must remain untouched:

- root `error_log`
- `admin/error_log`
- `auth/error_log`
- `uploads/` and user files
- `.DS_Store`

Do not delete or replace excluded artifacts as part of this release. The development tree also contains SQL migrations/production packs and `godaddyDB/` database dumps; none are FTP upload candidates.

## Environment-specific files

### `config/database.php`

The live and development files differ materially. The live file contains production database values; the development file is a private-config/environment loader. Never overwrite the live file with the development file. Keep the live production configuration or manually merge only the hardened error-handling/loader behavior after a credential-safe review.

### Private secrets/configuration

Never upload or overwrite:

- private `../georoster-config/database.php`
- private `../georoster-config/kyc_key.php`
- `.env` files
- GoDaddy environment variables
- `GEOROSTER_KYC_ENCRYPTION_KEY`
- `GEOROSTER_KYC_HMAC_KEY`
- uploads, logs, backups, or database dumps

The KYC service requires stable production encryption and HMAC secrets. The values must be configured privately through GoDaddy environment/private configuration. Do not generate, print, commit, or store them in MySQL.

## Client customization differences

- `config/database.php` is definitively production-specific and must be kept live.
- The live shared PHP files may contain client customizations not visible from the targeted hardening diff. The live header/footer and logos are the branding surface; the logo assets are byte-identical, while `includes/header.php` differs only in the security initialization in the inspected portion. Preserve any additional live branding/customization discovered in the complete review.
- No logo asset differences were found: `assets/img/geo-roster.png` and `assets/img/SWEAF_R_Logo.png` are identical.
- No live-vs-development differences were found in CSS or shared JavaScript assets.
- Any difference not explained by the hardened Git version must be classified as `client customization` or `unknown` and reviewed before replacement.

## Exact deployment manifest

### MUST DEPLOY, in dependency-safe order

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

The list is exact for the current comparison, but every file still requires a final human review for client customizations before upload.

### KEEP LIVE / DO NOT OVERWRITE

- `config/database.php`
- private configuration and secret files
- `uploads/`
- all logs
- all backups and SQL dumps
- `assets/css/dashboard.css`
- `assets/css/main.css`
- `assets/css/style.css`
- `assets/img/SWEAF_R_Logo.png`
- `assets/img/geo-roster.png`
- `assets/js/attendance.js`
- `assets/js/management_dashboard.js`
- `includes/footer.php`
- `index.php`

The identical assets and shared files do not need upload. Keep them live to minimize FTP changes.

### Requires Product Owner review

- Confirm the trailing-colon live path is the intended backup.
- Review all 31 changed common application/config files against client customizations.
- Decide whether the hardened `config/database.php` loader/error handling should be manually merged without exposing production credentials; do not overwrite blindly.
- Decide whether `.htaccess` should be installed; it is new and currently excluded from MUST DEPLOY.
- Confirm PHP version and GoDaddy path/session behavior support `includes/security.php`.
- Confirm KYC secrets are configured privately and stable before enabling KYC pages.
- Confirm the production migration verification evidence corresponds to this same database.

## Final classification

- Production KYC secrets configured: `NO / NOT VERIFIED` from this file comparison.
- FTP deployment authorized: `NO`.
- Live FTP modified: `NO`.
- Production database modified by this task: `NO`.

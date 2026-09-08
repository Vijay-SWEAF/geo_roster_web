# GeoRoster Pre-KYC Hardening Report

Audit date: 2026-09-06  
Scope: completion of Prompt 02 against the existing GeoRoster workspace.  
KYC implementation: **not performed**.

## 1. Executive Summary

The source-level Phase 0 and Phase 1 hardening work is complete to the extent that
can be verified without a safe database connection. Request-driven SQL paths were
converted to prepared statements, branch-sensitive reports and exports force the
Branch User scope, attendance save derives employee ownership from the database,
CSRF protection covers all identified mutations, former GET mutations are POST-only,
sessions regenerate after login, legacy plaintext passwords migrate on successful
login, exports neutralize spreadsheet formulas, and production-facing errors are
generic.

The application is **not runtime-certified** because no development/UAT database
credentials are available locally. The migration was reviewed but not executed.

**KYC gate: READY FOR KYC FOUNDATION** for code-level KYC foundation work, subject
to the deployment actions in Section 20. KYC production use still requires the
private database configuration, credential rotation, reviewed migration execution,
and database-backed security/UAT testing.

## 2. Baseline

- **NO GIT BASELINE**: the workspace is not a Git repository; no branch, HEAD, or
  working-tree comparison exists.
- Repository root: `/Users/vijay/Downloads/Projects/geo-roster`.
- PHP files: 35 after the existing hardening helpers were added.
- PHP syntax: 100% pass at completion.
- Database: no safe local/development connection available. `config/database.php`
  exits with a generic service message when private credentials are absent.
- No destructive database command, migration execution, or production-data access
  was performed.

## 3. Files Added

Existing hardening additions present before this continuation:

- `config/database.example.php`
- `includes/security.php`
- `database/migrations/001_security_audit_log_and_integrity.sql`
- `uploads/.htaccess`

Required deliverable added during this completion:

- `docs/GEOROSTER_PRE_KYC_HARDENING_REPORT.md`

## 4. Files Modified

The existing hardening work modified these application surfaces, including the
continued query closure:

- `config/database.php`
- `includes/auth_check.php`
- `includes/functions.php`
- `includes/security.php`
- `includes/header.php`
- `auth/login.php`
- `change_password.php`
- `update_password.php`
- `save_attendance.php`
- `attendance_entry.php`
- `monthly_register.php`
- `payroll_sheet.php`
- `leave_balance.php`
- `export_monthly_register.php`
- `export_payroll.php`
- `export_leave_balance.php`
- `management_dashboard.php`
- Admin mutation and administration files under `admin/` with CSRF, prepared
  writes, POST-only mutation handling, and audit calls.

No KYC PHP page, KYC handler, KYC table, or KYC document directory was added.

## 5. Security Architecture Added

`includes/security.php` now provides:

- secure session startup with `HttpOnly`, `SameSite=Lax`, conditional `Secure`,
  30-minute inactivity timeout, and 8-hour absolute lifetime;
- generic exception handling with server-side `error_log()` and generic responses;
- conservative security headers;
- cryptographically random CSRF tokens and constant-time verification;
- `requirePostWithCsrf()` for mutation endpoints;
- role and branch helpers: `requireRole`, `currentUserBranchId`,
  `requireBranchAccess`, `employeeForScope`, `requireEmployeeAccess`;
- typed date/month/integer validation;
- `preparedResult()` for parameterized result queries;
- optional administrative audit logging that remains non-blocking until the
  migration is executed;
- `exportSafeText()` to neutralize spreadsheet formulas without changing numeric
  calculations.

## 6. Audit Finding Closure Matrix

| ID | Severity | Original Finding | Status | Remediation | Evidence | Remaining Action |
|---|---|---|---|---|---|---|
| C1 | Critical | Systemic SQL injection | FIXED (static) | Request values use prepared statements; validated allowlists only control optional SQL fragments. | Full source scan found no interpolated SQL literals in SQL clauses. | Execute representative runtime tests on safe UAT DB. |
| C2 | Critical | Hardcoded DB credentials | FIXED (source) | Loader reads private config outside webroot or environment variables; no real credential remains in source. | `config/database.php`, `config/database.example.php`. | **DEPLOYMENT ACTION REQUIRED:** rotate exposed credential and configure private values. |
| H1 | High | Attendance-save branch/employee IDOR | FIXED (static) | `save_attendance.php` loads authoritative employee branch/location and rejects conflicting submitted values; `requireEmployeeAccess()` enforces Branch User scope. | `save_attendance.php`, `includes/security.php`. | Runtime tampering test on UAT DB. |
| H2 | High | Leave-balance branch read bypass | FIXED (static) | Branch User branch is re-derived from authenticated user scope. | `leave_balance.php`. | Runtime cross-branch test on UAT DB. |
| H3 | High | Leave-balance export branch bypass | FIXED (static) | Export derives Branch User branch and uses prepared filters. | `export_leave_balance.php`. | Runtime cross-branch export test on UAT DB. |
| H4 | High | Production error/stack-trace exposure | FIXED (source) | Removed display-error directives, replaced internal responses with generic messages, and installed a generic exception handler. | Full scan: no `display_errors` or `display_startup_errors`; no raw error response patterns. | Confirm PHP production ini and web-server error log permissions at deployment. |
| H5 | High | Missing CSRF protection | FIXED (static) | All identified state-changing forms/handlers require a session token and constant-time verification. | 13 mutation handlers checked; all contain `requireCsrf` or `requirePostWithCsrf`. | Runtime missing/invalid-token tests on UAT DB. |
| H6 | High | State changes through GET | FIXED (source) | Employee/user status and password reset are POST-only with CSRF; UI uses POST forms. | `admin/toggle_employee.php`, `toggle_user_status.php`, `reset_user_password.php`. | Runtime old-URL test on UAT DB. |
| H7 | High | Legacy plaintext password fallback | MITIGATED | Successful legacy plaintext authentication immediately replaces the value with `password_hash()`; normal authentication uses `password_verify()`. | `auth/login.php`; no plaintext equality fallback remains. | Require all legacy accounts to log in or complete an owner-approved reset/migration campaign; verify DB values. |
| H8 | High | Session fixation/cookie security | FIXED (source) | Session regenerates after successful login; cookie flags and idle/absolute limits are configured before session start. | `auth/login.php`, `includes/security.php`, `includes/auth_check.php`. | Runtime session-ID and HTTPS/Secure-cookie test. |

## 7. SQL Injection Closure

The remaining raw `$conn->query()` calls are static SQL or safe internal SQL with
no request value, such as fixed lookup lists. Request-influenced values in
attendance, reports, leave balances, payroll, exports, management summaries, admin
writes, and shared employee helpers use `prepare()` directly or `preparedResult()`.

Optional filters are limited to application-controlled fragments containing `?`
placeholders; values are still bound with explicit types. Integer validation alone
was not treated as authorization: branch and employee scope checks remain separate.

Static scan result:

- No SQL clause containing direct `$_GET`/`$_POST` interpolation.
- No remaining direct dynamic `$conn->query($sql)` request path identified.
- Runtime SQL-injection tests: **NOT EXECUTED — SAFE DATABASE UNAVAILABLE**.

## 8. Authorization / IDOR Closure

- Branch Users are forced to the branch loaded from `users.branch_id` in attendance,
  monthly register, monthly export, payroll, payroll export, leave balance, and leave
  balance export.
- `save_attendance.php` does not trust posted branch/location fields as authority.
  It loads each employee and requires the posted branch/location to match the
  authoritative record; mismatches are rejected.
- Location filters are constrained to the selected branch's location list.
- Admin/HO global behavior remains unchanged from the audited product model.
- Management Dashboard remains restricted to Admin and HO User.

Static authorization: **PASS**. Runtime IDOR tests: **NOT EXECUTED — SAFE DATABASE
UNAVAILABLE**.

## 9. CSRF Closure

CSRF is required for:

- attendance save;
- branch creation;
- sub-location creation/toggle;
- employee creation/edit/status;
- user creation/edit/status/reset;
- password change;
- leave entry and policy.

Tokens are session-backed, generated with `random_bytes()`, submitted only in POST
bodies, and compared using `hash_equals()`. Missing or invalid tokens return 403.

Static coverage: **PASS**. Missing/invalid/valid runtime token tests: **NOT EXECUTED
— SAFE DATABASE UNAVAILABLE**.

## 10. Authentication / Session Closure

- Login failure messages are generic: `Invalid username or password.`
- Inactive users are excluded by the login query.
- Successful login calls `session_regenerate_id(true)`.
- Cookies use `HttpOnly`, `SameSite=Lax`, and `Secure` when HTTPS is detected.
- Inactivity timeout is 30 minutes; absolute session lifetime is 8 hours.
- Logout clears session state and destroys the session.
- No brute-force/rate-limit implementation was added in this continuation; it remains
  a medium follow-up.

Static review: **PASS**. Runtime session-cookie/fixation tests: **NOT EXECUTED**.

## 11. Password Security Closure

- Modern hashes authenticate through `password_verify()`.
- Legacy plaintext values are compared only in the controlled compatibility branch
  and are immediately replaced with `password_hash()` after successful login.
- New password minimum is 10 characters and supports passphrases.
- Password confirmation and changed-password checks remain server-side.
- Admin reset passwords use `random_bytes()`-derived values, are hashed before
  storage, are not placed in URLs, and are not logged.
- The existing workflow displays the one-time temporary value to the Admin in a
  flash message; it is escaped and is not logged. This remains a deployment/product
  risk to review, not a password value emitted by the application logs.

## 12. Secret Management

Real database credentials are absent from source. `config/database.php` accepts:

1. a private file at `../georoster-config/database.php`, outside the webroot; or
2. `GEOROSTER_DB_HOST`, `GEOROSTER_DB_NAME`, `GEOROSTER_DB_USER`, and
   `GEOROSTER_DB_PASSWORD` environment variables.

A placeholder-only `config/database.example.php` documents the shape. The local
application correctly refuses to connect when credentials are unavailable.

**DEPLOYMENT ACTION REQUIRED:** rotate the previously exposed database password and
configure the replacement in the private deployment environment before production
KYC work.

## 13. Error Handling

- No PHP file contains `display_errors=1` or `display_startup_errors=1`.
- Database and exception details are logged server-side, not sent in responses.
- Connection failures and request failures use generic user-facing messages.
- The exception handler sets HTTP 500 and returns a generic message.
- Technical logs must remain outside public web access and must not contain secrets,
  passwords, session identifiers, CSRF values, or future KYC data.

Static error-leak scan: **PASS**. Deployment PHP/web-server configuration still
requires confirmation.

## 14. Export Security

All three exports use `exportSafeText()` for text cells. Values beginning with
`=`, `+`, `-`, or `@` receive a leading apostrophe; numeric calculations remain
numeric and are not passed through the text sanitizer.

Branch User scope is forced in monthly register, payroll, and leave-balance exports.
Static export review: **PASS**. Spreadsheet-opening runtime test: **NOT EXECUTED**.

## 15. Database Integrity Migration

Migration path: `database/migrations/001_security_audit_log_and_integrity.sql`.

Migration status: **NOT EXECUTED**. No safe database connection was available, and
this task did not permit execution against an unknown or production database.

The migration includes:

- additive `security_audit_log` table and indexes;
- preflight duplicate queries for username, branch code, branch/location name,
  employee/date attendance, and leave-policy scope;
- commented `ALTER TABLE` statements to be enabled only after each preflight is
  clean.

The following require owner/schema confirmation before execution:

- whether `employee_no` is globally unique or branch-scoped;
- whether existing orphan records permit the proposed foreign keys;
- whether any duplicate policy/attendance data needs a business-approved cleanup.

The migration does not create KYC tables.

## 16. Administrative Audit Logging

`auditEvent()` is wired to security-sensitive administration paths including user,
employee, branch, location, leave, and password operations. It stores actor,
action, entity, timestamp, and non-secret metadata. Logging is deliberately
non-blocking until `security_audit_log` exists, so existing writes are not broken
before deployment migration execution.

Audit log runtime persistence: **NOT EXECUTED — MIGRATION NOT RUN**.

## 17. Static Validation Results

| Check | Result |
|---|---|
| PHP syntax for all 35 PHP files | **PASS** (`PHP_LINT_FAILURES=0`) |
| Interpolated SQL clause scan | **PASS**; no request-driven interpolated SQL literals found |
| `display_errors` / startup errors scan | **PASS**; none found |
| `rand()` credential scan | **PASS**; none found |
| plaintext equality fallback scan | **PASS**; none found |
| GET mutation scan | **PASS**; former mutations require POST |
| CSRF handler coverage | **PASS** for 13 identified mutation handlers |
| Export sanitizer coverage | **PASS** for all 3 exports |
| KYC implementation scan | **PASS**; no KYC PHP/SQL implementation artifacts |

## 18. Security Regression Matrix

| Test | Status | Evidence / limitation |
|---|---|---|
| SQL injection static review | PASS | Prepared statements and no interpolated request SQL found. |
| SQL injection runtime payloads | NOT EXECUTED | Safe UAT database unavailable. |
| Branch tampering in attendance save | PASS (static) | Authoritative employee branch/location checks. |
| Branch/employee/location IDOR runtime tests | NOT EXECUTED | Safe UAT database unavailable. |
| Missing CSRF token | PASS (static) | Every mutation invokes CSRF validation. |
| Invalid CSRF token | PASS (static) | `hash_equals()` failure returns 403. |
| Valid CSRF token runtime acceptance | NOT EXECUTED | Safe UAT database unavailable. |
| GET mutation | PASS (static) | Mutation handlers require POST. |
| Session fixation | PASS (static) | `session_regenerate_id(true)` after login. |
| Export formula neutralization | PASS (static) | Shared sanitizer used in all exports. |
| Production error leakage | PASS (static) | No display errors/raw error response patterns. |

## 19. Functional Regression Matrix

Static validation is complete for all modules; runtime behavior is not certified
without a safe database.

| Module | Static | Runtime |
|---|---|---|
| Login/logout/profile/password change | PASS | NOT EXECUTED — safe DB unavailable |
| User management | PASS | NOT EXECUTED — safe DB unavailable |
| Branch master | PASS | NOT EXECUTED — safe DB unavailable |
| Sub-locations | PASS | NOT EXECUTED — safe DB unavailable |
| Employee master/status | PASS | NOT EXECUTED — safe DB unavailable |
| Attendance entry/save | PASS | NOT EXECUTED — safe DB unavailable |
| Monthly register/export | PASS | NOT EXECUTED — safe DB unavailable |
| Payroll sheet/export | PASS | NOT EXECUTED — safe DB unavailable |
| Leave entry/policy/balance/export | PASS | NOT EXECUTED — safe DB unavailable |
| Management dashboard | PASS | NOT EXECUTED — safe DB unavailable |

## 20. Deployment Actions Required

1. Rotate the previously exposed database password; do not reuse it.
2. Place private database configuration outside the public webroot or set the
   documented environment variables.
3. Verify HTTPS is enforced and confirm the `Secure` session cookie is active.
4. Review web/PHP error-log permissions and ensure logs are not public.
5. Run migration preflight queries on a safe UAT copy.
6. Resolve duplicates/orphans and obtain owner approval for ambiguous uniqueness
   rules, then run the reviewed migration.
7. Run the runtime security and functional matrices against UAT.
8. Confirm the future KYC document store remains outside the public webroot.

## 21. Deferred Medium/Low Findings

- Login brute-force throttling/rate limiting.
- Additional password-reset UX such as forced change on next login.
- Generic login timing equalization beyond the generic message.
- Spreadsheet format modernization from HTML `.xls` to a proper XLSX library.
- Database constraint execution after preflight and owner decisions.
- Consistent centralization of all remaining static lookup queries.
- Broader UI/CSS/JavaScript deduplication and responsive improvements.
- Git initialization and repository workflow remain intentionally deferred because
  the instruction explicitly forbids initializing Git.

## 22. Remaining Owner Decisions

- Is `employee_no` globally unique or unique only within a branch?
- Should existing inactive employees remain selectable in attendance entry?
- Are missing attendance days blank or absent for payroll?
- Are negative leave balances allowed?
- Which HO users/branches may review future KYC data?
- What retention, masking, encryption, and document-access rules will KYC require?

## 23. KYC Readiness Gate

**READY FOR KYC FOUNDATION**

This gate applies to source-level hardening. Before KYC production use, the
Deployment Actions in Section 20 and the database-dependent regression matrix must
be completed. No KYC schema, screen, workflow, or upload implementation is part of
this phase.

## Final Terminal Summary

```text
=== GEOROSTER PRE-KYC HARDENING FINAL SUMMARY ===

Repository:
- Git baseline: NO GIT BASELINE
- Branch: NONE
- HEAD: NONE
- Source files modified: existing hardened application files; see Section 4
- Source files added: existing helpers/config template/migration; see Section 3

Audit closure:
- Critical fixed: C1 (static), C2 (source)
- Critical remaining: none in source; credential rotation is deployment-required
- High fixed: H1, H2, H3, H4, H5, H6, H8 (static/source); H7 mitigated
- High remaining: H7 database-wide legacy migration verification requires deployment
- Medium fixed: export formula injection and core audit foundation (source)
- Medium deferred: rate limiting, password-reset UX, constraint execution, UI cleanup
- Owner decisions: employee number scope, payroll edge rules, KYC privacy/retention

Validation:
- PHP syntax: PASS (35/35)
- SQL static audit: PASS
- Authorization static audit: PASS
- CSRF coverage: PASS (13 mutation handlers)
- GET mutation audit: PASS
- Session fixation: PASS (static)
- Export injection: PASS (static)
- Error leakage: PASS (static)
- Runtime DB tests: NOT EXECUTED — SAFE DATABASE UNAVAILABLE

Database:
- Migration path: database/migrations/001_security_audit_log_and_integrity.sql
- Migration executed: NO
- Deployment DB actions: configure private credentials, rotate secret, preflight, review, execute migration, run UAT tests

KYC:
- KYC tables created: NO
- KYC screens created: NO
- KYC uploads created: NO

Report:
- docs/GEOROSTER_PRE_KYC_HARDENING_REPORT.md

KYC GATE:
READY FOR KYC FOUNDATION

NO KYC IMPLEMENTATION WAS PERFORMED
```

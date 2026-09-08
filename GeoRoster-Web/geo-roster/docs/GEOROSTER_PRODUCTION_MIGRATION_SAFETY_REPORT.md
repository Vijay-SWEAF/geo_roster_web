# GeoRoster Production Migration Safety Report

## 1. Executive Assessment

This pack prepares, but does not execute, GoDaddy production migration and FTP steps. The current local commit is `dba97ab51468f3748d13dda3cbde7329cafa29a5` on `feature/employee-kyc-foundation`; the worktree was clean at preparation start. No GoDaddy database or FTP connection was used.

Migration 001 has the highest production risk because its development file documents optional uniqueness changes to existing legacy tables. The production script leaves those statements commented. Migrations 002–004 are additive KYC/security table creation, but still require preflight checks because `IF NOT EXISTS` does not validate an existing object with the intended schema and foreign keys depend on the live legacy schema.

## 2. Migration 001 Risk

Statements: one `CREATE TABLE IF NOT EXISTS security_audit_log` with indexes and a foreign key to `users`; optional commented `ALTER TABLE ... ADD UNIQUE KEY` statements for users, branches, branch locations, attendance, and leave policy.

Existing tables affected: only if an operator separately enables the optional ALTER statements. Potential conflicts are duplicate usernames, duplicate branch codes, duplicate branch/location pairs, duplicate employee/date attendance rows, duplicate leave-policy scopes, incompatible collations/types, and orphan references. No existing rows are modified by the active CREATE statement. Production prerequisite: read-only preflight, zero duplicate/orphan findings, schema compatibility, and explicit owner approval for each optional uniqueness change.

### Migration statement risk table

| Migration | Statement/object | Classification | Existing/new object | Risk | Data impact | Production prerequisite |
|---|---|---|---|---|---|---|
| 001 | `security_audit_log` | CREATE NEW TABLE | New | Medium: FK/JSON/engine compatibility | No existing rows | Confirm `users(user_id)` and exact object absence/schema |
| 001 | Audit indexes | CREATE INDEX | New table | Low | No existing rows | Created with the new table |
| 001 | Actor FK | FOREIGN KEY | New table to existing `users` | Medium | No existing rows | Confirm parent key/type and engine compatibility |
| 001 | Optional legacy uniqueness ALTERs | UNIQUE CONSTRAINT / ALTER EXISTING TABLE | Existing users/branches/locations/attendance/leave policy | High to very high: duplicates block DDL and table locks are possible | No row rewrite intended | Zero duplicates/orphans, exact schema, maintenance window, owner approval |
| 002 | `employee_kyc` and `employee_kyc_history` | CREATE NEW TABLE | New | Medium: FKs to existing employees/users | No existing rows | Confirm exact object absence/schema and parent keys |
| 002 | KYC indexes, unique key, FKs | CREATE INDEX / UNIQUE CONSTRAINT / FOREIGN KEY | New tables | Medium | No legacy data touched | Verify server and engine support |
| 003 | `employee_kyc_private` | CREATE NEW TABLE | New | Medium: sensitive schema and FKs | No existing rows | Confirm migration 002 and exact parent schema |
| 003 | Private indexes, unique keys, FKs | CREATE INDEX / UNIQUE CONSTRAINT / FOREIGN KEY | New table | Medium | No legacy data touched | Verify exact KYC parent schema |
| 004 | `employee_kyc_amendments` and private table | CREATE NEW TABLE | New | High: generated column, CHECK, FKs, active uniqueness | No existing rows | Confirm server supports generated stored columns and CHECK constraints |
| 004 | Active slot/status rules | CHECK CONSTRAINT / UNIQUE CONSTRAINT | New table | High: controls amendment concurrency and lifecycle | No legacy data touched | Do not weaken; verify after execution |
| 004 | Amendment indexes and FKs | CREATE INDEX / FOREIGN KEY | New tables | Medium | No legacy data touched | Verify all expected relationships |

No reviewed statement in migrations 001–004 performs `INSERT`, `UPDATE`, `DELETE`, `DROP`, `RENAME`, or `TRUNCATE` against existing production rows. The optional 001 ALTER statements are the only existing-table DDL and remain commented in the production pack.

## 3. Migration 002 Risk

Creates `employee_kyc` and `employee_kyc_history`. It references existing `employees` and `users` through foreign keys but does not alter or update them. It creates new indexes and uniqueness on new tables. Risk is schema compatibility, pre-existing partial KYC objects, and FK creation failure. Attendance, payroll, leave, and historical rows are not touched.

## 4. Migration 003 Risk

Creates `employee_kyc_private`, with uniqueness on new KYC IDs/employee IDs and indexes on blind indexes. It references only the new `employee_kyc` table and existing employees through a new FK. It does not alter existing legacy tables or update rows. Risk is partial prior deployment, incompatible KYC schema, and FK/index compatibility.

## 5. Migration 004 Risk

Creates `employee_kyc_amendments` and `employee_kyc_amendment_private`, including status CHECK constraint, generated active slot, one-active-amendment unique key, indexes, and FKs to KYC, employees, and users. It does not alter legacy tables or update existing rows. Risk is MySQL/MariaDB support for generated columns/CHECK constraints, existing partial objects, and FK compatibility. The active-amendment key must not be weakened.

## 6. Existing Table Impact

The additive tables reference `users` and `employees`. Migration 001's active CREATE references `users`. The optional uniqueness statements are the only planned existing-table modifications and are intentionally not automatic. No attendance, payroll, leave, employee, branch, or user rows are rewritten by migrations 001–004 as reviewed.

## 7. Preflight Requirements

Run `database/production/GEOROSTER_PRODUCTION_PREFLIGHT.sql` in GoDaddy/phpMyAdmin and save all output. Confirm database identity, server/version support, engines, character set/collation, affected schema, row counts, duplicate checks, orphan checks, partial objects, and existing indexes. Any non-zero duplicate/orphan result or schema mismatch is a stop condition.

## 8. Backup Requirements

Before SQL: download a complete non-zero GoDaddy/phpMyAdmin SQL export, back up current FTP files, record commit/date/time/operator, save preflight row counts, and confirm private production credential and secret configuration. Do not begin without these artifacts.

## 9. Exact Execution Order

1. Backup database and FTP.
2. Run and review read-only preflight.
3. Run 001, then 001_VERIFY and existing-app smoke test.
4. Run 002, then 002_VERIFY.
5. Run 003, then 003_VERIFY.
6. Run 004, then 004_VERIFY.
7. Stop immediately on any error. Do not rely on DDL transactions as rollback.

## 10. Verification Procedures

Each verify script checks expected tables, columns, indexes, foreign keys, constraints, and legacy row counts. Compare every legacy row count to the preflight baseline. The 004 verification must show the generated active slot, status CHECK, and `uq_amend_one_active`.

## 11. FTP Deployment Order

After all SQL verification passes and the production baseline is compared: configure private secrets, back up FTP again, upload only the approved runtime PHP files, avoid public SQL/docs, clear approved PHP caches if required, then run existing GeoRoster smoke tests followed by a controlled KYC smoke test.

## 12. KYC Secret Configuration

Production must supply `GEOROSTER_KYC_ENCRYPTION_KEY` and `GEOROSTER_KYC_HMAC_KEY` through private environment configuration or an untracked private configuration mechanism. Do not generate, print, commit, or store keys in MySQL. Production DB credentials must be provided outside webroot or by environment variables supported by `config/database.php`.

## 13. Stop-on-Failure Procedure

Capture migration number, exact statement, MySQL error, timestamp, and read-only `SHOW CREATE TABLE`/index/object state. Stop all migration and FTP actions. Escalate; do not repeatedly rerun or manually repair production.

## 14. Recovery Procedure

Use the recovery guide in `docs/GEOROSTER_PRODUCTION_MIGRATION_RECOVERY.md`. Empty newly-created additive objects may be considered for cleanup only after explicit confirmation and approval. Never drop legacy attendance/payroll/leave/user/employee tables. Restore from the verified backup only under an approved recovery decision.

## 15. Remaining Production Decisions

- Product Owner must review the read-only preflight output.
- Decide whether optional Migration 001 uniqueness keys are wanted after duplicate/orphan review.
- Confirm GoDaddy server support for migration 004 generated columns and CHECK constraints.
- Confirm exact production FTP baseline and PHP version.
- Confirm KYC secret provisioning and rotation ownership.
- Approve controlled deployment and UAT window.

## Production status

**PRODUCTION EXECUTION: NOT PERFORMED**

**LIVE DATABASE: NOT MODIFIED**

**LIVE FTP: NOT MODIFIED**

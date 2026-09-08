# GeoRoster Production Migration Recovery

## Universal stop rule

If any production migration returns an error, stop immediately. Do not click Run repeatedly, run the next migration, manually alter tables, or delete legacy tables. Save the migration number, failing statement, exact MySQL error, time, operator, and the read-only object state.

Use only read-only diagnostics after a failure:

```sql
SHOW CREATE TABLE affected_table;
SHOW INDEX FROM affected_table;
SELECT TABLE_NAME, TABLE_TYPE FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE();
```

Escalate to the Product Owner and database operator. Restore from the verified GoDaddy SQL backup only under an approved recovery decision.

## Migration 001

Likely failures: `security_audit_log` already exists with a different schema; `users` is missing or incompatible; foreign-key creation fails; server does not support the JSON column; or an optional legacy uniqueness statement encounters duplicates.

The active statement creates only `security_audit_log`. The legacy unique ALTER statements in `001_PRODUCTION.sql` are intentionally commented and require separate approval. If the audit table was created and the process then failed, inspect it with `SHOW CREATE TABLE` and compare it with the migration before rerunning. `CREATE TABLE IF NOT EXISTS` is rerunnable only when the existing schema matches. Do not drop a table containing records.

## Migration 002

Likely failures: missing/incompatible `employees` or `users` tables, existing KYC object with a different schema, duplicate employee IDs in an existing partial object, or unsupported foreign-key engine.

Inspect both KYC tables and their foreign keys. Rerun only if an existing object exactly matches the reviewed migration and the failed statement did not leave a conflicting partial definition. Never drop an existing KYC table without confirming it was created by this deployment, contains no records, and is not referenced by a later object. Otherwise restore/escalate.

## Migration 003

Likely failures: missing `employee_kyc`, incompatible existing private table, index-name collision, or unsupported foreign-key definition.

Inspect `employee_kyc_private` with `SHOW CREATE TABLE` and `SHOW INDEX`. Rerun only after confirming an exact matching empty object or a successful prior migration. Never delete a table containing KYC data.

## Migration 004

Likely failures: MySQL/MariaDB version does not support the generated stored column or CHECK constraint, existing amendment objects differ, foreign-key incompatibility, or index/constraint-name collision.

Inspect both amendment tables, generated-column metadata, CHECK constraints, indexes, and foreign keys. The one-active-amendment unique key is safety-critical. Do not substitute a weaker constraint manually. If version compatibility fails, stop for design review rather than editing production under pressure.

## Additive-object cleanup

A newly created empty object may be removed only after all of these are confirmed: it did not exist in the preflight, it was created by this deployment attempt, it contains zero rows, no later migration/object references it, and the Product Owner/database operator explicitly approves cleanup. This is not an automatic rollback procedure.

Never drop `users`, `branches`, `branch_locations`, `employees`, `attendance_entries`, `leave_types`, `leave_policy`, `leave_entries`, payroll tables, or any other legacy table as recovery.

## FTP recovery

If PHP deployment causes an issue, stop using the KYC screens, preserve logs, and compare the uploaded files against the backed-up production FTP copy. Restore only the exact backed-up runtime files under operator approval. Do not roll back database migrations by deleting KYC tables after PHP has written KYC data. Database and FTP rollback decisions must be coordinated.

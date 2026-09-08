# GeoRoster GoDaddy Production Deployment Checklist

## Gate

This checklist is preparation only. Do not execute production SQL or FTP deployment until the Product Owner approves the saved preflight output and backup evidence.

## Before SQL

- [ ] Confirm branch is `feature/employee-kyc-foundation`.
- [ ] Confirm approved commit is `dba97ab51468f3748d13dda3cbde7329cafa29a5` or an explicitly approved successor.
- [ ] Record deployment date, time, operator, and approval reference.
- [ ] Export the complete production database through GoDaddy/phpMyAdmin.
- [ ] Download the SQL export locally.
- [ ] Confirm the backup file exists and has non-zero size.
- [ ] Open the backup header and confirm the intended database name.
- [ ] Back up the current production FTP/web files locally.
- [ ] Record production table row counts from the preflight.
- [ ] Confirm database credentials will not be placed in Git or the public webroot.
- [ ] Confirm the production KYC encryption and HMAC secret configuration plan.

## Read-only preflight

- [ ] Run `database/production/GEOROSTER_PRODUCTION_PREFLIGHT.sql` in the intended GoDaddy database.
- [ ] Confirm `DATABASE()` is the intended client database, not a test or unrelated database.
- [ ] Confirm server version supports generated columns and CHECK constraints used by migration 004.
- [ ] Review engines, charset, collation, columns, indexes, constraints, and foreign keys.
- [ ] Review duplicate-query results; every duplicate result must be zero before any legacy uniqueness change.
- [ ] Review orphan-query results; every required orphan result must be zero.
- [ ] Record whether any KYC/security object already exists.
- [ ] STOP for any schema mismatch, duplicate, orphan, unexpected object, or unexplained row-count discrepancy.

## SQL execution order

For each migration: run the script, stop on any error, save the output, run its read-only verify script, and compare legacy row counts.

1. [ ] Run `001_PRODUCTION.sql`.
2. [ ] Run `001_VERIFY.sql` and perform an existing GeoRoster smoke check.
3. [ ] Run `002_PRODUCTION.sql`.
4. [ ] Run `002_VERIFY.sql`.
5. [ ] Run `003_PRODUCTION.sql`.
6. [ ] Run `003_VERIFY.sql`.
7. [ ] Run `004_PRODUCTION.sql`.
8. [ ] Run `004_VERIFY.sql`.
9. [ ] Do not uncomment migration 001 legacy uniqueness statements without separate owner approval and zero duplicate results.

## PHP/FTP deployment

- [ ] Confirm all database migrations and verification steps passed.
- [ ] Confirm production private DB configuration exists outside webroot or through environment variables.
- [ ] Configure `GEOROSTER_KYC_ENCRYPTION_KEY` and `GEOROSTER_KYC_HMAC_KEY` through the private production mechanism; do not generate keys in this release process.
- [ ] Back up current FTP files again immediately before upload.
- [ ] Upload only the approved runtime files in the FTP manifest.
- [ ] Do not upload SQL migrations to the public runtime directory unless deliberately retained outside webroot.
- [ ] Do not upload documentation or local test files.
- [ ] Clear PHP opcode/cache only through the hosting-approved method.

## Existing GeoRoster smoke test

- [ ] Login and logout.
- [ ] Profile and change password.
- [ ] Dashboard.
- [ ] Employee, branch, sub-location, and user management.
- [ ] Load attendance for a current branch/date; do not create destructive test records.
- [ ] Monthly register, payroll sheet, leave balance, management dashboard.
- [ ] Monthly register, payroll, and leave exports.

## Controlled KYC smoke test

- [ ] Use a designated controlled test employee only.
- [ ] Confirm KYC status display and start/save draft.
- [ ] Test applicability and statutory save only with approved test data.
- [ ] Confirm masking, submit, review, Admin verification, and verified lock.
- [ ] Confirm amendment request and queue visibility.
- [ ] Confirm approval/rejection using only approved controlled data.
- [ ] Do not enter real Aadhaar, PAN, UAN, or ESIC values for an initial smoke test.

## Evidence and closeout

- [ ] Save preflight output, each verification output, smoke-test evidence, and FTP transfer log.
- [ ] Compare post-migration legacy row counts with the preflight baseline.
- [ ] Confirm no production table outside the additive KYC/security scope changed unexpectedly.
- [ ] Record rollback/recovery decision and owner approval.
- [ ] Keep the production KYC gate separate from this preparation task.

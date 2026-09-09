# GeoRoster Group Medical Insurance Coverage

## Purpose

Prompt 03H adds employee-level group medical insurance enrollment status. This module records insurance coverage/enrollment status only. It does not store personal medical or health-condition information.

The status has three states: `NULL` / Not Set, `1` / Covered, and `0` / Not Covered. Not Set means coverage has not yet been reviewed; Not Covered is an explicit administrative determination.

## Data domain and authorization

Coverage lives in `employee_benefit_status`, separate from KYC and bank data. It is not subject to KYC VERIFIED immutability and can change after KYC verification without an amendment. Admin and active KYC Officers may view and update it. Branch KYC Officers are limited to their live branch; regular HO and Branch users receive no status.

Every update uses live authoritative user state and is audit logged as `group_medical_coverage_updated` with only employee ID and previous/new status codes. No diagnosis, claim, condition, hospital, dependent, or health information is stored or logged.

## Report and export

The authorized report starts with `employees` and left joins the benefit table so employees without a row remain Not Set. Filters cover branch, coverage state, and active/inactive/all employee status. The dedicated CSV export contains only employment identity, branch/sub-location, designation, category, active status, coverage status, and last updated. Values use the existing spreadsheet formula sanitizer.

## Migration and rollout

Migration 008 is additive and creates one row per employee with `RESTRICT` foreign keys to employees and users. The production SQL is a CREATE TABLE preparation pack only; `008_VERIFY.sql` is read-only. No production migration, backfill, FTP action, payroll calculation, general export, attendance, leave, bank, or document-vault change is included.

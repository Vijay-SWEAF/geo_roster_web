# GeoRoster Group Medical Insurance Verification

Prompt 03H verification covers the nullable three-state model, live Admin/KYC Officer authorization, branch isolation, immediate permission revocation, POST + CSRF update/export routes, left-joined Not Set report semantics, branch/coverage/active filters, audit-safe metadata, and spreadsheet-safe CSV output.

Synthetic tests cover Not Set, Covered, Not Covered, labels, and audit status codes. Migration 008 is validated separately in a disposable database by applying migrations 001 through 008, rerunning 008, checking the table, unique employee index, `RESTRICT` foreign keys, and zero initial rows. Production migration 008 is not executed.

This module records insurance coverage/enrollment status only. It does not store personal medical or health-condition information.

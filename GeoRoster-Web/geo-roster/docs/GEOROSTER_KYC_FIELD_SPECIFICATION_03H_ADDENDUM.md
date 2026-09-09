# GeoRoster Employee Benefits Specification: Prompt 03H Addendum

Prompt 03H adds Group Medical Insurance coverage as an HR / Employee Benefit field, not an identity-verification field.

Approved state values:

- Not Set: no benefit status row or NULL value.
- Covered: explicit coverage confirmation.
- Not Covered: explicit non-coverage confirmation.

Coverage remains editable after KYC verification and does not require an amendment. Only Admin and active KYC Officers may view or change it within live scope. This module records insurance coverage/enrollment status only. It does not store personal medical or health-condition information.

# GeoRoster Pre-KYC Audit

> Read-only technical, security, and KYC-readiness audit of the current GeoRoster
> attendance / HR application. **No production code was modified. No KYC was
> implemented. No database changes were made.** This document is the only file created.
>
> Audit date: 2026-09-05 · Auditor: automated code review · Scope: entire source tree.

---

## 1. Executive Summary

GeoRoster is a compact, single-tenant PHP/MySQL attendance, leave, and payroll
application for **Surge Marine Services Pvt. Ltd.**, deployed on CloudLinux/cPanel
shared hosting (PHP 8.4, MariaDB). Functionally it is coherent and complete: the
Branch → Sub-Location → Employee → Attendance → Leave → Payroll chain works, screen
and Excel calculations are in parity, and role-based menus are in place.

However, the codebase was written in a "get-it-working" style and carries **serious
security debt that is not acceptable once employee PII (KYC) is introduced.**

| Dimension | Assessment |
|---|---|
| Functional maturity | **Good** — modules are complete and internally consistent. |
| Code quality / maintainability | **Fair** — heavy logic duplication, mixed query styles, no VCS. |
| Security posture | **Poor** — systemic SQL injection, no CSRF, plaintext-password fallback, errors exposed. |
| Data integrity | **Fair** — some DB constraints exist (unique `employee_no`, one FK), but app-level "check-then-write" and missing uniqueness create race/duplication risk. |
| KYC readiness | **NOT READY** — must complete Phase 0 + Phase 1 hardening first. |

**Go / No-Go conclusion: NOT READY — READY AFTER HARDENING.**
Do **not** begin KYC implementation until the Phase 0 (critical) and Phase 1
(pre-KYC hardening) items in the roadmap are complete. KYC will store identity
documents, statutory IDs, and bank details; introducing that data on top of the
current SQL-injection and authorization weaknesses would create a direct
PII-breach path.

Top themes:
1. **SQL injection is pervasive** — most read pages and several admin write pages
   interpolate `$_GET`/`$_POST` directly into SQL.
2. **No CSRF protection**, and several destructive actions run over `GET`.
3. **Authorization is inconsistent** — one write path (`save_attendance.php`) and
   the leave-balance pages do not enforce branch isolation server-side.
4. **Production error exposure** — `display_errors` is on and DB exceptions are
   uncaught, leaking stack traces, server paths, and SQL fragments.
5. **Legacy plaintext-password fallback** still accepts non-hashed passwords.

---

## 2. Repository / Environment Checkpoint

| Item | Value |
|---|---|
| Repository root | `/Users/vijay/Downloads/Projects/geo-roster` |
| Version control | **None** — `git status` returns *"not a git repository"*. No branch/HEAD exists. |
| Working-tree state | Untracked working copy; no VCS baseline to diff against. |
| PHP version | **8.4** (evidence: `include_path=/opt/alt/php84/...` in `admin/error_log`). Verified `php -l` locally: all files pass. |
| Database | **MariaDB** (evidence: *"MariaDB server version"* in `error_log`). Schema DB name `attendance_db`. |
| Hosting | CloudLinux / cPanel shared hosting; app path `/home/<redacted>/public_html/geo-roster/`. |
| Web server | Apache with `mod_rewrite` (`.htaccess`, `RewriteBase /geo-roster/`). |
| PHP syntax check | **PASS** — 33/33 PHP files, no syntax errors. |

> **Note:** The absence of Git means there is no audit trail of code changes and no
> safe rollback point. Initializing version control is recommended before any KYC
> work begins (see Phase 0).

---

## 3. Current Architecture

### 3.1 Entity / data-flow map

```
                       ┌────────────┐
                       │   users    │  role_name ∈ {Admin, HO User, Branch User}
                       │ branch_id ─┼──────────────┐
                       └─────┬──────┘              │ (Branch User scoped to one branch)
                             │ entered_by          │
                             ▼                     ▼
   ┌───────────┐      ┌──────────────┐      ┌────────────────┐
   │ branches  │◄─────│  employees   │─────►│ branch_locations│
   │ branch_id │      │ employee_id  │      │  location_id    │
   │ branch_   │      │ employee_no* │      │  is_ot_enabled  │
   │  code     │      │ branch_id    │      │  is_expense_en. │
   └─────┬─────┘      │ location_id  │      └────────┬────────┘
         │            │ category     │               │  FK: fk_attendance_entries_location
         │            │ is_active    │               │
         │            └──────┬───────┘               │
         │                   │                       │
         │                   ▼                       │
         │         ┌─────────────────────┐           │
         └────────►│  attendance_entries │◄──────────┘
                   │ attendance_id       │
                   │ employee_id         │
                   │ attendance_date     │  status_code ∈ {P,A,L,H,WO}
                   │ branch_id           │  leave_type_id → leave_types
                   │ location_id         │  ot_hours, other_expense, remarks
                   │ leave_type_id       │  entered_by → users
                   └─────────┬───────────┘
                             │
              ┌──────────────┼───────────────┐
              ▼              ▼                ▼
       ┌────────────┐ ┌────────────┐  ┌──────────────┐
       │leave_types │ │leave_policy│  │leave_entries │
       │leave_code  │ │policy_year │  │ (category-   │
       │(CL,SL,EL,  │ │category    │  │  level leave │
       │ LWP, ...)  │ │leave_type  │  │  periods)    │
       └────────────┘ │entitled_dys│  └──────────────┘
                      └────────────┘

  * employee_no has a UNIQUE key (evidence: "Duplicate entry ... for key 'employee_no'").
```

### 3.2 Request flow

```
Browser → index.php → auth/login.php ─(POST)→ session[user_id, role, full_name]
       → dashboard.php (role-based cards)
           ├─ attendance_entry.php ─(POST)→ save_attendance.php
           ├─ monthly_register.php ─→ export_monthly_register.php
           ├─ payroll_sheet.php    ─→ export_payroll.php
           ├─ leave_balance.php    ─→ export_leave_balance.php
           ├─ management_dashboard.php (Admin/HO)
           └─ admin/* (branches, employees, sub-locations, users, leave policy/entry)
Every authenticated page requires includes/auth_check.php (session gate only).
```

### 3.3 Where KYC would attach

KYC is a **1:1 extension of `employees`** (identity, statutory IDs, bank, address)
plus a **1:many document store** and an **audit log**. It slots between
`employees` and reporting/exports, and must inherit the same branch-scoping that
attendance uses — but with *stronger* access control because the data is PII.

---

## 4. Existing Functional Modules

| Module | File(s) | Purpose |
|---|---|---|
| Login | `auth/login.php` | Username/password auth, sets session. Prepared statement + plaintext fallback. |
| Logout | `logout.php` | Clears + destroys session and cookie. |
| Auth gate | `includes/auth_check.php` | Redirects to login if no `user_id` in session. |
| Layout | `includes/header.php`, `footer.php` | Chrome, flash messages, role badge. `APP_INCLUDED` guard. |
| Helpers | `includes/functions.php` | `getBranchName`, `getLeaveTypes`, `getEmployeesByBranch`. |
| Profile | `profile.php` | Read-only account view. |
| Change password | `change_password.php` → `update_password.php` | Self-service password change (prepared stmts, plaintext fallback). |
| Dashboard | `dashboard.php` | Role-based module cards (UI only). |
| Attendance entry | `attendance_entry.php` → `save_attendance.php` | Daily branch attendance grid, bulk status, leave-exhaustion → LWP. |
| Monthly register | `monthly_register.php` / `export_monthly_register.php` | Date-wise register + Excel export. |
| Payroll sheet | `payroll_sheet.php` / `export_payroll.php` | Monthly matrix, paid days, OT, expense, CL/SL/EL balances. |
| Leave balance | `leave_balance.php` / `export_leave_balance.php` | Entitled/availed/balance per employee. |
| Management dashboard | `management_dashboard.php` | Charts/summaries (Admin/HO). |
| Branch master | `admin/branches.php` | Create/list branches (Admin). |
| Sub-location master | `admin/branch_locations.php` | Create sub-locations, OT/expense toggles (Admin). |
| Employee master | `admin/employees.php`, `edit_employee.php`, `toggle_employee.php` | CRUD + activate/deactivate (Admin/HO). |
| Leave policy | `admin/leave_policy.php` | Yearly entitlement per category/type (Admin). |
| Leave entry | `admin/leave_entry.php` | Category-level leave periods (Admin). |
| User management | `admin/user_management.php`, `create_user.php`, `edit_user.php`, `toggle_user_status.php`, `reset_user_password.php` | User CRUD, activate, reset password (Admin). |

Confirmed roles from source: **Admin, HO User, Branch User** (`create_user.php`,
`dashboard.php`, per-page role checks).

---

## 5. Role / Permission Matrix

**UI visibility** = shown on dashboard. **Server enforcement** = actual check on the
endpoint. The two diverge in several places — those rows are flagged.

| Capability | Admin | HO User | Branch User | Server-side enforcement |
|---|---|---|---|---|
| Dashboard | Allowed | Allowed | Allowed | Auth only |
| Branch Master (`admin/branches.php`) | Allowed | Denied | Denied | ✔ `role != Admin` blocked |
| Sub-Location Master (`admin/branch_locations.php`) | Allowed | Denied | Denied | ✔ Admin only |
| Employee Master (`admin/employees.php`) | Allowed | Allowed | Denied | ✔ Admin/HO; **no branch scope for HO** |
| Employee Edit (`admin/edit_employee.php`) | Allowed | Allowed | Denied | ✔ Admin/HO |
| Employee Activate/Deactivate (`admin/toggle_employee.php`) | Allowed | Allowed | Denied | ✔ Admin/HO — **GET, no CSRF** |
| Attendance Entry (`attendance_entry.php`) | Allowed | Allowed | Branch-scoped | Auth only; branch forced on entry |
| Attendance Save (`save_attendance.php`) | Allowed | Allowed | Branch-scoped (intended) | ⚠ **Auth only — branch NOT re-validated (IDOR)** |
| Monthly Register (`monthly_register.php`) | Allowed | Allowed | Branch-scoped | ✔ Branch forced |
| Monthly Register Export | Allowed | Allowed | Branch-scoped | ✔ Branch forced |
| Payroll Sheet (`payroll_sheet.php`) | Allowed | Allowed | Branch-scoped | ✔ Branch forced |
| Payroll Export (`export_payroll.php`) | Allowed | Allowed | Branch-scoped | ✔ Branch forced |
| Leave Entry (`admin/leave_entry.php`) | Allowed | Denied | Denied | ✔ Admin only |
| Leave Policy (`admin/leave_policy.php`) | Allowed | Denied | Denied | ✔ Admin only |
| Leave Balance (`leave_balance.php`) | Allowed | Allowed | *(hidden)* | ⚠ **No role/branch check — any authed user, any branch** |
| Leave Balance Export (`export_leave_balance.php`) | Allowed | Allowed | *(hidden)* | ⚠ **No branch scope — any branch** |
| Management Dashboard | Allowed | Allowed | Denied | ✔ Admin/HO only |
| User Management (`admin/user_management.php`) | Allowed | Denied | Denied | ✔ Admin only |
| User Edit (`admin/edit_user.php`) | Allowed | Denied | Denied | ✔ Admin only |
| User Activate/Deactivate (`admin/toggle_user_status.php`) | Allowed | Denied | Denied | ✔ Admin only — **GET, no CSRF** |
| Password Reset (`admin/reset_user_password.php`) | Allowed | Denied | Denied | ✔ Admin only — **GET, no CSRF, weak temp pw** |
| Profile / Change Password | Allowed | Allowed | Allowed | Auth only |

Key takeaways:
- **HO User** is effectively head-office-global for employees (no branch scoping) —
  appears intentional but should be confirmed by the product owner.
- **`save_attendance.php`, `leave_balance.php`, `export_leave_balance.php`** are the
  three authorization gaps.

---

## 6. Database Model

No SQL schema/migration files are checked into the repo, so the model is
reconstructed from query usage and from constraint errors observed in the logs.

| Table | Key columns (observed) | Constraints observed | Notes |
|---|---|---|---|
| `users` | `user_id` PK, `username`, `password_hash`, `role_name`, `branch_id`, `is_active`, `full_name`, `created_at` | (username uniqueness enforced only in app via `create_user.php`) | No DB unique on `username` verified. |
| `branches` | `branch_id` PK, `branch_code`, `branch_name`, `location_city` | none verified | No unique on `branch_code` verified. |
| `branch_locations` | `location_id` PK, `branch_id`, `location_name`, `is_active`, `is_ot_enabled`, `is_expense_enabled`, `created_at` | referenced by FK below | App checks (branch_id + name) uniqueness only. |
| `employees` | `employee_id` PK, `employee_no`, `employee_name`, `branch_id`, `location_id`, `designation`, `employee_category`, `is_active` | **UNIQUE `employee_no`** (log: *Duplicate entry 'SMS-170' for key 'employee_no'*) | Good. Category is app-restricted to Staff/Labour. |
| `attendance_entries` | `attendance_id` PK, `attendance_date`, `branch_id`, `location_id`, `employee_id`, `status_code`, `leave_type_id`, `ot_hours`, `other_expense`, `remarks`, `entered_by` | **FK `fk_attendance_entries_location`** → `branch_locations(location_id)` ON DELETE SET NULL | No unique on (`employee_id`,`attendance_date`) verified — app enforces via SELECT-then-write. |
| `leave_types` | `leave_type_id` PK, `leave_code`, `leave_name`, `is_active` | none verified | Codes: CL, SL, EL, LWP (+ others). |
| `leave_policy` | `policy_id` PK, `policy_year`, `employee_category`, `leave_type_id`, `entitled_days` | none verified | **No unique on (year,category,type)** — duplicates possible; payroll reads `LIMIT 1`. |
| `leave_entries` | `leave_id` PK, `employee_category`, `leave_type_id`, `from_date`, `to_date`, `remarks`, `entered_by` | none verified | Category-level; not linked to individual employees. |

**Uniqueness rules — verification at DB level:**

| Expected rule | App-enforced? | DB-enforced? |
|---|---|---|
| `users.username` unique | Yes (`create_user.php`) | **Unverified / likely missing** |
| `employees.employee_no` unique | No app pre-check on insert | **Yes (confirmed via error log)** |
| `branches.branch_code` unique | No | **Unverified** |
| `branch_locations` (branch+name) unique | Yes (SELECT check) | **Unverified** |
| `attendance_entries` (employee+date) unique | Yes (SELECT-then-write) | **Unverified — race condition risk** |
| `leave_policy` (year+category+type) unique | No | **Unverified — duplicates observed-possible** |

**Data-integrity risks:** missing FKs on `attendance_entries.employee_id`,
`.branch_id`, `.leave_type_id`, `.entered_by`; missing FK on `employees.branch_id`,
`.location_id`; missing unique constraints above; no `created_at/updated_at` audit
columns on most tables.

---

## 7. Authentication & Session Audit

| Check | Result | Evidence |
|---|---|---|
| Password hashing (new) | `password_hash(..., PASSWORD_DEFAULT)` | `create_user.php`, `update_password.php`, `reset_user_password.php` |
| Password verification | `password_verify()` | `login.php`, `update_password.php` |
| **Legacy plaintext fallback** | **Present** — `elseif ($password === $stored_password)` | `login.php` L33-37, `update_password.php` L58-63 |
| Login uses prepared stmt | Yes | `login.php` `prepare("... username = ?")` |
| Session regeneration after login | **Missing** — no `session_regenerate_id(true)` | `login.php` sets session then redirects |
| Session fixation protection | **Missing** | as above |
| Session cookie flags (Secure/HttpOnly/SameSite) | **Not set** — relies on defaults | no `session_set_cookie_params`/ini hardening |
| Inactivity / absolute timeout | **None** | no timeout logic |
| Logout | Correct — unsets, clears cookie, `session_destroy()` | `logout.php` |
| Brute-force / rate limiting / lockout | **None** | no attempt counter |
| Account enumeration | **Present** — "User not found." vs "Invalid password." | `login.php` distinct messages |
| Inactive account handling | Login filters `is_active = 1` | `login.php` |
| Password policy | Weak — min 6 chars only, no complexity | `update_password.php` L28 |
| Temp password (admin reset) | **Weak** — `"Temp@".rand(1000,9999)` (non-CSPRNG, 4 digits), shown in flash message | `reset_user_password.php` L22, L34 |

The plaintext fallback means any legacy row whose `password_hash` still holds a
plaintext value authenticates by string equality. This must be migrated out
before KYC (a compromised DB backup would reveal usable passwords).

---

## 8. Authorization / Branch Isolation Audit

Branch isolation is enforced by re-deriving the user's `branch_id` from the
session and forcing it for Branch Users — done correctly in `attendance_entry.php`,
`monthly_register.php`, `payroll_sheet.php`, `export_monthly_register.php`,
`export_payroll.php`. Three gaps:

1. **`save_attendance.php` (IDOR — write, HIGH).** The handler trusts POST arrays
   `employee_id[]`, `branch_id[]`, `location_id[]` and only checks that a Branch
   User isn't posting a non-today date. It never verifies the posted employees /
   branch belong to the user's own branch. A Branch User can craft a POST to
   insert/overwrite attendance for **any** branch's employees.

2. **`leave_balance.php` (broken access control — read, HIGH).** No role or branch
   check; `$branch_id` comes straight from `$_GET`. Any authenticated user
   (including a Branch User navigating directly) can read any branch's
   employee-level leave data.

3. **`export_leave_balance.php` (read, HIGH).** Same — no branch forcing; exports
   any branch.

All three are also **SQL-injectable** (Section 9) because the branch/date/year
parameters are interpolated.

> IDOR reachability for KYC: the same "trust the posted/queried id" pattern would,
> if copied into KYC pages, expose other branches' identity documents. The fix
> (a central `assertBranchAccess($conn, $branchId)` helper) must land before KYC.

---

## 9. Input / SQL / XSS Audit

### 9.1 Query classification

| Class | Where |
|---|---|
| **A. Prepared, parameterized** | `login.php` (SELECT user), `update_password.php` (SELECT + UPDATE), `change_password.php` flow. |
| **B. Escaped/interpolated** | `create_user.php`, `edit_user.php`, `edit_employee.php`, `branch_locations.php` (use `real_escape_string` + int casts), `management_dashboard.php` (partial `real_escape_string` on branch filter). |
| **C. Directly interpolated (UNSAFE)** | `attendance_entry.php`, `save_attendance.php`, `monthly_register.php`, `payroll_sheet.php`, `leave_balance.php`, `export_payroll.php`, `export_monthly_register.php`, `export_leave_balance.php`, `admin/branches.php`, `admin/employees.php`, `admin/leave_entry.php`, `admin/leave_policy.php`, `profile.php`. |
| **D. Safe constant/internal** | Static `SELECT`s over fixed tables with no user input. |

### 9.2 Confirmed SQL-injection vectors (Class C)

| Parameter | Source | Example sink | Files |
|---|---|---|---|
| `attendance_date` / `$date` | `$_GET` / `$_POST` | `WHERE attendance_date = '$date'`, `YEAR('$date')`, INSERT `VALUES('$date', ...)` | `attendance_entry.php`, `save_attendance.php` |
| `branch_id` / `$selected_branch_id` | `$_GET` (HO/Admin) | `WHERE branch_id = '$selected_branch_id'` (not cast) | `attendance_entry.php`, `monthly_register.php`, `payroll_sheet.php`, exports, `leave_balance.php` |
| `month` → `$start`/`$end` | `$_GET` | `BETWEEN '$start_date' AND '$end_date'` | `monthly_register.php`, `payroll_sheet.php`, `export_*` |
| `year` / `$selected_year` | `$_GET` | `policy_year = '$selected_year'` | `leave_balance.php`, `export_leave_balance.php` |
| `leave_type_id` | `$_GET` | `leave_type_id = '$leave_type_id'` | `leave_balance.php`, `export_leave_balance.php` |
| `employee_no`, `employee_name`, `branch_id`, `designation`, `employee_category` | `$_POST` | INSERT `employees` — **no escaping** | `admin/employees.php` |
| `branch_code`, `branch_name`, `location_city` | `$_POST` | INSERT `branches` — **no escaping** | `admin/branches.php` |
| `employee_category`, `leave_type_id`, `from_date`, `to_date`, `remarks` | `$_POST` | INSERT `leave_entries` — **no escaping** | `admin/leave_entry.php` |
| `policy_year`, `employee_category`, `leave_type_id`, `entitled_days` | `$_POST` | INSERT `leave_policy` — **no escaping** | `admin/leave_policy.php` |

Because MariaDB throws `mysqli_sql_exception` and `display_errors` is on, injection
attempts also **echo SQL errors and server paths** back to the attacker (blind →
error-based). Several inputs are partially mitigated by `(int)` casts
(`employee_id`, `location_id`, `is_active`, etc.) or allowlists (`status_code`,
category), which reduces but does not eliminate the surface.

### 9.3 XSS / output escaping

- Most display output uses `htmlspecialchars()` — good baseline.
- **Stored XSS is currently limited** because names/remarks are escaped on output,
  but the underlying values are stored unsanitized; any *new* page or export that
  forgets escaping (e.g. a future KYC screen) will render them.
- `login.php` echoes `$error` unescaped, but only from static strings — low risk.

---

## 10. CSRF Audit

**No CSRF protection exists anywhere in the application** — no tokens, no
`SameSite` cookie attribute, no origin/referer checks.

State-changing endpoints:

| Endpoint | Method | CSRF risk |
|---|---|---|
| `save_attendance.php` | POST | High — no token |
| `admin/branches.php` (add) | POST | High |
| `admin/branch_locations.php` (add / toggle) | POST | High |
| `admin/employees.php` (add) | POST | High |
| `admin/edit_employee.php` (update) | POST | High |
| `admin/create_user.php` / `edit_user.php` | POST | High |
| `admin/leave_entry.php` / `leave_policy.php` | POST | High |
| `update_password.php` | POST | Medium (requires current password) |
| **`admin/toggle_employee.php`** | **GET** | **High — destructive over GET** |
| **`admin/toggle_user_status.php`** | **GET** | **High — destructive over GET** |
| **`admin/reset_user_password.php`** | **GET** | **High — resets a password over GET** |

The three GET-based admin actions are the worst: they can be triggered by a
crafted link/image and are prefetchable. Recommended standard: a per-session CSRF
token stored in `$_SESSION`, embedded as a hidden field in every form, verified on
every POST; convert the three GET actions to POST; set the session cookie
`SameSite=Lax` (or `Strict`) + `HttpOnly` + `Secure`. **Do not implement now** —
scheduled for Phase 1.

---

## 11. Attendance Audit

- **Statuses supported (server allowlist in `save_attendance.php`):** `P, A, L, H, WO`.
  Leave sub-codes (`CL, SL, EL, LWP`) live in `leave_types` and are selected via
  `leave_type_id` when status = `L`.
- **Default status:** `P` (attendance_entry default when no record exists).
- **Leave exhaustion → LWP:** on save, if computed balance ≤ 0 and the type isn't
  already LWP, the entry is silently converted to LWP with a warning message.
  Balance = policy `entitled_days` − count of prior `L` entries of that type this
  year (excluding the row being saved).
- **OT / expense toggles:** per sub-location (`is_ot_enabled`, `is_expense_enabled`);
  Admin/HO can override; Branch Users are zeroed when disabled. Enforced
  **server-side** in `save_attendance.php` (good — not just the JS/readonly UI).
- **Branch User date restriction:** enforced server-side (only today's date).
- **Duplicate prevention:** app-level SELECT-then-INSERT/UPDATE keyed on
  (`employee_id`,`attendance_date`). **No DB unique constraint verified → race
  condition** (two concurrent posts could insert duplicates).
- **Inactive employees:** `attendance_entry.php` / `payroll_sheet.php` do **not**
  filter `is_active`, so inactive employees still appear and can be marked — while
  `leave_balance.php` filters `is_active = 1`. Inconsistent.
- **Client vs server:** bulk-status and leave warnings are JS conveniences; the
  authoritative checks (status allowlist, OT/expense, date) are server-side. Good.

---

## 12. Leave Audit

Calculation chain: `leave_policy(entitled)` → per employee category/year →
`attendance_entries` where `status_code='L'` and `leave_type_id=X` and year →
`availed` = COUNT → `balance = entitled − availed`.

Parity check across modules:

| Module | Availed definition | Consistent? |
|---|---|---|
| `attendance_entry.php` | COUNT `L` of type, year (includes current date) | baseline |
| `save_attendance.php` | COUNT `L` of type, year, **excluding the saving date** | intentional variant (excludes row being edited) |
| `leave_balance.php` / `export_leave_balance.php` | COUNT `L` of type, year | ✔ matches baseline |
| `payroll_sheet.php` / `export_payroll.php` | COUNT `L` grouped by CL/SL/EL, year | ✔ matches |

**Findings:** logic is *consistent in result* but **duplicated in ~6 places**. Any
future change (e.g. pro-rating on transfer, carry-forward) must be edited in every
copy — high divergence risk. `leave_policy` has no uniqueness on
(year,category,type); a duplicate row would be silently ignored by `LIMIT 1` and
could mask a data-entry error.

---

## 13. Payroll Audit

Paid-day formula (identical in `payroll_sheet.php` and `export_payroll.php` →
**screen/export parity confirmed**):

| Status | Count bucket | Paid days |
|---|---|---|
| `P` Present | present++ | +1 |
| `WO` Weekly Off | weekly_off++ | +1 |
| `H` Half Day | half++ | +0.5 |
| `A` Absent | absent++ | +0 |
| `CL`/`SL`/`EL` (paid leave) | leave++ | +1 |
| `L`/`LWP`/`PL` (unpaid) | leave++ | +0 |

OT and other-expense are summed per employee per month. CL/SL/EL balances shown =
allotment − used (year-to-date).

**Boundary observations (business rules to confirm, not defects to fix):**
- Month length handled via `date("t")` — 28/29/30/31 and leap years OK.
- Missing attendance on a day = blank (not counted as absent). Confirm this is
  intended vs. "no entry = absent".
- Inactive / mid-month transferred employees are not specially handled — an
  employee moved between branches keeps historical rows under the old branch_id
  (rows carry their own `branch_id`), which is reasonable, but the current-master
  branch view will not show their prior-branch days.
- Negative leave balances are possible (used > allotment) and are displayed as
  negative — confirm desired presentation.

No payroll formula was changed. These are flagged as **ambiguous business rules**
for owner confirmation.

---

## 14. Export Audit

Four exporters produce **HTML tables served as `application/vnd.ms-excel` `.xls`**:
`export_monthly_register.php`, `export_payroll.php`, `export_leave_balance.php`.

| Check | Result |
|---|---|
| Authorization | Auth required; branch forced for Branch User in monthly/payroll exports; **`export_leave_balance.php` does NOT force branch** (Section 8). |
| Output escaping | `htmlspecialchars()` used on cells. |
| **Excel/CSV formula injection** | **Not mitigated** — cells beginning with `= + - @` (e.g. a crafted `employee_name` or `remarks`) will be interpreted as formulas when opened in Excel. |
| Content-Type | Legacy `.xls`-as-HTML; opens with a "file format differs" warning in modern Excel (cosmetic). |
| Filename sanitization | Branch name passed through `preg_replace('/[^A-Za-z0-9_-]/','_')` — good; month/year unsanitized in filename (low risk, header-injection unlikely via `date()`-derived values but the raw `$_GET` `month` flows in). |
| Screen/export parity | Payroll and register match their on-screen counterparts. |

**KYC relevance:** once KYC exists, these general exporters must **not** be extended
to include identity/document fields, and the formula-injection gap must be closed
before any PII lands in a spreadsheet.

---

## 15. Error Handling / Production Configuration

| Item | Finding | Evidence |
|---|---|---|
| `display_errors` | **Enabled** in `login.php`, `attendance_entry.php`, `monthly_register.php`, `payroll_sheet.php`, `leave_balance.php`, `export_monthly_register.php`, `management_dashboard.php` via `ini_set('display_errors',1)` | file headers |
| Uncaught DB exceptions | mysqli throws `mysqli_sql_exception`, not caught → fatal error page with stack trace | `error_log`, `admin/error_log` |
| Server path disclosure | Full paths `/home/<redacted>/public_html/geo-roster/...` leaked in error output | logs |
| SQL error exposure | `die("... " . $conn->error)` and uncaught exceptions surface SQL text | `save_attendance.php`, `attendance_entry.php`, etc. |
| **Hardcoded DB credentials** | **Present** in `config/database.php` — host, db, user, and password committed in source. **Value redacted from this report.** | `config/database.php` |
| `.env` usage | None | — |
| `uploads/` protection | **No `.htaccess`, no `index`** in `uploads/` (empty now; relevant for KYC document storage) | `uploads/` listing |
| Directory listing | Mitigated globally via `Options -Indexes` | `.htaccess` |
| Security headers (CSP, X-Frame-Options, HSTS, etc.) | **None** | no header code |
| HTTPS enforcement | Not enforced in app (`.htaccess` has no redirect) | `.htaccess` |

> **Remediation for credentials:** move DB credentials out of source into an
> environment file **outside** the web root (e.g. cPanel env / `.env` above
> `public_html`), rotate the current password, and add the config to ignore rules.
> The committed secret should be treated as compromised. The actual value is **not**
> reproduced here.

---

## 16. UI / Maintainability Findings

- **Heavy inline CSS/JS** duplicated per page (login has a full inline stylesheet;
  employees/edit pages duplicate location-filter JS and confirm-modal markup).
- **Inconsistent confirmations** — `employees.php` uses a custom modal; other
  destructive links rely on `data-message`/native behavior.
- **Mixed query styles** — prepared statements in a few files, raw interpolation in
  most; no shared DB helper.
- **No shared components** for flash messages beyond the header include; no shared
  authorization/branch-scope/validation helpers.
- Responsive tables use `table-wrap` scroll; sticky columns are limited — likely
  mobile friction on wide payroll matrices (report only, no redesign requested).
- **No version control** — no history, no rollback, no code review trail.

---

## 17. Error Log Findings

| Signature | Interpretation | Status |
|---|---|---|
| `save_attendance.php:98` — SQL syntax error near '' | Empty/edge parameter reaching interpolated query — matches the SQLi/validation gaps | Historical + reproducible |
| `save_attendance.php:97` — FK `fk_attendance_entries_location` fails | Posted `location_id` not present in `branch_locations` (stale/tampered id) | Reproducible; also proves an FK exists |
| `employees.php:24` / `edit_employee.php:67` — Duplicate entry for key `employee_no` | Unique constraint firing as an **uncaught** exception (poor UX, but constraint works) | Reproducible |
| `admin/*` — Failed opening required `includes/auth_check.php` / `header.php` | Relative include failures when script run from an unexpected CWD | Historical (path/config) |
| `auth/login.php` / `config/database.php:8` — mysqli "No such file or directory" | DB socket/host resolution failures at times | Historical (infra) |

No credentials or session identifiers were reproduced from the logs. The logs
confirm two positive facts (unique `employee_no`, one FK) and one negative pattern
(uncaught exceptions surfacing to users).

---

## 18. Full Security Findings Table

Complexity: **S** ≤ half-day · **M** ~1–3 days · **L** > 3 days.

| ID | Sev | Area | Description | Evidence | Failure/Exploit | Current impact | KYC impact | Remediation | Req. before KYC | Cx |
|---|---|---|---|---|---|---|---|---|---|---|
| C1 | Critical | SQLi | User input interpolated into SQL across read pages & several admin writes | §9.2 | Error/blind SQLi → data theft, tamper | DB read/write exposure | **PII/doc theft, mass exfil** | Convert all Class-C queries to prepared statements; centralize DB access | **Yes** | L |
| C2 | Critical | Secrets | Hardcoded DB credentials in source | `config/database.php` | Source/backup leak → full DB access | Full DB compromise if leaked | Direct PII access | Move to env outside webroot; **rotate**; ignore in VCS | **Yes** | S |
| H1 | High | AuthZ (IDOR) | `save_attendance.php` trusts POST `employee_id[]/branch_id[]` | §8.1 | Branch User writes other branch attendance | Cross-branch data tamper | Cross-branch PII writes | Re-derive & assert branch/employee ownership server-side | **Yes** | M |
| H2 | High | AuthZ | `leave_balance.php` no role/branch scope | §8.2 | Any user reads any branch leave data | Cross-branch data read | Cross-branch PII read | Add role gate + branch force | **Yes** | S |
| H3 | High | AuthZ | `export_leave_balance.php` no branch scope | §8.3 | Any user exports any branch | Data leak via export | PII export leak | Force branch for Branch User | **Yes** | S |
| H4 | High | Config | `display_errors` on + uncaught DB exceptions | §15 | Stack traces, paths, SQL to user | Info disclosure, aids SQLi | Reveals PII query structure | Disable display_errors; global exception handler; log-only | **Yes** | S |
| H5 | High | CSRF | No CSRF tokens anywhere | §10 | Forged state changes | User/employee/attendance tamper | Forged KYC edits/approvals | Session CSRF token on all POST | **Yes** | M |
| H6 | High | CSRF | Destructive actions over GET (toggle user/employee, reset pw) | §10 | Link/prefetch triggers action | Account/employee disable, pw reset | KYC status flips via GET | Convert to POST + CSRF | **Yes** | S |
| H7 | High | Auth | Legacy plaintext-password fallback | `login.php`, `update_password.php` | Plaintext rows authenticate by `==` | Weak credential store | Backup leak → usable creds | Migrate all to hashes; remove fallback after migration | **Yes** | M |
| H8 | High | Session | No `session_regenerate_id` after login; cookie flags not set | §7 | Session fixation; cookie theft | Session hijack | PII session hijack | Regenerate on login; set Secure/HttpOnly/SameSite | **Yes** | S |
| M1 | Med | Auth | Weak temp password (`rand`, 4 digits) shown in flash | `reset_user_password.php` | Guessable reset password | Account takeover window | KYC account takeover | CSPRNG, ≥12 chars, force change on next login, deliver securely | Recommended | S |
| M2 | Med | Auth | Username enumeration in login messages | `login.php` | Distinguish valid users | Recon aid | Recon aid | Generic "invalid credentials" | Recommended | S |
| M3 | Med | Auth | No brute-force/rate limiting | `login.php` | Unlimited guesses | Credential stuffing | PII access via stuffing | Attempt throttling/lockout | Recommended | M |
| M4 | Med | Auth | Weak password policy (min 6) | `update_password.php` | Weak passwords | Easier compromise | — | Length ≥10 + complexity | Recommended | S |
| M5 | Med | Export | Excel/CSV formula injection | §14 | `=`/`+`/`-`/`@` cells execute in Excel | Client-side formula exec | Malicious KYC export | Prefix risky cells with `'`; proper XLSX lib | Recommended | S |
| M6 | Med | Maint | Duplicated leave/payroll logic (~6 copies) | §12 | Divergent edits | Calc drift risk | KYC report drift | Centralize into helper/service | Recommended | M |
| M7 | Med | DB | No unique on `leave_policy` (year,cat,type) | §6 | Duplicate policy rows | Ambiguous entitlement | — | Add unique constraint | Recommended | S |
| M8 | Med | DB | No unique on `attendance_entries` (emp,date) | §6/§11 | Race → duplicate rows | Payroll double-count | — | Add unique constraint | Recommended | S |
| M9 | Med | Audit | No admin action audit trail | §16 | No accountability | Undetected tamper | **KYC needs audit trail** | Add audit logging (see §24) | Recommended | M |
| M10 | Med | Process | No version control | §2 | No rollback/history | Change risk | Risky KYC rollout | `git init` + workflow | Recommended | S |
| M11 | Med | Logic | Inactive employees unfiltered in attendance/payroll | §11 | Inconsistent with leave_balance | Data-entry noise | Stale KYC targets | Consistent `is_active` policy | Optional | S |
| M12 | Med | Storage | `uploads/` unprotected, no deny rules | §15 | Direct file access | (empty now) | **KYC doc exposure** | Store docs outside webroot; deny direct access | **Yes (for KYC)** | S |
| L1 | Low | Maint | Inline CSS/JS duplication | §16 | — | Maintainability | — | Extract shared assets | Optional | M |
| L2 | Low | SQLi | `profile.php` interpolates session `user_id` | `profile.php` | Low (server-set int) | Minimal | Minimal | Parameterize | Optional | S |
| L3 | Low | XSS | `login.php` echoes `$error` unescaped | `login.php` | Static strings only | Minimal | Minimal | Escape on output | Optional | S |
| I1 | Info | Config | Server path disclosure via errors | §15 | Recon | Minor | Minor | Covered by H4 | — | — |
| I2 | Info | DB | Confirmed unique `employee_no` + FK on location | §6/§17 | Positive | — | — | Extend same rigor to all tables | — | — |

---

## 19. KYC Blockers

Must be fixed **before** KYC implementation / production launch:

- **C1** SQL injection (systemic).
- **C2** Hardcoded DB credentials (+ rotation).
- **H1** Attendance write IDOR (proves the branch-scope pattern is unsafe to copy).
- **H2/H3** Leave-balance branch-isolation gaps.
- **H4** Production error exposure.
- **H5/H6** No CSRF + destructive GET actions.
- **H7** Plaintext-password fallback + migration.
- **H8** Session fixation / cookie flags.
- **M12** Unprotected `uploads/` (blocker specifically for KYC documents).

---

## 20. Pre-KYC Hardening Recommendations

1. **Central DB layer** — one helper with prepared-statement wrappers; ban raw
   interpolation. Migrate all Class-C queries.
2. **Central auth/branch helpers** — `requireRole([...])`,
   `assertBranchAccess($conn,$branchId)`, `currentUserBranchId()`; apply to every
   endpoint (fixes H1/H2/H3 uniformly).
3. **CSRF service** — `csrf_token()` + `csrf_verify()`; hidden field in all forms;
   convert the three GET actions to POST; set `SameSite`/`HttpOnly`/`Secure`.
4. **Global error handling** — `display_errors=Off` in production; app-level
   exception handler that logs and shows a generic message.
5. **Secrets** — env file outside web root; rotate password; add to ignore rules.
6. **Auth hardening** — `session_regenerate_id(true)` on login; strong session
   cookie params; login throttling; generic login errors; stronger password policy;
   CSPRNG temp passwords with forced reset.
7. **Password migration** — rehash-on-login for any plaintext row, then remove the
   fallback.
8. **DB constraints** — add missing unique keys (`users.username`,
   `attendance_entries(emp,date)`, `leave_policy(year,cat,type)`,
   `branches.branch_code`) and FKs; do this as reviewed migrations (Phase 1/2).
9. **Export safety** — neutralize spreadsheet formula injection.
10. **Version control** — initialize Git; commit a clean baseline before KYC.
11. **Security headers** — `X-Frame-Options`, `X-Content-Type-Options`,
    `Referrer-Policy`, CSP, and HTTPS redirect.

> These are recommendations for later phases. **None are implemented in this audit.**

---

## 21. Proposed KYC Architecture

Extend the existing schema conventionally (names indicative, to be finalized after
owner sign-off):

- **`employee_kyc`** — 1:1 with `employees`. Holds structured, non-file PII
  (identity numbers masked at rest where justified, contact, address, statutory IDs,
  bank details), plus `kyc_status`, `verified_by`, `verified_at`, timestamps.
- **`employee_kyc_documents`** — 1:many. One row per uploaded document with
  `document_type`, `stored_filename` (unpredictable), `original_filename`,
  `mime_type`, `file_size`, `document_number` (optional), `expiry_date`,
  `version`, `is_current`, `uploaded_by`, `uploaded_at`, `status`.
- **`employee_kyc_audit_log`** — append-only. One row per material event
  (see §24). Never stores document contents.

Design decisions:
- **One current KYC record per employee** (`employee_kyc`) with **versioned
  documents** (supersede, don't overwrite) rather than versioning the whole record.
- **Documents stored on disk OUTSIDE the web root**, referenced by DB rows;
  served only through an authorization-checked download script.
- **Branch scoping inherited** from `employees.branch_id` via the central
  `assertBranchAccess` helper.
- **Transfers:** KYC follows the employee (keyed on `employee_id`), independent of
  branch history rows.
- **Inactive employees:** KYC retained per retention policy, read-only.

---

## 22. Proposed KYC Workflow

```
Not Started → Draft → Submitted → Under Review → Verified
                              │           │
                              │           └──► Rejected → Corrected → Resubmitted → Under Review
                              │
                    (document-level) Verified doc → Expired → Renewal Required → Resubmitted
```

- Record-level status on `employee_kyc`; document-level status on
  `employee_kyc_documents`.
- Verified documents are **immutable**; a replacement creates a new version and
  supersedes the prior (`is_current=0`), preserving history.
- Expiry dates drive a "Renewal Required" state via a scheduled/derived check.

This is a recommendation; the exact states should be confirmed with the owner.

---

## 23. Proposed KYC Permission Matrix

| Action | Admin | HO User | Branch User |
|---|---|---|---|
| View KYC (own branch) | All | Authorized branches | **Own branch only** |
| View sensitive fields (full statutory/bank numbers) | Yes | Configurable | **Masked by default** |
| Enter / edit KYC draft | Yes | Yes | Own-branch employees only |
| Upload documents | Yes | Yes | Own-branch employees only |
| Submit for review | Yes | Yes | Yes (own branch) |
| Verify / Reject | Yes | Yes (per policy) | **No** |
| Download original document | Yes (logged) | Authorized (logged) | Own branch, logged, maybe restricted types |
| Configure KYC (types, retention) | Yes | No | No |
| View audit log | Yes | Read (scoped) | No |

Principle: **Branch Users collect and submit; they do not verify and do not see
full statutory identifiers by default.** All access is branch-scoped and logged.

---

## 24. KYC Privacy & Document Security Strategy

- **Least privilege** + field-level masking (show last 4 digits of statutory/bank
  IDs unless explicitly authorized).
- **Documents outside the web root**; unpredictable stored filenames (UUID/hash);
  never trust the original filename for storage.
- **Upload validation:** allowlist MIME + extension, magic-byte sniff, max size,
  reject executables/double extensions, block path traversal.
- **Download:** authorization-checked script, forced `Content-Disposition:
  attachment`, no direct URL access; every view/download audited.
- **At rest:** consider column encryption / DB-at-rest encryption for the most
  sensitive identifiers; encrypt or access-restrict the document directory.
- **Retention & deletion:** defined retention, archive/supersede rather than hard
  delete; ensure backups honor the policy.
- **Transport:** enforce HTTPS.
- **Audit metadata per event:** employee, actor user, role, action, timestamp,
  previous→new status, related document id, and (only if legally justified)
  IP/user-agent. **Never store document contents in the audit log.**

Events to capture: KYC created; field changed; document uploaded; document
replaced; submitted; verified; rejected; resubmitted; expired; viewed/downloaded
(where appropriate).

---

## 25. Proposed Files/Tables for Future KYC (not created)

Following existing conventions (flat pages + `admin/` for privileged, `includes/`
for shared, `assets/js/` for scripts):

```
kyc/
  kyc_list.php            # branch-scoped employee KYC index
  kyc_view.php            # single employee KYC (masked by role)
  kyc_edit.php            # draft entry/update (POST + CSRF)
  kyc_submit.php          # state transition handler
  kyc_document_upload.php # validated upload handler
  kyc_document_download.php # authz-checked forced download
admin/
  kyc_verify.php          # verify/reject queue (Admin/HO)
  kyc_config.php          # document types, retention (Admin)
includes/
  db.php                  # central prepared-statement helper (Phase 1)
  authz.php               # requireRole / assertBranchAccess (Phase 1)
  csrf.php                # csrf_token / csrf_verify (Phase 1)
  kyc_functions.php       # KYC domain logic (single source)
assets/js/
  kyc.js                  # client UX only (no security logic)

DB (reviewed migrations, Phase 2):
  employee_kyc
  employee_kyc_documents
  employee_kyc_audit_log
storage (OUTSIDE web root):
  /home/<user>/kyc_store/<employee_id>/<uuid>.<ext>
```

**None of the above is created by this audit.**

---

## 26. Regression Test Matrix (protect existing behavior during KYC work)

| Area | Must still pass |
|---|---|
| Login | Valid login works; invalid rejected; inactive blocked; hashed + (until migrated) legacy both work. |
| Attendance | Load grid; bulk status; save P/A/L/H/WO; leave→LWP conversion; OT/expense toggles; Branch-User today-only. |
| Monthly register | Screen matches DB; export matches screen; branch scoping intact. |
| Payroll | Paid-day math (P/WO=1, H=0.5, CL/SL/EL=1, A/L/LWP=0); OT/expense totals; screen==export. |
| Leave balance | Entitled/availed/balance correct; export matches. |
| Employee master | Add/edit; unique `employee_no`; activate/deactivate; category. |
| User management | Create/edit; last-admin protection; activate/deactivate; password reset. |
| Branch / sub-location | Add; OT/expense toggles persist. |
| Exports | Correct headers/filenames; no data leakage across branches. |
| Session | Login regenerate; logout destroys; timeout (after hardening). |

---

## 27. Prioritized Implementation Roadmap

- **Phase 0 — Critical security blockers:** C1 (SQLi → prepared statements), C2
  (secrets out + rotate), H4 (kill error exposure), H1 (attendance write IDOR),
  H2/H3 (leave-balance authz). Init Git baseline (M10).
- **Phase 1 — Pre-KYC hardening:** central DB/authz/CSRF helpers; H5/H6 (CSRF +
  GET→POST); H7 (password migration + remove fallback); H8 (session/cookies);
  M1–M5 (temp pw, enumeration, throttling, policy, export injection); security
  headers + HTTPS.
- **Phase 2 — KYC database foundation:** reviewed migrations for `employee_kyc`,
  `employee_kyc_documents`, `employee_kyc_audit_log`; add missing unique/FK
  constraints (M7/M8); storage dir outside web root (M12).
- **Phase 3 — KYC entry/UI:** branch-scoped list/view/edit; masked fields.
- **Phase 4 — Verification workflow:** submit/review/verify/reject/resubmit states.
- **Phase 5 — Document security:** validated uploads, versioning, authz downloads.
- **Phase 6 — KYC reporting/dashboard:** verification status, expiry alerts
  (isolated from general attendance/payroll exports).
- **Phase 7 — UAT / security regression:** run §26 + §30 matrices; pen-test the
  authz/IDOR/upload paths.

---

## 28. Recommended KYC MVP Scope

**Confirmed existing requirements (from code):** branch isolation, roles
Admin/HO/Branch, employee master keyed by `employee_no`, Staff/Labour categories.

**Recommended KYC MVP assumptions (require owner approval):**
- Structured identity + contact + address + one statutory ID + bank details.
- Document upload for a small fixed set (e.g. ID proof, address proof, bank proof)
  with expiry where relevant.
- Draft → Submit → Verify/Reject workflow.
- Branch Users enter/submit; Admin/HO verify; masked sensitive fields for Branch
  Users.
- Full audit log + secure document storage.

Defer to later: bulk import, OCR/auto-verification, multi-document versioning UI,
cross-branch analytics.

---

## 29. Open Decisions Required From Product Owner

1. Exact KYC field list and which are statutorily mandatory.
2. Which sensitive fields Branch Users may see vs. must be masked.
3. Is HO User global across all branches, or scoped to assigned branches?
4. "No attendance entry for a day" = blank or absent for payroll?
5. Are negative leave balances permitted/displayed intentionally?
6. Document types, max size, retention period, and deletion policy.
7. Whether at-rest encryption is required for statutory/bank identifiers.
8. Whether IP/user-agent may be recorded in the KYC audit log (privacy/legal).

---

## 30. Test Matrix for Future KYC

| Group | Scenario | Expected |
|---|---|---|
| Admin | Global employee visibility; review; verify | Allowed, logged |
| HO | Authorized-branch visibility; review per policy | Allowed within scope |
| Branch | Access another branch's KYC | **Denied** |
| Branch | URL/employee-id tampering | **Rejected** (assertBranchAccess) |
| Documents | Unauthorized download | **Denied**, logged |
| Documents | Invalid MIME/extension | **Rejected** |
| Documents | Oversized upload | **Rejected** |
| Documents | Renamed executable / double extension | **Rejected** |
| Documents | Path-traversal filename | **Rejected** |
| Workflow | Draft→Submitted | Allowed |
| Workflow | Submitted→Verified | Allowed (authorized role) |
| Workflow | Submitted→Rejected | Allowed with reason |
| Workflow | Rejected→Resubmitted | Allowed |
| Workflow | Replace verified document | New version, prior superseded |
| Workflow | Expired document | Renewal-required state |
| Audit | Every material event | Recorded immutably |
| Regression | Attendance/leave/payroll/exports/employee/user mgmt | All still pass (§26) |

---

*End of audit. No fixes, no KYC implementation, and no database changes were made.*

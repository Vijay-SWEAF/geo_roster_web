# GeoRoster GoDaddy Release Checksums

## Scope

- Runtime release commit: `79eb2f2aae0840aa88639b30118b88c9fa53ed23`
- Deployment set: 34 MUST DEPLOY runtime files from `docs/GEOROSTER_FTP_DEPLOYMENT_MANIFEST.md`.
- Hash algorithm: SHA-256.
- These hashes are for the development release files before FTP transfer.
- Do not include credentials, private configuration, secrets, uploads, logs, backups, SQL, or documentation in the public upload.

| Relative path | SHA-256 |
|---|---|
| `includes/security.php` | `e1151e8d201356a145402213f4ff3b4c1950923d25d219769195359aaa6a0b43` |
| `includes/auth_check.php` | `0e7cdae8c44c02f5f636f81dffe402571fe75baa7dc9c7c79adccfa2f7f0366f` |
| `includes/functions.php` | `3acabef61b5dc26bcf8b2bef130f7865357c2d167337617fb2d3a8af07b7111a` |
| `includes/header.php` | `73ab6899dbe7d2ae4cf2dadfec9ec92d8cd8c8fa5716c264a70920c64e86a37e` |
| `includes/kyc_service.php` | `05a08ffe7fccbd68adab4f4cbf1423e89f320b6162dc50cfd97d5d6e50c81bb8` |
| `admin/branch_locations.php` | `a1ba0bd5620431850d3f8f6c18a0d548f7ce575406e7a2ed01ffb0495ce4be13` |
| `admin/branches.php` | `ee2dd28a995609661cd4fc9dff4db641b24672d963587e3a4483020a3804706f` |
| `admin/create_user.php` | `a207f28e6001de9f14c722a1e2870d8f5a228f60add287809d28838ff91457a5` |
| `admin/edit_employee.php` | `8d0178a89842ce97d665795735844a035aaa1e04382b07ff0726f130db0724f2` |
| `admin/edit_user.php` | `86151205e8b82b9b00185550a022e2d31e2b5f1b211a2362785d3f10f87b04f5` |
| `admin/employees.php` | `628e7ec8b4024b41fffae7daa790eab48ff839b90b4b6d35e224658cdd6bbb61` |
| `admin/leave_entry.php` | `d9e24c5ea7a10469851a4f625f2af1f0bc501468eb0831646b8c9ab981870136` |
| `admin/leave_policy.php` | `266dae456c1b2261731b2d4729a20b42562c5d176ca0f6d7616dc0c09f2a755f` |
| `admin/reset_user_password.php` | `a0e607ffd34a34af59f95b8b97558afc749085b64a46bc17594a742590ec0854` |
| `admin/toggle_employee.php` | `0f67edcc301ec65eee6da4848c7f594f4903773d57179d7e629e8681e4aab6df` |
| `admin/toggle_user_status.php` | `9e0d106d01b0c7e1a5e040df48a17cb30355d0cde6b50e35cbb5f50677f6c526` |
| `admin/user_management.php` | `5fef4ca09b767532c39f3a4ccaad57556d3723612fd55e7985523cf52e5bb297` |
| `attendance_entry.php` | `ec30ce00a1ed4c55f03ee98062e8dc5dfdab1ffbadb9155415b8e1613fa48c4f` |
| `auth/login.php` | `735e745be9935ed8f71835ac98e39588ad91e28868b052bb4df7e5ef9319d62f` |
| `change_password.php` | `0658b12b017c3ff26dd8b2703e860eded60a78c469ba8f9df524c1b13de38b23` |
| `dashboard.php` | `a20925d914bd01ae192b62f29cbf85322fb3b9d6d194bdffc357038d000675eb` |
| `export_leave_balance.php` | `a5016f89bbacbb8c797883ce9a92339f0415f4298097661d395c096b3ef36e54` |
| `export_monthly_register.php` | `308b6373ed30bcd9cabd761711a84c0afa539545859222cbfe3b8de13f7c8766` |
| `export_payroll.php` | `c39aed74c841ebc37ae20d867c512b314932d20748a474ced58268d330cb85f4` |
| `kyc/employee_kyc.php` | `91fc8f358fecaaf0d845a39dc1814788c7b52f85ae604f567b845330cb639e92` |
| `kyc/review_queue.php` | `a609a7806f877817aa4a7f3c2766695b9661eda9dada18163459a101522cccc6` |
| `leave_balance.php` | `30e25b3a6624ca1376b83939e1736e2d80a4fcf0ee36a6724cc75688ab49e20d` |
| `logout.php` | `ed321280be007ee7f3ae7cd6c03f014f30254e549ad62daf2b9a0db8d3ff3432` |
| `management_dashboard.php` | `c8172191b4b5be9ec7b0ccc2c5c2d4d72a2a9a0a39b053b50a1cc48195e2f514` |
| `monthly_register.php` | `44c72222980766421c3479546f0ff19f97497c2b022ef8121d9ac68f0867d8ad` |
| `payroll_sheet.php` | `b0d907717ec06d1bb8b65dc805b491affd60ea2b684860fcc6377bf433bf5698` |
| `profile.php` | `f2324398e86790047adffb0c5a2e37d14692ce7f838949c125ed693fce687815` |
| `save_attendance.php` | `706fa680149f297e04682f2b4bf912ab1859f1207c71f3277b3efc58acc1c8fb` |
| `update_password.php` | `3c61d94ebda3db1d692f09bb4101678ef7b8a526e276100c567330986a6d4629` |

## Verification

The Product Owner should compute SHA-256 on the FTP staging files and compare every path before publishing. Any mismatch is a stop condition.

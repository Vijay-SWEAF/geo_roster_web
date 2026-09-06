# GeoRoster Employee KYC Document Security Architecture Design

> **Document Version:** 1.0  
> **Status:** ARCHITECTURAL DESIGN ONLY — NOT IMPLEMENTED IN PROMPT 03A  
> **Phase:** Prompt 03A — Foundation Phase  

---

## 1. Executive Notice

```text
NO KYC DOCUMENT STORAGE, UPLOAD, OR DOWNLOAD FUNCTIONALITY WAS IMPLEMENTED IN PROMPT 03A.
THIS DOCUMENT DEFINES THE MANDATORY ARCHITECTURAL SPECIFICATION FOR FUTURE DOCUMENT IMPLEMENTATION PHASES.
```

---

## 2. Storage Architecture & Location

1. **Storage Outside Webroot:**
   Future KYC uploaded files MUST be stored in a dedicated directory **completely outside the publicly served webroot** (e.g. `/home/<user>/georoster_kyc_vault/` or a private non-public directory).
   - **Forbidden Directory:** `/public_html/uploads/kyc/` or any web-accessible path.
   - Direct HTTP access to uploaded documents (e.g. `http://domain.com/uploads/kyc/doc.pdf`) MUST be impossible.

2. **Webroot Protection Fallback:**
   If infrastructure constraints force storage within the app tree, the directory MUST be protected by web server rules (e.g. `.htaccess` containing `Require all denied` or `Deny from all`) AND serve files exclusively through an authenticated PHP proxy controller.

---

## 3. Object Naming & Identifier Randomization

1. **Unpredictable Object Names:**
   Every uploaded file MUST be renamed upon receipt to a cryptographically random UUID or hash (e.g., `550e8400-e29b-41d4-a716-446655440000.dat`).
2. **Forbidden Filename Patterns:**
   Filenames MUST NEVER contain personal identifiers such as Aadhaar number, PAN, employee number, employee name, or original client filename.
3. **Original Filename Handling:**
   The original user-provided filename MUST be treated as untrusted metadata, sanitized against header injection and directory traversal, and stored separately in the database document metadata table.

---

## 4. File Type Allowlist & Validation Rules

Future file uploads MUST pass strict multi-layered server-side validation before storage:

1. **Extension Allowlist:**
   Only explicitly permitted extensions will be accepted: `.pdf`, `.jpeg`, `.jpg`, `.png`.
   - **Forbidden Extensions:** `.php`, `.php5`, `.phtml`, `.exe`, `.bat`, `.sh`, `.js`, `.html`, `.svg`, or double extensions (`.jpg.php`).

2. **MIME Type Allowlist:**
   Validation MUST inspect `finfo_file()` / magic bytes on the server:
   - `application/pdf`
   - `image/jpeg`
   - `image/png`

3. **Magic Byte / Header Verification:**
   The file signature MUST match the declared MIME type (e.g., `%PDF-` for PDFs, `\xFF\xD8\xFF` for JPEGs).

4. **Maximum File Size Limit:**
   Single document uploads MUST be capped at a reasonable limit (e.g., 5 MB maximum).

5. **Malware / Antivirus Strategy:**
   Where hosting infrastructure permits (e.g. ClamAV on cPanel/Linux), files MUST be scanned before moving to permanent storage. If local scanner binary is unavailable, uploads MUST be isolated in an un-executable staging folder and validated against strict image/PDF re-encoding libraries.

---

## 5. Streaming Access & Authorization Protocol

All document viewing and downloading MUST be mediated by an authorized controller endpoint (e.g. `kyc/document_stream.php?doc_id=123`):

```
User Request → Authenticated Session Check → Authoritative DB User/Role Lookup 
             → Load Document DB Record → Authoritative Employee Branch Check 
             → Role Authorization Matrix → Verify Document File Existence 
             → Log Stream Audit Event → Stream File with Security Headers
```

### Mandatory Streaming Headers

When streaming an authorized document, the controller MUST emit:

- `Content-Type: <validated_mime_type>`
- `Content-Disposition: inline; filename="sanitized_name.pdf"` (or `attachment`)
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`
- `Cache-Control: private, no-store, no-cache, must-revalidate`
- `Pragma: no-cache`

---

## 6. Document Versioning & Immutability

1. **Immutable Historical Records:**
   Verified document files MUST NOT be overwritten or deleted directly.
2. **Superseding Documents:**
   When an employee resubmits an updated document (e.g., renewed ID or corrected address proof), a new document record and file UUID MUST be created. The previous document record is marked as `is_current = 0` (superseded), preserving the historical record for audit and compliance.

---

## 7. Audit & Event Lifecycle

The document manager MUST log the following lifecycle events into `employee_kyc_history` and `security_audit_log`:

- Document Uploaded (Actor, Emp ID, Document Type, Version)
- Document Review Started (Actor, Emp ID, Document ID)
- Document Verified (Actor, Emp ID, Document ID)
- Document Rejected (Actor, Emp ID, Reason)
- Document Viewed / Streamed (Actor, Emp ID, Document ID, Timestamp)
- Document Superseded (Actor, Emp ID, Old Doc ID, New Doc ID)

---

## 8. Retention & Deletion Policy

1. **Policy Status:** `OWNER / LEGAL POLICY REQUIRED`
2. Document retention periods (e.g. 7 years post-employment for statutory compliance) MUST be confirmed by the product owner and legal counsel.
3. Automated retention purge scripts MUST securely un-link and erase physical files using multi-pass file overwrite or secure OS deletion routines.

---

*Architectural design document prepared for GeoRoster Prompt 03A.*

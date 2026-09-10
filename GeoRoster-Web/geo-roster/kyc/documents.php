<?php

require_once '../includes/auth_check.php';
require_once '../config/database.php';
require_once '../includes/security.php';
require_once '../includes/functions.php';
require_once '../includes/kyc_document_service.php';

$employeeId = validPositiveInt($_GET['employee_id'] ?? $_POST['employee_id'] ?? null);
if (!$employeeId) { $_SESSION['flash_error'] = 'Invalid employee selected.'; header('Location: ../admin/employees.php'); exit; }
$auth = requireAuthoritativeKycAccess($conn, $employeeId);
$employee = $auth['employee']; $user = $auth['user'];
$canManage = !empty($auth['can_sensitive']);
$profile = getKycProfile($conn, $employeeId);
$documents = ($profile && $canManage) ? getKycDocuments($conn, $employeeId) : [];
$pageTitle = 'KYC Documents';
$pageSubtitle = 'Private, audited document vault';
$basePath = '../';
define('APP_INCLUDED', true);
require_once '../includes/header.php';
?>
<div class="kyc-page">

    <!-- Breadcrumb Navigation -->
    <div class="kyc-breadcrumb" style="margin-bottom:16px;">
        <a href="../admin/employees.php">Employees</a>
        <span class="kyc-breadcrumb-separator">›</span>
        <a href="employee_kyc.php?employee_id=<?php echo $employeeId; ?>">Employee KYC</a>
        <span class="kyc-breadcrumb-separator">›</span>
        <strong>Documents</strong>
    </div>

    <div class="kyc-header" style="margin-bottom:16px;">
        <div class="kyc-header-title">
            KYC Documents
            <span style="font-size:14px; font-weight:400; color:#64748b;">- <?php echo htmlspecialchars($employee['employee_name']); ?></span>
        </div>
        <div class="kyc-summary-grid">
            <div class="kyc-summary-item">
                <span class="kyc-summary-label">Employee No</span>
                <span class="kyc-summary-value"><?php echo htmlspecialchars($employee["employee_no"]); ?></span>
            </div>
            <div class="kyc-summary-item">
                <span class="kyc-summary-label">KYC Status</span>
                <span class="kyc-summary-value"><?php echo htmlspecialchars($profile['kyc_status'] ?? 'NOT_STARTED'); ?></span>
            </div>
        </div>
    </div>

    <div style="background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:16px; margin-bottom:16px;">
        <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px;">
            <a href="employee_kyc.php?employee_id=<?php echo $employeeId; ?>" class="btn-secondary-link">← Back to Employee KYC</a>
        </div>
    </div>

    <?php if ($canManage) { ?>
        <div class="panel-card" style="margin-bottom:18px; background:#f0f9ff; border:1px solid #bfdbfe;">
            <div class="panel-title" style="color:#0284c7;">Upload KYC Document</div>
            <form method="post" action="document_upload.php" enctype="multipart/form-data" class="form-grid" style="margin-top:12px;">
                <?php echo csrfField(); ?>
                <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                <div>
                    <label for="document_type" style="display:block; margin-bottom:6px; font-weight:600;">Document Type</label>
                    <select id="document_type" name="document_type" required style="padding:10px 12px; border:1px solid #cbd5e1; border-radius:6px; width:100%;">
                        <?php foreach (getAllowedKycDocumentTypes() as $type) { ?>
                            <option value="<?php echo htmlspecialchars($type); ?>"><?php echo htmlspecialchars(str_replace('_', ' ', $type)); ?></option>
                        <?php } ?>
                    </select>
                </div>
                <div>
                    <label for="document_label" style="display:block; margin-bottom:6px; font-weight:600;">Label (for OTHER_KYC only)</label>
                    <input type="text" id="document_label" name="document_label" maxlength="120" placeholder="Optional custom label" style="padding:10px 12px; border:1px solid #cbd5e1; border-radius:6px; width:100%;">
                </div>
                <div style="grid-column:1 / -1;">
                    <label for="document" style="display:block; margin-bottom:6px; font-weight:600;">File (PDF, JPG, PNG)</label>
                    <input type="file" id="document" name="document" accept="application/pdf,image/jpeg,image/png" required style="padding:10px 12px; border:1px solid #cbd5e1; border-radius:6px; width:100%;">
                    <p style="font-size:12px; color:#64748b; margin:6px 0 0 0;">Accepted: PDF / JPG / PNG. Maximum: 5 MB.</p>
                </div>
                <div style="grid-column:1 / -1;">
                    <button type="submit" class="btn-generate">Upload Document</button>
                </div>
            </form>
        </div>
    <?php } else { ?>
        <div style="background:#f1f5f9; border:1px solid #cbd5e1; border-radius:8px; padding:14px; margin-bottom:16px;">
            <p style="color:#64748b; font-weight:600; margin:0;">Restricted Access</p>
            <p style="color:#64748b; font-size:13px; margin:8px 0 0 0;">Documents are managed by an authorized KYC Officer.</p>
        </div>
    <?php } ?>

    <?php if ($canManage) { ?>
        <div class="panel-card">
            <div class="panel-title">Document Versions</div>
            <div style="overflow-x:auto; margin-top:12px;">
                <table class="kyc-responsive-table" style="width:100%;">
                    <thead>
                        <tr>
                            <th>Type</th>
                            <th>Version</th>
                            <th>Status</th>
                            <th>Current</th>
                            <th>File Type</th>
                            <th>Size</th>
                            <th>Uploaded At</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if (!empty($documents)) { ?>
                            <?php foreach ($documents as $document) { ?>
                                <tr>
                                    <td><?php echo htmlspecialchars($document['document_label'] ?: str_replace('_', ' ', $document['document_type'])); ?></td>
                                    <td><?php echo (int)$document['version_no']; ?></td>
                                    <td><?php echo htmlspecialchars($document['lifecycle_status']); ?></td>
                                    <td><?php echo (int)$document['is_current'] === 1 ? '✓' : ''; ?></td>
                                    <td><?php echo htmlspecialchars($document['validated_mime']); ?></td>
                                    <td><?php echo number_format((int)$document['plaintext_size']); ?> B</td>
                                    <td style="font-size:12px;"><?php echo htmlspecialchars($document['uploaded_at']); ?></td>
                                    <td>
                                        <div style="display:flex; gap:6px; flex-wrap:wrap;">
                                            <form method="post" action="document_stream.php" target="_blank" style="display:inline;">
                                                <?php echo csrfField(); ?>
                                                <input type="hidden" name="document_id" value="<?php echo (int)$document['document_id']; ?>">
                                                <input type="hidden" name="mode" value="inline">
                                                <button type="submit" class="btn-secondary-link" style="font-size:11px; padding:4px 8px;">View</button>
                                            </form>
                                            <form method="post" action="document_stream.php" target="_blank" style="display:inline;">
                                                <?php echo csrfField(); ?>
                                                <input type="hidden" name="document_id" value="<?php echo (int)$document['document_id']; ?>">
                                                <input type="hidden" name="mode" value="download">
                                                <button type="submit" class="btn-secondary-link" style="font-size:11px; padding:4px 8px;">Download</button>
                                            </form>
                                        </div>
                                    </td>
                                </tr>
                            <?php } ?>
                        <?php } else { ?>
                            <tr>
                                <td colspan="8" style="text-align:center; padding:20px; color:#64748b; font-size:13px;">No documents recorded.</td>
                            </tr>
                        <?php } ?>
                    </tbody>
                </table>
            </div>
        </div>
    <?php } ?>

</div>

<?php require_once '../includes/footer.php'; ?>

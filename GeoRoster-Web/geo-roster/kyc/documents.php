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
$documents = $profile ? getKycDocuments($conn, $employeeId) : [];
$pageTitle = 'KYC Documents';
$pageSubtitle = 'Private, audited document vault';
$basePath = '../';
define('APP_INCLUDED', true);
require_once '../includes/header.php';
?>
<div class="panel-card" style="margin-bottom:18px;">
    <div class="panel-title">Employee KYC Documents</div>
    <p><strong><?php echo htmlspecialchars($employee['employee_no']); ?></strong> &middot; <?php echo htmlspecialchars($employee['employee_name']); ?> &middot; <?php echo htmlspecialchars(getBranchName($conn, $employee['branch_id'])); ?></p>
    <p>KYC Status: <strong><?php echo htmlspecialchars($profile['kyc_status'] ?? 'NOT_STARTED'); ?></strong></p>
    <?php if ($canManage) { ?>
        <form method="post" action="document_upload.php" enctype="multipart/form-data" class="form-grid">
            <?php echo csrfField(); ?>
            <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
            <label>Document Type
                <select name="document_type" required>
                    <?php foreach (getAllowedKycDocumentTypes() as $type) { ?><option value="<?php echo htmlspecialchars($type); ?>"><?php echo htmlspecialchars(str_replace('_', ' ', $type)); ?></option><?php } ?>
                </select>
            </label>
            <label>Other KYC Label (only for OTHER_KYC)
                <input type="text" name="document_label" maxlength="120">
            </label>
            <label>File
                <input type="file" name="document" accept="application/pdf,image/jpeg,image/png" required>
            </label>
            <p>Accepted: PDF / JPG / PNG. Maximum: 5 MB.</p>
            <button type="submit" class="btn-generate">Upload Document</button>
        </form>
    <?php } else { ?>
        <p>Documents are managed by an authorized KYC Officer.</p>
    <?php } ?>
</div>
<div class="panel-card">
    <div class="panel-title">Document Versions</div>
    <div class="table-wrap"><table><thead><tr><th>Type</th><th>Version</th><th>Status</th><th>Current</th><th>File Type</th><th>Size</th><th>Uploaded At</th><th>Action</th></tr></thead><tbody>
    <?php foreach ($documents as $document) { ?>
        <tr><td><?php echo htmlspecialchars($document['document_label'] ?: str_replace('_', ' ', $document['document_type'])); ?></td><td><?php echo (int)$document['version_no']; ?></td><td><?php echo htmlspecialchars($document['lifecycle_status']); ?></td><td><?php echo (int)$document['is_current'] === 1 ? 'Yes' : 'No'; ?></td><td><?php echo htmlspecialchars($document['validated_mime']); ?></td><td><?php echo number_format((int)$document['plaintext_size']); ?> bytes</td><td><?php echo htmlspecialchars($document['uploaded_at']); ?></td><td><?php if ($canManage) { ?><form method="post" action="document_stream.php" target="_blank" style="display:inline"><?php echo csrfField(); ?><input type="hidden" name="document_id" value="<?php echo (int)$document['document_id']; ?>"><input type="hidden" name="mode" value="inline"><button type="submit" title="View document">View</button></form> <form method="post" action="document_stream.php" target="_blank" style="display:inline"><?php echo csrfField(); ?><input type="hidden" name="document_id" value="<?php echo (int)$document['document_id']; ?>"><input type="hidden" name="mode" value="download"><button type="submit" title="Download document">Download</button></form><?php } else { ?>Managed by KYC Officer<?php } ?></td></tr>
    <?php } if (!$documents) { ?><tr><td colspan="8">No documents recorded.</td></tr><?php } ?>
    </tbody></table></div>
</div>
<?php require_once '../includes/footer.php'; ?>

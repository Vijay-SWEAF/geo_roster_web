<?php

require_once __DIR__ . '/kyc_service.php';

define('KYC_DOCUMENT_MAX_BYTES', 5242880);

define('KYC_DOCUMENT_STATUS_ACTIVE', 'ACTIVE');
define('KYC_DOCUMENT_STATUS_PENDING_AMENDMENT', 'PENDING_AMENDMENT');
define('KYC_DOCUMENT_STATUS_SUPERSEDED', 'SUPERSEDED');
define('KYC_DOCUMENT_STATUS_REJECTED', 'REJECTED');
define('KYC_DOCUMENT_STATUS_CANCELLED', 'CANCELLED');

define('KYC_DOCUMENT_SCHEME', 'GRKYCDOC1');

function getAllowedKycDocumentTypes() {
    return [
        'PAN_CARD', 'AADHAAR_CARD', 'UAN_PROOF', 'ESIC_CARD',
        'ADDRESS_PROOF', 'EMPLOYEE_PHOTO', 'OTHER_KYC'
    ];
}

function getKycVaultRoot() {
    $configured = getenv('GEOROSTER_KYC_VAULT_PATH');
    $root = ($configured !== false && $configured !== '')
        ? $configured
        : dirname(__DIR__, 3) . '/georoster-kyc-vault';

    if (!is_string($root) || $root === '' || $root[0] !== DIRECTORY_SEPARATOR) {
        throw new RuntimeException('KYC document vault is unavailable.');
    }

    $realRoot = realpath($root);
    $documentRoot = $_SERVER['DOCUMENT_ROOT'] ?? '';
    $appRoot = realpath(dirname(__DIR__));
    if ($realRoot === false || !is_dir($realRoot) || $documentRoot === '' || $appRoot === false) {
        throw new RuntimeException('KYC document vault is unavailable.');
    }

    $realRoot = rtrim($realRoot, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR;
    $documentRoot = rtrim(realpath($documentRoot) ?: $documentRoot, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR;
    $appRoot = rtrim($appRoot, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR;
    if (strpos($realRoot, $documentRoot) === 0 || strpos($realRoot, $appRoot) === 0) {
        throw new RuntimeException('KYC document vault is unavailable.');
    }
    return rtrim($realRoot, DIRECTORY_SEPARATOR);
}

function assertKycVaultWritable() {
    $root = getKycVaultRoot();
    if (!is_readable($root) || !is_writable($root)) {
        throw new RuntimeException('KYC document vault is unavailable.');
    }
    return $root;
}

function deriveKycDocumentEncryptionKey($providedKey = null) {
    $master = getKycEncryptionKey($providedKey);
    return hash_hkdf('sha256', $master, 32, 'georoster-kyc-document-v1');
}

function deriveKycDocumentHmacKey($providedKey = null) {
    $master = getKycHmacKey($providedKey);
    return hash_hkdf('sha256', $master, 32, 'georoster-kyc-document-hmac-v1');
}

function generateKycStorageKey() {
    $random = bin2hex(random_bytes(32));
    return substr($random, 0, 2) . '/' . substr($random, 2, 2) . '/' . $random . '.vault';
}

function kycDocumentPath($root, $storageKey) {
    if (!preg_match('/\A[0-9a-f]{2}\/[0-9a-f]{2}\/[0-9a-f]{64}\.vault\z/', $storageKey)) {
        throw new RuntimeException('KYC document vault is unavailable.');
    }
    $root = rtrim($root, DIRECTORY_SEPARATOR);
    $path = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $storageKey);
    $parent = realpath(dirname($path));
    if ($parent === false || strpos($parent . DIRECTORY_SEPARATOR, $root . DIRECTORY_SEPARATOR) !== 0) {
        throw new RuntimeException('KYC document vault is unavailable.');
    }
    return $path;
}

function encryptKycDocument($plaintext, $key = null) {
    $key = deriveKycDocumentEncryptionKey($key);
    if (function_exists('sodium_crypto_secretbox')) {
        $nonce = random_bytes(SODIUM_CRYPTO_SECRETBOX_NONCEBYTES);
        return KYC_DOCUMENT_SCHEME . ':S:' . base64_encode($nonce . sodium_crypto_secretbox($plaintext, $nonce, $key));
    }
    $iv = random_bytes(12);
    $tag = '';
    $ciphertext = openssl_encrypt($plaintext, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
    if ($ciphertext === false) {
        throw new RuntimeException('KYC document encryption failed.');
    }
    return KYC_DOCUMENT_SCHEME . ':G:' . base64_encode($iv . $tag . $ciphertext);
}

function decryptKycDocument($payload, $key = null) {
    if (strpos((string)$payload, KYC_DOCUMENT_SCHEME . ':') !== 0) {
        throw new RuntimeException('KYC document decryption failed.');
    }
    $parts = explode(':', $payload, 3);
    $raw = base64_decode($parts[2] ?? '', true);
    if ($raw === false) {
        throw new RuntimeException('KYC document decryption failed.');
    }
    $key = deriveKycDocumentEncryptionKey($key);
    if (($parts[1] ?? '') === 'S') {
        $nonceBytes = SODIUM_CRYPTO_SECRETBOX_NONCEBYTES;
        if (strlen($raw) <= $nonceBytes) throw new RuntimeException('KYC document decryption failed.');
        $plain = sodium_crypto_secretbox_open(substr($raw, $nonceBytes), substr($raw, 0, $nonceBytes), $key);
    } elseif (($parts[1] ?? '') === 'G' && strlen($raw) > 28) {
        $plain = openssl_decrypt(substr($raw, 28), 'aes-256-gcm', $key, OPENSSL_RAW_DATA, substr($raw, 0, 12), substr($raw, 12, 16));
    } else {
        $plain = false;
    }
    if ($plain === false) throw new RuntimeException('KYC document decryption failed.');
    return $plain;
}

function validateKycDocumentUpload($file, $documentType, $documentLabel = '') {
    if (!is_array($file) || ($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK || !is_uploaded_file($file['tmp_name'])) {
        throw new InvalidArgumentException('Upload failed.');
    }
    if (($file['size'] ?? 0) <= 0 || $file['size'] > KYC_DOCUMENT_MAX_BYTES) throw new InvalidArgumentException('File must be between 1 byte and 5 MB.');
    if (!in_array($documentType, getAllowedKycDocumentTypes(), true)) throw new InvalidArgumentException('Invalid document type.');
    $original = basename((string)$file['name']);
    if (preg_match('/\.[^.]+\.[^.]+$/', $original)) throw new InvalidArgumentException('Unsafe filename.');
    $extension = strtolower(pathinfo($original, PATHINFO_EXTENSION));
    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $mime = $finfo->file($file['tmp_name']);
    $allowed = ['application/pdf' => 'pdf', 'image/jpeg' => 'jpg', 'image/png' => 'png'];
    if (!isset($allowed[$mime])) throw new InvalidArgumentException('Unsupported document format.');
    if ($documentType === 'EMPLOYEE_PHOTO' && $mime === 'application/pdf') throw new InvalidArgumentException('Employee photo must be JPEG or PNG.');
    if (!in_array($extension, $mime === 'image/jpeg' ? ['jpg','jpeg'] : [$allowed[$mime]], true)) throw new InvalidArgumentException('File extension does not match content.');
    $bytes = file_get_contents($file['tmp_name'], false, null, 0, 12);
    if ($mime === 'application/pdf' && substr($bytes, 0, 5) !== '%PDF-') throw new InvalidArgumentException('Invalid PDF signature.');
    if ($mime === 'image/jpeg' && substr($bytes, 0, 3) !== "\xFF\xD8\xFF") throw new InvalidArgumentException('Invalid JPEG signature.');
    if ($mime === 'image/png' && substr($bytes, 0, 8) !== "\x89PNG\r\n\x1a\n") throw new InvalidArgumentException('Invalid PNG signature.');
    if ($mime !== 'application/pdf') {
        $dimensions = @getimagesize($file['tmp_name']);
        if (!$dimensions || $dimensions[0] < 1 || $dimensions[1] < 1 || $dimensions[0] > 20000 || $dimensions[1] > 20000) throw new InvalidArgumentException('Invalid image dimensions.');
    }
    $label = trim((string)$documentLabel);
    if ($documentType === 'OTHER_KYC') {
        if ($label === '' || mb_strlen($label) > 120 || !preg_match('/\A[A-Za-z0-9][A-Za-z0-9 .,()_-]*\z/', $label) || preg_match('/\d[\s-]?\d[\s-]?\d[\s-]?\d[\s-]?\d[\s-]?\d[\s-]?\d[\s-]?\d/', $label) || preg_match('/\A[A-Z]{5}\d{4}[A-Z]\z/i', $label)) throw new InvalidArgumentException('Invalid document label.');
    } else {
        $label = '';
    }
    return [$original, $mime, $allowed[$mime], $label];
}

function getKycDocumentById($conn, $documentId) {
    $stmt = $conn->prepare('SELECT d.*, e.employee_no, e.employee_name, e.branch_id, k.kyc_status FROM employee_kyc_documents d JOIN employees e ON e.employee_id = d.employee_id JOIN employee_kyc k ON k.kyc_id = d.kyc_id WHERE d.document_id = ? LIMIT 1');
    $documentId = (int)$documentId;
    $stmt->bind_param('i', $documentId); $stmt->execute();
    return $stmt->get_result()->fetch_assoc() ?: null;
}

function requireKycDocumentAccess($conn, $documentId) {
    $sessionUserId = (int)($_SESSION['user_id'] ?? 0);
    $user = getAuthoritativeUser($conn, $sessionUserId);
    if (!$user || (int)$user['is_active'] !== 1 || ($user['role_name'] !== 'Admin' && !hasKycOfficerPermission($conn, $sessionUserId))) {
        http_response_code(403); exit('KYC document permission required.');
    }
    $document = getKycDocumentById($conn, $documentId);
    if (!$document) { http_response_code(404); exit('Document not found.'); }
    if ($user['role_name'] === 'Branch User' && (int)$user['branch_id'] !== (int)$document['branch_id']) {
        auditEvent($conn, 'kyc_document_access_denied', 'employee_kyc_document', (int)$documentId);
        http_response_code(403); exit('Access denied.');
    }
    return [$user, $document];
}

function getKycDocuments($conn, $employeeId) {
    $stmt = $conn->prepare('SELECT document_id, document_type, document_label, version_no, is_current, lifecycle_status, validated_mime, file_extension, plaintext_size, uploaded_by, uploaded_at, amendment_id FROM employee_kyc_documents WHERE employee_id = ? ORDER BY document_type, version_no DESC');
    $employeeId = (int)$employeeId; $stmt->bind_param('i', $employeeId); $stmt->execute();
    $rows = []; $result = $stmt->get_result(); while ($row = $result->fetch_assoc()) $rows[] = $row; return $rows;
}

function uploadKycDocument($conn, $employeeId, $documentType, $documentLabel, $file, $actorId) {
    $auth = requireAuthoritativeKycAccess($conn, $employeeId);
    if (!$auth['can_sensitive']) { http_response_code(403); exit('KYC document permission required.'); }
    $profile = getKycProfile($conn, $employeeId);
    if (!$profile) throw new InvalidArgumentException('KYC profile not found.');
    $activeAmendment = getKycActiveAmendment($conn, (int)$profile['kyc_id']);
    if ($profile['kyc_status'] === KYC_STATUS_VERIFIED && !$activeAmendment) throw new InvalidArgumentException('Verified KYC requires an active amendment for document replacement.');
    [$original, $mime, $extension, $label] = validateKycDocumentUpload($file, $documentType, $documentLabel);
    $root = assertKycVaultWritable();
    $storageKey = generateKycStorageKey(); $finalPath = kycDocumentPath($root, $storageKey); $dir = dirname($finalPath);
    if (!is_dir($dir) && !mkdir($dir, 0700, true)) throw new RuntimeException('KYC document vault is unavailable.');
    @chmod($dir, 0700);
    $plaintext = file_get_contents($file['tmp_name']);
    $encrypted = encryptKycDocument($plaintext);
    $tempPath = tempnam($root, '.kyc-upload-');
    if ($tempPath === false || file_put_contents($tempPath, $encrypted, LOCK_EX) === false) throw new RuntimeException('KYC document storage failed.');
    chmod($tempPath, 0600);
    $status = $activeAmendment ? KYC_DOCUMENT_STATUS_PENDING_AMENDMENT : KYC_DOCUMENT_STATUS_ACTIVE;
    $isCurrent = $activeAmendment ? 0 : 1; $amendmentId = $activeAmendment ? (int)$activeAmendment['amendment_id'] : null;
    $hmac = hash_hmac('sha256', $plaintext, deriveKycDocumentHmacKey());
    $originalEnc = encryptKycField($original);
    $conn->begin_transaction();
    try {
        $lock = $conn->prepare('SELECT COALESCE(MAX(version_no), 0) FROM employee_kyc_documents WHERE employee_id = ? AND document_type = ? FOR UPDATE');
        $lock->bind_param('is', $employeeId, $documentType); $lock->execute(); $version = (int)$lock->get_result()->fetch_row()[0] + 1;
        if ($isCurrent) {
            $old = $conn->prepare("UPDATE employee_kyc_documents SET is_current = 0, lifecycle_status = 'SUPERSEDED', superseded_at = NOW(), updated_at = NOW() WHERE employee_id = ? AND document_type = ? AND is_current = 1 AND lifecycle_status = 'ACTIVE'");
            $old->bind_param('is', $employeeId, $documentType); $old->execute();
        }
        if (!rename($tempPath, $finalPath)) throw new RuntimeException('KYC document storage finalization failed.');
        $stmt = $conn->prepare('INSERT INTO employee_kyc_documents (kyc_id, employee_id, amendment_id, document_type, document_label, version_no, is_current, lifecycle_status, original_filename_enc, validated_mime, file_extension, plaintext_size, encrypted_size, content_hmac, storage_key, encryption_scheme, uploaded_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
        $kycId=(int)$profile['kyc_id']; $plainSize=strlen($plaintext); $encSize=strlen($encrypted); $scheme=KYC_DOCUMENT_SCHEME;
        $stmt->bind_param('iiissiissssiisssi', $kycId,$employeeId,$amendmentId,$documentType,$label,$version,$isCurrent,$status,$originalEnc,$mime,$extension,$plainSize,$encSize,$hmac,$storageKey,$scheme,$actorId); $stmt->execute(); $documentId=$stmt->insert_id;
        $historyAction = 'kyc_document_uploaded';
        $historyRemark = 'Document type ' . $documentType . ', version ' . $version . ', status ' . $status;
        $history = $conn->prepare('INSERT INTO employee_kyc_history (kyc_id, employee_id, actor_user_id, action, previous_status, new_status, remarks, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())');
        $previousStatus = KYC_STATUS_VERIFIED; $newStatus = KYC_STATUS_VERIFIED;
        $history->bind_param('iiissss', $kycId, $employeeId, $actorId, $historyAction, $previousStatus, $newStatus, $historyRemark); $history->execute();
        $conn->commit();
        auditEvent($conn, 'kyc_document_uploaded', 'employee_kyc_document', $documentId, ['document_type'=>$documentType,'version'=>$version,'status'=>$status]);
        return $documentId;
    } catch (Throwable $e) { $conn->rollback(); if (is_file($tempPath)) unlink($tempPath); if (is_file($finalPath)) unlink($finalPath); throw $e; }
}

function streamKycDocument($conn, $documentId, $mode) {
    [$user, $document] = requireKycDocumentAccess($conn, $documentId);
    $root = getKycVaultRoot(); $path = kycDocumentPath($root, $document['storage_key']);
    if (!is_file($path) || !is_readable($path)) { http_response_code(404); exit('Document not found.'); }
    try { $plain = decryptKycDocument(file_get_contents($path)); } catch (Throwable $e) { error_log('KYC document stream failed.'); http_response_code(500); exit('Document unavailable.'); }
    auditEvent($conn, $mode === 'download' ? 'kyc_document_downloaded' : 'kyc_document_viewed', 'employee_kyc_document', $documentId, ['document_type'=>$document['document_type'],'version'=>(int)$document['version_no']]);
    $safeName = preg_replace('/[^A-Za-z0-9_-]/', '_', $document['document_type']) . '_v' . (int)$document['version_no'] . '.' . $document['file_extension'];
    header('Content-Type: ' . $document['validated_mime']); header('Content-Disposition: ' . ($mode === 'download' ? 'attachment' : 'inline') . '; filename="' . $safeName . '"'); header('X-Content-Type-Options: nosniff'); header('X-Frame-Options: SAMEORIGIN'); header('Cache-Control: private, no-store, no-cache, must-revalidate'); header('Pragma: no-cache'); header('Expires: 0'); echo $plain; exit;
}

function promotePendingKycDocuments($conn, $employeeId, $amendmentId) {
    $stmt = $conn->prepare('SELECT document_id, document_type FROM employee_kyc_documents WHERE employee_id = ? AND amendment_id = ? AND lifecycle_status = ? FOR UPDATE');
    $pending = KYC_DOCUMENT_STATUS_PENDING_AMENDMENT; $employeeId=(int)$employeeId; $amendmentId=(int)$amendmentId;
    $stmt->bind_param('iis', $employeeId, $amendmentId, $pending); $stmt->execute(); $result = $stmt->get_result();
    while ($document = $result->fetch_assoc()) {
        $old = $conn->prepare("UPDATE employee_kyc_documents SET is_current = 0, lifecycle_status = 'SUPERSEDED', superseded_at = NOW(), updated_at = NOW() WHERE employee_id = ? AND document_type = ? AND is_current = 1 AND lifecycle_status = 'ACTIVE'");
        $old->bind_param('is', $employeeId, $document['document_type']); $old->execute();
        $active = KYC_DOCUMENT_STATUS_ACTIVE; $current = 1; $documentId=(int)$document['document_id'];
        $update = $conn->prepare('UPDATE employee_kyc_documents SET is_current = ?, lifecycle_status = ?, updated_at = NOW() WHERE document_id = ?');
        $update->bind_param('isi', $current, $active, $documentId); $update->execute();
        auditEvent($conn, 'kyc_document_promoted', 'employee_kyc_document', $documentId, ['amendment_id'=>$amendmentId]);
    }
}

function rejectPendingKycDocuments($conn, $employeeId, $amendmentId, $status) {
    $stmt = $conn->prepare('UPDATE employee_kyc_documents SET lifecycle_status = ?, is_current = 0, updated_at = NOW() WHERE employee_id = ? AND amendment_id = ? AND lifecycle_status = ?');
    $pending = KYC_DOCUMENT_STATUS_PENDING_AMENDMENT; $employeeId=(int)$employeeId; $amendmentId=(int)$amendmentId;
    $stmt->bind_param('siis', $status, $employeeId, $amendmentId, $pending); $stmt->execute();
}

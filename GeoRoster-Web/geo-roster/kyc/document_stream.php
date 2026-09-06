<?php

require_once '../includes/auth_check.php';
require_once '../config/database.php';
require_once '../includes/security.php';
require_once '../includes/kyc_document_service.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') { http_response_code(405); exit('Method not allowed.'); }
requireCsrf();
$documentId = validPositiveInt($_POST['document_id'] ?? null);
if (!$documentId) { http_response_code(400); exit('Invalid document.'); }
$mode = ($_POST['mode'] ?? 'inline') === 'download' ? 'download' : 'inline';
streamKycDocument($conn, $documentId, $mode);

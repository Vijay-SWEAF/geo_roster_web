<?php

require_once "../includes/auth_check.php";
require_once "../config/database.php";
require_once "../includes/security.php";
require_once "../includes/functions.php";
require_once "../includes/kyc_document_service.php";
require_once "../includes/kyc_bank_service.php";
require_once "../includes/employee_benefit_service.php";

$employeeId = validPositiveInt($_GET["employee_id"] ?? ($_POST["employee_id"] ?? null));
if (!$employeeId) {
    $_SESSION["flash_error"] = "Invalid employee selected.";
    header("Location: ../admin/employees.php");
    exit;
}

// Authoritative security check (re-verifies active status, role, and branch live from DB)
$auth = requireAuthoritativeKycAccess($conn, $employeeId);
$user = $auth["user"];
$employee = $auth["employee"];
$userRole = $user["role_name"];
$isKycOfficer = !empty($auth["is_kyc_officer"]);
$canSensitive = !empty($auth["can_sensitive"]);

// Handle Workflow State Transitions & Data Entry (POST + CSRF)
if ($_SERVER["REQUEST_METHOD"] === "POST") {
    requirePostWithCsrf();
    $action = trim($_POST["action"] ?? "");

    if ($action === "save_basic") {
        $dob = trim($_POST["date_of_birth"] ?? "");
        $mobile = trim($_POST["mobile_number"] ?? "");
        $currentAddr = trim($_POST["current_address"] ?? "");
        $permAddr = trim($_POST["permanent_address"] ?? "");
        $sameAsCurrent = isset($_POST["same_as_current"]) ? 1 : 0;

        if (updateKycBasicData($conn, $employeeId, $dob, $mobile, $currentAddr, $permAddr, $sameAsCurrent)) {
            $_SESSION["flash_message"] = "Basic KYC details updated successfully.";
        }
    } elseif ($action === "save_statutory") {
        $panApp = isset($_POST["pan_applicable"]) ? 1 : 0;
        $aadhaarApp = isset($_POST["aadhaar_applicable"]) ? 1 : 0;
        $uanApp = isset($_POST["uan_applicable"]) ? 1 : 0;
        $esicApp = isset($_POST["esic_applicable"]) ? 1 : 0;

        $panRaw = trim($_POST["pan_number"] ?? "");
        $aadhaarRaw = trim($_POST["aadhaar_number"] ?? "");
        $uanRaw = trim($_POST["uan_number"] ?? "");
        $esicRaw = trim($_POST["esic_number"] ?? "");

        if (updateKycStatutoryData($conn, $employeeId, $panApp, $aadhaarApp, $uanApp, $esicApp, $panRaw, $aadhaarRaw, $uanRaw, $esicRaw)) {
            $_SESSION["flash_message"] = "Statutory KYC details updated successfully.";
        }
    } elseif ($action === "save_bank") {
        if (saveKycBankDetails($conn, $employeeId, $_POST["account_number"] ?? "", $_POST["confirm_account_number"] ?? "", $_POST["ifsc_code"] ?? "", $_POST["account_type"] ?? "", $_POST["branch_name"] ?? "")) {
            $_SESSION["flash_message"] = "Bank details updated successfully.";
        }
    } elseif ($action === "reveal") {
        $fieldToReveal = trim($_POST["field_name"] ?? "");
        $revealedVal = revealKycField($conn, $employeeId, $fieldToReveal);
        $_SESSION["revealed_field"] = $fieldToReveal;
        $_SESSION["revealed_value"] = $revealedVal;
        $_SESSION["flash_message"] = "Unmasked value revealed for " . strtoupper($fieldToReveal) . " (Audit Logged).";
    } elseif ($action === "reveal_bank_account") {
        $_SESSION["revealed_bank_account"] = revealKycBankAccount($conn, $employeeId);
        $_SESSION["flash_message"] = "Bank account number revealed (Audit Logged).";
    } elseif ($action === "start") {
        startKycProfile($conn, $employeeId, $user["user_id"]);
        $_SESSION["flash_message"] = "KYC profile started in Draft status.";
    } elseif ($action === "submit") {
        if (transitionKycStatus($conn, $employeeId, KYC_STATUS_SUBMITTED, $user["user_id"])) {
            $_SESSION["flash_message"] = "KYC profile submitted for verification review.";
        }
    } elseif ($action === "start_review") {
        if (transitionKycStatus($conn, $employeeId, KYC_STATUS_UNDER_REVIEW, $user["user_id"])) {
            $_SESSION["flash_message"] = "KYC profile is now Under Review.";
        }
    } elseif ($action === "verify") {
        if (transitionKycStatus($conn, $employeeId, KYC_STATUS_VERIFIED, $user["user_id"])) {
            $_SESSION["flash_message"] = "KYC profile has been Internally Verified.";
        }
    } elseif ($action === "reject") {
        $reason = trim($_POST["rejection_reason"] ?? "");
        if ($reason === "") {
            $_SESSION["flash_error"] = "Rejection reason is required.";
            header("Location: employee_kyc.php?employee_id=" . $employeeId);
            exit;
        }
        if (transitionKycStatus($conn, $employeeId, KYC_STATUS_REJECTED, $user["user_id"], $reason)) {
            $_SESSION["flash_error"] = "KYC profile has been rejected.";
        }
    } elseif ($action === "reopen") {
        if (transitionKycStatus($conn, $employeeId, KYC_STATUS_DRAFT, $user["user_id"], "Re-opened for draft corrections")) {
            $_SESSION["flash_message"] = "KYC profile re-opened for corrections.";
        }
    } elseif ($action === "request_amendment") {
        $reason = trim($_POST["request_reason"] ?? "");
        if (requestKycAmendment($conn, $employeeId, $reason)) {
            $_SESSION["flash_message"] = "KYC amendment requested and draft created.";
        }
    } elseif ($action === "save_amendment_basic") {
        $amendmentId = validPositiveInt($_POST["amendment_id"] ?? null);
        $dob = trim($_POST["date_of_birth"] ?? "");
        $mobile = trim($_POST["mobile_number"] ?? "");
        $currentAddr = trim($_POST["current_address"] ?? "");
        $permAddr = trim($_POST["permanent_address"] ?? "");
        $sameAsCurrent = isset($_POST["same_as_current"]) ? 1 : 0;

        if (updateKycAmendmentBasicData($conn, $employeeId, $amendmentId, $dob, $mobile, $currentAddr, $permAddr, $sameAsCurrent)) {
            $_SESSION["flash_message"] = "Amendment basic details updated successfully.";
        }
    } elseif ($action === "save_amendment_statutory") {
        $amendmentId = validPositiveInt($_POST["amendment_id"] ?? null);
        $panApp = isset($_POST["pan_applicable"]) ? 1 : 0;
        $aadhaarApp = isset($_POST["aadhaar_applicable"]) ? 1 : 0;
        $uanApp = isset($_POST["uan_applicable"]) ? 1 : 0;
        $esicApp = isset($_POST["esic_applicable"]) ? 1 : 0;

        $panRaw = trim($_POST["pan_number"] ?? "");
        $aadhaarRaw = trim($_POST["aadhaar_number"] ?? "");
        $uanRaw = trim($_POST["uan_number"] ?? "");
        $esicRaw = trim($_POST["esic_number"] ?? "");

        if (updateKycAmendmentStatutoryData($conn, $employeeId, $amendmentId, $panApp, $aadhaarApp, $uanApp, $esicApp, $panRaw, $aadhaarRaw, $uanRaw, $esicRaw)) {
            $_SESSION["flash_message"] = "Amendment statutory details updated successfully.";
        }
    } elseif ($action === "save_amendment_bank") {
        $amendmentId = validPositiveInt($_POST["amendment_id"] ?? null);
        if (updateKycBankAmendmentDetails($conn, $employeeId, $amendmentId, $_POST["account_number"] ?? "", $_POST["confirm_account_number"] ?? "", $_POST["ifsc_code"] ?? "", $_POST["account_type"] ?? "", $_POST["branch_name"] ?? "")) {
            $_SESSION["flash_message"] = "Amendment bank details updated successfully.";
        }
    } elseif ($action === "save_benefit_status") {
        if (saveGroupMedicalCoverage($conn, $employeeId, $_POST["group_medical_covered"] ?? null)) {
            $_SESSION["flash_message"] = "Employee benefit status updated successfully.";
        }
    } elseif ($action === "submit_amendment") {
        $amendmentId = validPositiveInt($_POST["amendment_id"] ?? null);
        if (submitKycAmendment($conn, $employeeId, $amendmentId)) {
            $_SESSION["flash_message"] = "KYC amendment submitted for verification review.";
        }
    } elseif ($action === "start_review_amendment") {
        $amendmentId = validPositiveInt($_POST["amendment_id"] ?? null);
        if (startReviewKycAmendment($conn, $employeeId, $amendmentId)) {
            $_SESSION["flash_message"] = "KYC amendment review initiated.";
        }
    } elseif ($action === "approve_amendment") {
        $amendmentId = validPositiveInt($_POST["amendment_id"] ?? null);
        if (approveKycAmendment($conn, $employeeId, $amendmentId)) {
            $_SESSION["flash_message"] = "KYC amendment approved and applied to live profile.";
        }
    } elseif ($action === "reject_amendment") {
        $amendmentId = validPositiveInt($_POST["amendment_id"] ?? null);
        $reason = trim($_POST["rejection_reason"] ?? "");
        if ($reason === "") {
            $_SESSION["flash_error"] = "Rejection reason is required.";
            header("Location: employee_kyc.php?employee_id=" . $employeeId);
            exit;
        }
        if (rejectKycAmendment($conn, $employeeId, $amendmentId, $reason)) {
            $_SESSION["flash_error"] = "KYC amendment has been rejected. Live profile remains unchanged.";
        }
    } elseif ($action === "cancel_amendment") {
        $amendmentId = validPositiveInt($_POST["amendment_id"] ?? null);
        if (cancelKycAmendment($conn, $employeeId, $amendmentId)) {
            $_SESSION["flash_message"] = "KYC amendment cancelled.";
        }
    } elseif ($action === "revise_amendment") {
        $amendmentId = validPositiveInt($_POST["amendment_id"] ?? null);
        if (reviseKycAmendment($conn, $employeeId, $amendmentId)) {
            $_SESSION["flash_message"] = "Rejected amendment re-opened for draft corrections.";
        }
    } else {
        $_SESSION["flash_error"] = "Invalid action requested.";
    }

    header("Location: employee_kyc.php?employee_id=" . $employeeId);
    exit;
}

// GET Page Rendering
$kycProfile = getKycProfile($conn, $employeeId);
$kycPrivate = getKycPrivateData($conn, $employeeId);
$kycBank = $canSensitive ? getKycBankDetails($conn, $employeeId) : null;
$benefitStatus = $canSensitive ? getEmployeeBenefitStatus($conn, $employeeId) : null;
$kycStatus = $kycProfile ? $kycProfile["kyc_status"] : KYC_STATUS_NOT_STARTED;
$documentCount = $kycProfile ? count(getKycDocuments($conn, $employeeId)) : 0;
$kycHistory = $kycProfile ? getKycHistory($conn, (int)($kycProfile["kyc_id"] ?? 0)) : [];

$activeAmendment = $kycProfile ? getKycActiveAmendment($conn, (int)$kycProfile["kyc_id"]) : null;
if (!$activeAmendment && $kycProfile) {
    $latestAmendment = getKycLatestAmendment($conn, (int)$kycProfile["kyc_id"]);
    if ($latestAmendment && $latestAmendment["amendment_status"] === AMENDMENT_STATUS_REJECTED) {
        $activeAmendment = $latestAmendment;
    }
}
$amendmentPrivate = $activeAmendment ? getKycAmendmentPrivateData($conn, (int)$activeAmendment["amendment_id"]) : null;
$amendmentBank = ($activeAmendment && $canSensitive) ? getKycBankAmendmentDetails($conn, (int)$activeAmendment["amendment_id"]) : null;
$amendmentStatus = $activeAmendment ? $activeAmendment["amendment_status"] : null;

if (isset($_SESSION["revealed_field"]) && isset($_SESSION["revealed_value"])) {
    $revealedField = $_SESSION["revealed_field"];
    $revealedValue = $_SESSION["revealed_value"];
    unset($_SESSION["revealed_field"], $_SESSION["revealed_value"]);
}
$revealedBankAccount = $_SESSION["revealed_bank_account"] ?? null;
unset($_SESSION["revealed_bank_account"]);

$pageTitle = "Employee KYC Profile";
$pageSubtitle = "Manage internal identity verification workflow, amendments, and structured KYC data.";
$basePath = "../";

define('APP_INCLUDED', true);
require_once "../includes/header.php";

function statusBadgeClass($status) {
    switch ($status) {
        case 'VERIFIED':
        case 'APPROVED': return 'badge-ho';
        case 'SUBMITTED':
        case 'UNDER_REVIEW': return 'badge-branch';
        case 'REJECTED': return 'badge-admin';
        case 'DRAFT':
        case 'REQUESTED': return 'badge-ho';
        default: return '';
    }
}

$isVerified = ($kycStatus === KYC_STATUS_VERIFIED);
$canEditStatutory = ($userRole === 'Admin' || $isKycOfficer) && !$isVerified;
$canEditBasic = !$isVerified;

$canEditAmendmentBasic = $activeAmendment && in_array($amendmentStatus, ['DRAFT', 'REQUESTED'], true);
$canEditAmendmentStatutory = $activeAmendment && in_array($amendmentStatus, ['DRAFT', 'REQUESTED'], true) && ($userRole === 'Admin' || $isKycOfficer);
$canEditAmendmentBank = $canEditAmendmentStatutory;

$statusDisplay = $kycStatus === 'VERIFIED' ? 'Internally Verified' : str_replace('_', ' ', $kycStatus);
?>

<div class="kyc-page">

    <!-- Breadcrumb Navigation -->
    <div class="kyc-breadcrumb">
        <a href="../admin/employees.php">Employees</a>
        <span class="kyc-breadcrumb-separator">›</span>
        <span>Employee KYC</span>
        <span class="kyc-breadcrumb-separator">›</span>
        <strong><?php echo htmlspecialchars($employee["employee_name"]); ?></strong>
    </div>

    <!-- Compact Employee Header -->
    <div class="kyc-header">
        <div class="kyc-header-title">
            <?php echo htmlspecialchars($employee["employee_name"]); ?>
            <span class="kyc-status-badge <?php echo statusBadgeClass($kycStatus); ?>">
                <?php echo htmlspecialchars($statusDisplay); ?>
            </span>
        </div>

        <div class="kyc-summary-grid">
            <div class="kyc-summary-item">
                <span class="kyc-summary-label">Employee No</span>
                <span class="kyc-summary-value"><?php echo htmlspecialchars($employee["employee_no"]); ?></span>
            </div>
            <div class="kyc-summary-item">
                <span class="kyc-summary-label">Branch</span>
                <span class="kyc-summary-value"><?php echo htmlspecialchars(getBranchName($conn, $employee["branch_id"])); ?></span>
            </div>
            <div class="kyc-summary-item">
                <span class="kyc-summary-label">Designation</span>
                <span class="kyc-summary-value"><?php echo htmlspecialchars($employee["designation"] ?? "N/A"); ?></span>
            </div>
            <div class="kyc-summary-item">
                <span class="kyc-summary-label">Category</span>
                <span class="kyc-summary-value"><?php echo htmlspecialchars($employee["employee_category"]); ?></span>
            </div>
        </div>

        <?php if ($kycStatus === 'REJECTED' && !empty($kycProfile["rejection_reason"])) { ?>
            <div class="flash-message flash-error" style="margin-top:12px;">
                <strong>Rejection Reason:</strong> <?php echo htmlspecialchars($kycProfile["rejection_reason"]); ?>
            </div>
        <?php } ?>
    </div>

    <!-- Workflow Action Toolbar -->
    <div class="kyc-toolbar">
        <div class="kyc-toolbar-primary">
            <?php if ($kycStatus === KYC_STATUS_NOT_STARTED && canUserTransitionKyc($userRole, KYC_STATUS_NOT_STARTED, KYC_STATUS_DRAFT)) { ?>
                <form method="post" action="employee_kyc.php" style="display:inline;">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="start">
                    <button type="submit" class="btn-generate">Start KYC Profile</button>
                </form>
            <?php } elseif ($kycStatus === KYC_STATUS_DRAFT && canUserTransitionKyc($userRole, KYC_STATUS_DRAFT, KYC_STATUS_SUBMITTED)) { ?>
                <form method="post" action="employee_kyc.php" style="display:inline;">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="submit">
                    <button type="submit" class="btn-generate">Submit for Verification Review</button>
                </form>
            <?php } elseif ($kycStatus === KYC_STATUS_SUBMITTED && (canUserTransitionKyc($userRole, KYC_STATUS_SUBMITTED, KYC_STATUS_UNDER_REVIEW) || $isKycOfficer)) { ?>
                <form method="post" action="employee_kyc.php" style="display:inline;">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="start_review">
                    <button type="submit" class="btn-generate">Start Verification Review</button>
                </form>
            <?php } elseif ($kycStatus === KYC_STATUS_UNDER_REVIEW && canUserTransitionKyc($userRole, KYC_STATUS_UNDER_REVIEW, KYC_STATUS_VERIFIED)) { ?>
                <form method="post" action="employee_kyc.php" style="display:inline;">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="verify">
                    <button type="submit" class="btn-generate" style="background:#0f766e;">Approve & Mark Internally Verified</button>
                </form>
            <?php } elseif ($kycStatus === KYC_STATUS_REJECTED && canUserTransitionKyc($userRole, KYC_STATUS_REJECTED, KYC_STATUS_DRAFT)) { ?>
                <form method="post" action="employee_kyc.php" style="display:inline;">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="reopen">
                    <button type="submit" class="btn-generate">Re-open Profile for Draft Corrections</button>
                </form>
            <?php } elseif ($userRole === 'Branch User' && ($kycStatus === KYC_STATUS_SUBMITTED || $kycStatus === KYC_STATUS_UNDER_REVIEW)) { ?>
                <span style="color:#64748b; font-size:13px; font-weight:600;">Profile under review by Head Office</span>
            <?php } ?>
        </div>

        <!-- Back to Employee Master Navigation (top right of toolbar) -->
        <a href="../admin/employees.php" class="btn-secondary-link" style="margin-left:auto;">← Back</a>
    </div>

    <?php if ($isVerified) { ?>
        <div style="background:#f0fdf4; border:1px solid #bbf7d0; padding:12px 14px; border-radius:8px; margin-bottom:16px; display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap;">
            <div>
                <p style="color:#0f766e; font-weight:600; margin:0 0 2px 0;">✓ Internally Verified</p>
                <p style="color:#475569; font-size:12px; margin:0;">Live verified profile is locked against direct edits.</p>
            </div>
            <?php if (!$activeAmendment) { ?>
                <form method="post" action="employee_kyc.php" style="display:inline;">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="request_amendment">
                    <button type="button" class="btn-generate" onclick="document.getElementById('requestAmendmentModal').style.display='block'; return false;" style="margin-top:8px;">Request Amendment</button>
                </form>
            <?php } ?>
        </div>

        <!-- Amendment Modal/Form (minimal, compact) -->
        <?php if (!$activeAmendment) { ?>
            <div id="requestAmendmentModal" style="display:none; background:#fef3c7; border:1px solid #fde68a; border-radius:8px; padding:16px; margin-bottom:16px;">
                <h4 style="color:#b45309; margin:0 0 8px 0;">Request Profile Amendment</h4>
                <form method="post" action="employee_kyc.php">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="request_amendment">
                    <textarea name="request_reason" placeholder="Explain why an amendment is needed (e.g., Address changed, PAN correction)" required style="width:100%; height:60px; margin-bottom:10px; padding:10px; border:1px solid #fde68a; border-radius:6px; font-family:Arial; font-size:14px;"></textarea>
                    <div style="display:flex; gap:10px;">
                        <button type="submit" class="btn-generate">Request Amendment</button>
                        <button type="button" onclick="document.getElementById('requestAmendmentModal').style.display='none';" class="btn-cancel" style="background:#64748b; color:#ffffff;">Cancel</button>
                    </div>
                </form>
            </div>
        <?php } elseif ($activeAmendment) { ?>
            <div class="kyc-amendment-box">
                <h4>Amendment Active: <?php echo htmlspecialchars($amendmentStatus); ?></h4>
                <p>Reason: <?php echo htmlspecialchars($activeAmendment['request_reason']); ?></p>

                <!-- Amendment Actions -->
                <?php if ($amendmentStatus === 'DRAFT' || $amendmentStatus === 'REQUESTED') { ?>
                    <div style="display:flex; gap:10px; flex-wrap:wrap; margin-top:10px;">
                        <form method="post" action="employee_kyc.php" style="display:inline;">
                            <?php echo csrfField(); ?>
                            <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                            <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                            <input type="hidden" name="action" value="submit_amendment">
                            <button type="submit" class="btn-generate">Submit Amendment for Review</button>
                        </form>
                        <form method="post" action="employee_kyc.php" style="display:inline;">
                            <?php echo csrfField(); ?>
                            <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                            <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                            <input type="hidden" name="action" value="cancel_amendment">
                            <button type="submit" class="btn-cancel" style="background:#64748b; color:#ffffff;">Cancel Amendment</button>
                        </form>
                    </div>
                <?php } elseif ($amendmentStatus === 'SUBMITTED' && ($userRole === 'Admin' || $userRole === 'HO User' || $isKycOfficer)) { ?>
                    <form method="post" action="employee_kyc.php" style="display:inline; margin-top:10px;">
                        <?php echo csrfField(); ?>
                        <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                        <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                        <input type="hidden" name="action" value="start_review_amendment">
                        <button type="submit" class="btn-generate">Start Amendment Review</button>
                    </form>
                <?php } elseif ($amendmentStatus === 'UNDER_REVIEW') { ?>
                    <?php if ($userRole === 'Admin') { ?>
                        <div style="display:flex; gap:10px; flex-wrap:wrap; margin-top:10px;">
                            <form method="post" action="employee_kyc.php" style="display:inline;">
                                <?php echo csrfField(); ?>
                                <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                                <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                                <input type="hidden" name="action" value="approve_amendment">
                                <button type="submit" class="btn-generate" style="background:#0f766e;">Approve & Apply Amendment</button>
                            </form>
                            <button type="button" onclick="document.getElementById('rejectAmendmentModal').style.display='block';" class="btn-cancel" style="background:#b91c1c; color:#ffffff;">Reject Amendment</button>
                        </div>
                        <div id="rejectAmendmentModal" style="display:none; background:#fef2f2; border:1px solid #fca5a5; border-radius:8px; padding:12px; margin-top:10px;">
                            <form method="post" action="employee_kyc.php">
                                <?php echo csrfField(); ?>
                                <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                                <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                                <input type="hidden" name="action" value="reject_amendment">
                                <input type="text" name="rejection_reason" placeholder="Rejection reason (Required)" required style="width:100%; padding:8px; margin-bottom:8px; border:1px solid #fca5a5; border-radius:4px;">
                                <div style="display:flex; gap:8px;">
                                    <button type="submit" class="btn-cancel" style="background:#b91c1c; color:#ffffff; flex:1;">Reject</button>
                                    <button type="button" onclick="document.getElementById('rejectAmendmentModal').style.display='none';" class="btn-cancel" style="background:#64748b; color:#ffffff; flex:1;">Cancel</button>
                                </div>
                            </form>
                        </div>
                    <?php } else { ?>
                        <p style="color:#64748b; font-size:12px;">Amendment is currently under review by Admin.</p>
                    <?php } ?>
                <?php } elseif ($amendmentStatus === 'REJECTED') { ?>
                    <p style="color:#b91c1c; font-size:12px; margin:8px 0;"><strong>Rejection Reason:</strong> <?php echo htmlspecialchars($activeAmendment['rejection_reason']); ?></p>
                    <form method="post" action="employee_kyc.php" style="display:inline;">
                        <?php echo csrfField(); ?>
                        <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                        <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                        <input type="hidden" name="action" value="revise_amendment">
                        <button type="submit" class="btn-generate">Re-open Amendment Draft</button>
                    </form>
                <?php } ?>
            </div>

            <!-- Amendment Field Changes Summary -->
            <div style="background:#fffbe1; border:1px solid #fde68a; border-radius:8px; padding:14px; margin-bottom:16px;">
                <div style="font-weight:700; color:#92400e; margin-bottom:8px;">Proposed Amendment Changes</div>
                <table class="kyc-responsive-table" style="font-size:12px;">
                    <tr>
                        <th>Field</th>
                        <th>Status</th>
                    </tr>
                    <tr>
                        <td>Date of Birth</td>
                        <td><?php echo ($kycPrivate['date_of_birth'] ?? '') !== ($amendmentPrivate['date_of_birth'] ?? '') ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px;">Unchanged</span>'; ?></td>
                    </tr>
                    <tr>
                        <td>Mobile Number</td>
                        <td><?php echo ($kycPrivate['mobile_number'] ?? '') !== ($amendmentPrivate['mobile_number'] ?? '') ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px;">Unchanged</span>'; ?></td>
                    </tr>
                    <tr>
                        <td>Current Address</td>
                        <td><?php echo ($kycPrivate['current_address'] ?? '') !== ($amendmentPrivate['current_address'] ?? '') ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px;">Unchanged</span>'; ?></td>
                    </tr>
                    <tr>
                        <td>Permanent Address</td>
                        <td><?php echo ($kycPrivate['permanent_address'] ?? '') !== ($amendmentPrivate['permanent_address'] ?? '') ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px;">Unchanged</span>'; ?></td>
                    </tr>
                    <tr>
                        <td>PAN</td>
                        <td><?php echo (($kycPrivate['pan_applicable'] ?? 0) !== ($amendmentPrivate['pan_applicable'] ?? 0) || ($kycPrivate['pan_hmac'] ?? '') !== ($amendmentPrivate['pan_hmac'] ?? '')) ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px;">Unchanged</span>'; ?></td>
                    </tr>
                    <tr>
                        <td>Aadhaar</td>
                        <td><?php echo (($kycPrivate['aadhaar_applicable'] ?? 0) !== ($amendmentPrivate['aadhaar_applicable'] ?? 0) || ($kycPrivate['aadhaar_hmac'] ?? '') !== ($amendmentPrivate['aadhaar_hmac'] ?? '')) ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px;">Unchanged</span>'; ?></td>
                    </tr>
                    <tr>
                        <td>UAN</td>
                        <td><?php echo (($kycPrivate['uan_applicable'] ?? 0) !== ($amendmentPrivate['uan_applicable'] ?? 0) || ($kycPrivate['uan_hmac'] ?? '') !== ($amendmentPrivate['uan_hmac'] ?? '')) ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px;">Unchanged</span>'; ?></td>
                    </tr>
                    <tr>
                        <td>ESIC</td>
                        <td><?php echo (($kycPrivate['esic_applicable'] ?? 0) !== ($amendmentPrivate['esic_applicable'] ?? 0) || ($kycPrivate['esic_number_enc'] ?? '') !== ($amendmentPrivate['esic_number_enc'] ?? '')) ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px;">Unchanged</span>'; ?></td>
                    </tr>
                </table>
            </div>
        <?php } ?>
    <?php } ?>

    <!-- Section Navigation Tabs -->
    <div class="kyc-tabs" role="tablist" aria-label="Employee KYC sections">
        <button id="tab-overview" type="button" role="tab" aria-selected="true" aria-controls="overview-panel" data-tab="overview" class="active">Overview</button>
        <button id="tab-personal" type="button" role="tab" aria-selected="false" aria-controls="personal-panel" data-tab="personal">Personal</button>
        <button id="tab-statutory" type="button" role="tab" aria-selected="false" aria-controls="statutory-panel" data-tab="statutory">Statutory IDs</button>
        <button id="tab-bank" type="button" role="tab" aria-selected="false" aria-controls="bank-panel" data-tab="bank">Bank Details</button>
        <button id="tab-documents" type="button" role="tab" aria-selected="false" aria-controls="documents-panel" data-tab="documents">Documents</button>
        <button id="tab-benefits" type="button" role="tab" aria-selected="false" aria-controls="benefits-panel" data-tab="benefits">Benefits</button>
        <button id="tab-history" type="button" role="tab" aria-selected="false" aria-controls="history-panel" data-tab="history">History</button>
    </div>

    <!-- TAB: OVERVIEW -->
    <div id="overview-panel" class="kyc-panel active" role="tabpanel" aria-labelledby="tab-overview" tabindex="0">
        <div style="background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:16px;">
            <h3 style="margin:0 0 12px 0; font-size:16px;">Profile Status Overview</h3>
            <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(180px, 1fr)); gap:12px;">
                <div class="kyc-stat-card">
                    <div class="kyc-stat-label">KYC Status</div>
                    <div class="kyc-stat-value" style="font-size:18px;"><?php echo htmlspecialchars($statusDisplay); ?></div>
                </div>
                <div class="kyc-stat-card">
                    <div class="kyc-stat-label">Documents</div>
                    <div class="kyc-stat-value"><?php echo (int)$documentCount; ?></div>
                </div>
                <div class="kyc-stat-card">
                    <div class="kyc-stat-label">Medical Coverage</div>
                    <div class="kyc-stat-value" style="font-size:14px;"><?php echo htmlspecialchars(groupMedicalCoverageLabel($benefitStatus['group_medical_covered'] ?? null)); ?></div>
                </div>
            </div>

            <h3 style="margin:20px 0 12px 0; font-size:14px; border-top:1px solid #e2e8f0; padding-top:12px;">Workflow Guidance</h3>
            <ul style="font-size:13px; color:#475569; margin:0; padding-left:20px;">
                <li>Complete Personal Details in the Personal tab</li>
                <li>Add Statutory Identifiers (PAN, Aadhaar, UAN, ESIC) in the Statutory IDs tab</li>
                <li>Optionally add Bank Details in the Bank Details tab</li>
                <li>Upload KYC Documents in the Documents tab</li>
                <li>Once all sections are complete, submit your profile for verification review</li>
                <li>Verified profiles can request amendments for corrections</li>
            </ul>
        </div>
    </div>

    <!-- TAB: PERSONAL DETAILS -->
    <div id="personal-panel" class="kyc-panel" role="tabpanel" aria-labelledby="tab-personal" tabindex="0">
        <?php if ($activeAmendment) { ?>
            <div style="background:#fffbe1; border:1px solid #fde68a; border-radius:8px; padding:14px; margin-bottom:16px;">
                <p style="color:#92400e; font-weight:700; margin:0 0 4px 0;">Editing Amendment Draft — Personal Details</p>
                <p style="color:#78350f; font-size:12px; margin:0;">Changes will be compared against the live verified profile.</p>
            </div>
            <form method="post" action="employee_kyc.php">
                <?php echo csrfField(); ?>
                <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                <input type="hidden" name="action" value="save_amendment_basic">

                <div class="kyc-form-grid">
                    <div class="kyc-form-group">
                        <label for="dob_amend">Date of Birth</label>
                        <input type="date" id="dob_amend" name="date_of_birth" value="<?php echo htmlspecialchars($amendmentPrivate["date_of_birth"] ?? ""); ?>" <?php echo !$canEditAmendmentBasic ? 'disabled' : ''; ?>>
                    </div>

                    <div class="kyc-form-group">
                        <label for="mobile_amend">Mobile Number</label>
                        <input type="text" id="mobile_amend" name="mobile_number" placeholder="10 digits" value="<?php echo htmlspecialchars($amendmentPrivate["mobile_number"] ?? ""); ?>" <?php echo !$canEditAmendmentBasic ? 'disabled' : ''; ?>>
                    </div>

                    <div class="kyc-form-group kyc-form-span-2">
                        <label for="curr_addr_amend">Current Address</label>
                        <input type="text" id="curr_addr_amend" name="current_address" placeholder="Street, City, State, Pincode" value="<?php echo htmlspecialchars($amendmentPrivate["current_address"] ?? ""); ?>" <?php echo !$canEditAmendmentBasic ? 'disabled' : ''; ?>>
                    </div>

                    <div class="kyc-form-group kyc-form-span-2">
                        <label style="font-weight:normal; cursor:pointer; display:flex; align-items:center; gap:6px;">
                            <input type="checkbox" name="same_as_current" value="1" <?php echo (!empty($amendmentPrivate["same_as_current"]) && (int)$amendmentPrivate["same_as_current"] === 1) ? 'checked' : ''; ?> <?php echo !$canEditAmendmentBasic ? 'disabled' : ''; ?> onchange="togglePermanentAddress(this)">
                            Permanent Address same as Current Address
                        </label>
                    </div>

                    <div class="kyc-form-group kyc-form-span-2" id="permanent_address_wrap">
                        <label for="perm_addr_amend">Permanent Address</label>
                        <input type="text" id="perm_addr_amend" name="permanent_address" placeholder="Street, City, State, Pincode" value="<?php echo htmlspecialchars($amendmentPrivate["permanent_address"] ?? ""); ?>" <?php echo !$canEditAmendmentBasic ? 'disabled' : ''; ?>>
                    </div>
                </div>

                <?php if ($canEditAmendmentBasic) { ?>
                    <div class="kyc-actions">
                        <button type="submit" class="btn-generate">Save Personal Details</button>
                    </div>
                <?php } ?>
            </form>
        <?php } else { ?>
            <form method="post" action="employee_kyc.php">
                <?php echo csrfField(); ?>
                <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                <input type="hidden" name="action" value="save_basic">

                <div class="kyc-form-grid">
                    <div class="kyc-form-group">
                        <label for="dob">Date of Birth</label>
                        <input type="date" id="dob" name="date_of_birth" value="<?php echo htmlspecialchars($kycPrivate["date_of_birth"] ?? ""); ?>" <?php echo !$canEditBasic ? 'disabled' : ''; ?>>
                    </div>

                    <div class="kyc-form-group">
                        <label for="mobile">Mobile Number</label>
                        <input type="text" id="mobile" name="mobile_number" placeholder="10 digits" value="<?php echo htmlspecialchars($kycPrivate["mobile_number"] ?? ""); ?>" <?php echo !$canEditBasic ? 'disabled' : ''; ?>>
                    </div>

                    <div class="kyc-form-group kyc-form-span-2">
                        <label for="curr_addr">Current Address</label>
                        <input type="text" id="curr_addr" name="current_address" placeholder="Street, City, State, Pincode" value="<?php echo htmlspecialchars($kycPrivate["current_address"] ?? ""); ?>" <?php echo !$canEditBasic ? 'disabled' : ''; ?>>
                    </div>

                    <div class="kyc-form-group kyc-form-span-2">
                        <label style="font-weight:normal; cursor:pointer; display:flex; align-items:center; gap:6px;">
                            <input type="checkbox" name="same_as_current" value="1" <?php echo (!empty($kycPrivate["same_as_current"]) && (int)$kycPrivate["same_as_current"] === 1) ? 'checked' : ''; ?> <?php echo !$canEditBasic ? 'disabled' : ''; ?> onchange="togglePermanentAddress(this)">
                            Permanent Address same as Current Address
                        </label>
                    </div>

                    <div class="kyc-form-group kyc-form-span-2" id="permanent_address_wrap">
                        <label for="perm_addr">Permanent Address</label>
                        <input type="text" id="perm_addr" name="permanent_address" placeholder="Street, City, State, Pincode" value="<?php echo htmlspecialchars($kycPrivate["permanent_address"] ?? ""); ?>" <?php echo !$canEditBasic ? 'disabled' : ''; ?>>
                    </div>
                </div>

                <?php if ($canEditBasic) { ?>
                    <div class="kyc-actions">
                        <button type="submit" class="btn-generate">Save Personal Details</button>
                    </div>
                <?php } ?>
            </form>
        <?php } ?>
    </div>

    <!-- TAB: STATUTORY IDENTIFIERS -->
    <div id="statutory-panel" class="kyc-panel" role="tabpanel" aria-labelledby="tab-statutory" tabindex="0">
        <?php if (!$canSensitive) { ?>
            <div style="background:#f1f5f9; border:1px solid #cbd5e1; border-radius:8px; padding:14px;">
                <p style="color:#64748b; font-weight:600; margin:0;">Restricted Access</p>
                <p style="color:#64748b; font-size:13px; margin:8px 0 0 0;">Statutory identifiers are managed by Head Office / Admin.</p>
            </div>
        <?php } else { ?>
            <?php if ($activeAmendment) { ?>
                <div style="background:#fffbe1; border:1px solid #fde68a; border-radius:8px; padding:14px; margin-bottom:16px;">
                    <p style="color:#92400e; font-weight:700; margin:0 0 4px 0;">Editing Amendment Draft — Statutory Identifiers</p>
                </div>
                <form method="post" action="employee_kyc.php">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                    <input type="hidden" name="action" value="save_amendment_statutory">

                    <div style="display:grid; grid-template-columns:1fr; gap:20px;">
                        <?php foreach (['pan' => 'PAN', 'aadhaar' => 'Aadhaar', 'uan' => 'UAN', 'esic' => 'ESIC'] as $fKey => $fLabel) { ?>
                            <div style="background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:14px;">
                                <h4 style="margin:0 0 12px 0; font-size:14px;"><?php echo $fLabel; ?></h4>
                                <div style="display:grid; grid-template-columns:auto 1fr; gap:12px 16px; margin-bottom:12px;">
                                    <label style="font-weight:600; font-size:13px;">Applicable:</label>
                                    <label style="display:flex; align-items:center; gap:6px; font-weight:normal;">
                                        <input type="checkbox" name="<?php echo $fKey; ?>_applicable" value="1" <?php echo (!empty($amendmentPrivate["{$fKey}_applicable"]) && (int)$amendmentPrivate["{$fKey}_applicable"] === 1) ? 'checked' : ''; ?> <?php echo !$canEditAmendmentStatutory ? 'disabled' : ''; ?>>
                                        Yes
                                    </label>
                                    <label style="font-weight:600; font-size:13px;">Current:</label>
                                    <code style="background:#ffffff; padding:6px 10px; border-radius:4px; border:1px solid #cbd5e1; font-size:12px;">
                                        <?php
                                        $fieldKey = $fKey . "_number_enc";
                                        if ($fKey === 'esic') $fieldKey = "esic_number_enc";
                                        echo !empty($amendmentPrivate[$fieldKey]) ? htmlspecialchars(maskIdentifier(decryptKycField($amendmentPrivate[$fieldKey]))) : 'Not Set';
                                        ?>
                                    </code>
                                    <label style="font-weight:600; font-size:13px;">New Value:</label>
                                    <input type="text" name="<?php echo $fKey; ?>_number" placeholder="Enter new <?php echo $fLabel; ?>" style="padding:8px 12px; border:1px solid #cbd5e1; border-radius:6px;" <?php echo !$canEditAmendmentStatutory ? 'disabled' : ''; ?>>
                                </div>
                            </div>
                        <?php } ?>
                    </div>

                    <?php if ($canEditAmendmentStatutory) { ?>
                        <div class="kyc-actions">
                            <button type="submit" class="btn-generate">Save Statutory Details</button>
                        </div>
                    <?php } ?>
                </form>
            <?php } else { ?>
                <form method="post" action="employee_kyc.php">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="save_statutory">

                    <div style="display:grid; grid-template-columns:1fr; gap:20px; margin-bottom:20px;">
                        <?php foreach (['pan' => 'PAN', 'aadhaar' => 'Aadhaar', 'uan' => 'UAN', 'esic' => 'ESIC'] as $fKey => $fLabel) { ?>
                            <div style="background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:14px;">
                                <h4 style="margin:0 0 12px 0; font-size:14px;"><?php echo $fLabel; ?></h4>
                                <div style="display:grid; grid-template-columns:auto 1fr; gap:12px 16px; margin-bottom:12px;">
                                    <label style="font-weight:600; font-size:13px;">Applicable:</label>
                                    <label style="display:flex; align-items:center; gap:6px; font-weight:normal;">
                                        <input type="checkbox" name="<?php echo $fKey; ?>_applicable" value="1" <?php echo (!empty($kycPrivate["{$fKey}_applicable"]) && (int)$kycPrivate["{$fKey}_applicable"] === 1) ? 'checked' : ''; ?> <?php echo !$canEditStatutory ? 'disabled' : ''; ?>>
                                        Yes
                                    </label>
                                    <label style="font-weight:600; font-size:13px;">Current:</label>
                                    <code style="background:#ffffff; padding:6px 10px; border-radius:4px; border:1px solid #cbd5e1; font-size:12px;">
                                        <?php
                                        $fieldKey = $fKey . "_number_enc";
                                        if ($fKey === 'esic') $fieldKey = "esic_number_enc";
                                        echo !empty($kycPrivate[$fieldKey]) ? htmlspecialchars(maskIdentifier(decryptKycField($kycPrivate[$fieldKey]))) : 'Not Set';
                                        ?>
                                    </code>
                                    <label style="font-weight:600; font-size:13px;">New Value:</label>
                                    <input type="text" name="<?php echo $fKey; ?>_number" placeholder="Enter new <?php echo $fLabel; ?>" style="padding:8px 12px; border:1px solid #cbd5e1; border-radius:6px;" <?php echo !$canEditStatutory ? 'disabled' : ''; ?>>
                                </div>
                            </div>
                        <?php } ?>
                    </div>

                    <?php if ($canEditStatutory) { ?>
                        <div class="kyc-actions" style="margin-bottom:20px;">
                            <button type="submit" class="btn-generate">Save Statutory Details</button>
                        </div>
                    <?php } ?>
                </form>

                <!-- Audit-logged Reveal Controls -->
                <?php if ($canSensitive) { ?>
                    <div style="background:#f1f5f9; border:1px solid #cbd5e1; border-radius:8px; padding:14px;">
                        <p style="font-weight:600; margin:0 0 8px 0; font-size:13px;">🔐 Audit-Logged Sensitive Field Reveal</p>
                        <p style="font-size:12px; color:#64748b; margin:0 0 12px 0;">
                            Full statutory values are shown only when explicitly requested. All reveals are recorded in the security audit log.
                        </p>
                        <div style="display:flex; gap:8px; flex-wrap:wrap;">
                            <?php foreach (['pan' => 'PAN', 'aadhaar' => 'Aadhaar', 'uan' => 'UAN', 'esic' => 'ESIC'] as $fKey => $fLabel) { ?>
                                <form method="post" action="employee_kyc.php" style="display:inline;">
                                    <?php echo csrfField(); ?>
                                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                                    <input type="hidden" name="action" value="reveal">
                                    <input type="hidden" name="field_name" value="<?php echo $fKey; ?>">
                                    <button type="submit" class="btn-secondary-link" style="font-size:12px; padding:6px 12px;">Reveal <?php echo $fLabel; ?></button>
                                </form>
                            <?php } ?>
                        </div>

                        <?php if ($revealedField && $revealedValue !== null) { ?>
                            <div class="flash-message flash-success" style="margin-top:12px;">
                                <strong>Revealed <?php echo strtoupper($revealedField); ?>:</strong>
                                <code style="font-size:15px; font-weight:700; background:#ffffff; padding:2px 8px; border-radius:4px;"><?php echo htmlspecialchars($revealedValue !== '' ? $revealedValue : 'Not Set'); ?></code>
                            </div>
                        <?php } ?>
                    </div>
                <?php } ?>
            <?php } ?>
        <?php } ?>
    </div>

    <!-- TAB: BANK DETAILS -->
    <div id="bank-panel" class="kyc-panel" role="tabpanel" aria-labelledby="tab-bank" tabindex="0">
        <?php if (!$canSensitive) { ?>
            <div style="background:#f1f5f9; border:1px solid #cbd5e1; border-radius:8px; padding:14px;">
                <p style="color:#64748b; font-weight:600; margin:0;">Restricted Access</p>
                <p style="color:#64748b; font-size:13px; margin:8px 0 0 0;">Bank details are managed by an authorized KYC Officer.</p>
            </div>
        <?php } else { ?>
            <?php if ($activeAmendment && ($amendmentStatus === 'DRAFT' || $amendmentStatus === 'REQUESTED')) { ?>
                <div style="background:#fffbe1; border:1px solid #fde68a; border-radius:8px; padding:14px; margin-bottom:16px;">
                    <p style="color:#92400e; font-weight:700; margin:0;">Editing Amendment Draft — Bank Details</p>
                </div>
                <form method="post" action="employee_kyc.php">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                    <input type="hidden" name="action" value="save_amendment_bank">

                    <div class="kyc-form-grid">
                        <div class="kyc-form-group">
                            <label for="amend_acct">Account Number</label>
                            <input type="text" id="amend_acct" name="account_number" inputmode="numeric" autocomplete="off" placeholder="6 to 24 digits">
                        </div>
                        <div class="kyc-form-group">
                            <label for="amend_confirm_acct">Confirm Account Number</label>
                            <input type="text" id="amend_confirm_acct" name="confirm_account_number" inputmode="numeric" autocomplete="off">
                        </div>
                        <div class="kyc-form-group">
                            <label for="amend_ifsc">IFSC Code</label>
                            <input type="text" id="amend_ifsc" name="ifsc_code" maxlength="11" style="text-transform:uppercase;" value="<?php echo htmlspecialchars($amendmentBank['ifsc_code'] ?? ''); ?>">
                        </div>
                        <div class="kyc-form-group">
                            <label for="amend_type">Account Type</label>
                            <select id="amend_type" name="account_type">
                                <option value="">Select type</option>
                                <?php foreach (KYC_BANK_ACCOUNT_TYPES as $type) { ?>
                                    <option value="<?php echo $type; ?>" <?php echo (($amendmentBank['account_type'] ?? '') === $type) ? 'selected' : ''; ?>><?php echo htmlspecialchars(ucfirst(strtolower($type))); ?></option>
                                <?php } ?>
                            </select>
                        </div>
                        <div class="kyc-form-group kyc-form-span-2">
                            <label for="amend_branch">Bank Branch Name</label>
                            <input type="text" id="amend_branch" name="branch_name" maxlength="150" value="<?php echo htmlspecialchars($amendmentBank['branch_name'] ?? ''); ?>">
                        </div>
                    </div>

                    <div class="kyc-actions">
                        <button type="submit" class="btn-generate">Save Bank Details</button>
                    </div>
                </form>
            <?php } elseif (!$isVerified) { ?>
                <form method="post" action="employee_kyc.php">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="save_bank">

                    <div class="kyc-form-grid">
                        <div class="kyc-form-group">
                            <label for="acct">Account Number</label>
                            <input type="text" id="acct" name="account_number" inputmode="numeric" autocomplete="off" placeholder="6 to 24 digits">
                        </div>
                        <div class="kyc-form-group">
                            <label for="confirm_acct">Confirm Account Number</label>
                            <input type="text" id="confirm_acct" name="confirm_account_number" inputmode="numeric" autocomplete="off">
                        </div>
                        <div class="kyc-form-group">
                            <label for="ifsc">IFSC Code</label>
                            <input type="text" id="ifsc" name="ifsc_code" maxlength="11" style="text-transform:uppercase;" value="<?php echo htmlspecialchars($kycBank['ifsc_code'] ?? ''); ?>">
                        </div>
                        <div class="kyc-form-group">
                            <label for="type">Account Type</label>
                            <select id="type" name="account_type">
                                <option value="">Select type</option>
                                <?php foreach (KYC_BANK_ACCOUNT_TYPES as $type) { ?>
                                    <option value="<?php echo $type; ?>" <?php echo (($kycBank['account_type'] ?? '') === $type) ? 'selected' : ''; ?>><?php echo htmlspecialchars(ucfirst(strtolower($type))); ?></option>
                                <?php } ?>
                            </select>
                        </div>
                        <div class="kyc-form-group kyc-form-span-2">
                            <label for="branch">Bank Branch Name</label>
                            <input type="text" id="branch" name="branch_name" maxlength="150" value="<?php echo htmlspecialchars($kycBank['branch_name'] ?? ''); ?>">
                        </div>
                    </div>

                    <p style="font-size:12px; color:#64748b; margin:12px 0 0 0;">Bank details are optional. If started, all four fields must be completed.</p>
                    <div class="kyc-actions">
                        <button type="submit" class="btn-generate">Save Bank Details</button>
                    </div>
                </form>
            <?php } else { ?>
                <div style="background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:14px;">
                    <p style="margin:0 0 8px 0;"><strong>Account Number:</strong> <code><?php echo !empty($kycBank['account_number_enc']) ? htmlspecialchars(maskBankAccountNumber(decryptKycField($kycBank['account_number_enc']))) : 'Not Set'; ?></code></p>
                    <p style="margin:0 0 8px 0;"><strong>IFSC Code:</strong> <?php echo htmlspecialchars($kycBank['ifsc_code'] ?? 'Not Set'); ?></p>
                    <p style="margin:0 0 8px 0;"><strong>Account Type:</strong> <?php echo htmlspecialchars($kycBank['account_type'] ?? 'Not Set'); ?></p>
                    <p style="margin:0;"><strong>Branch Name:</strong> <?php echo htmlspecialchars($kycBank['branch_name'] ?? 'Not Set'); ?></p>

                    <?php if (!empty($kycBank['account_number_enc'])) { ?>
                        <form method="post" action="employee_kyc.php" style="display:inline; margin-top:12px;">
                            <?php echo csrfField(); ?>
                            <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                            <input type="hidden" name="action" value="reveal_bank_account">
                            <button type="submit" class="btn-secondary-link" style="font-size:12px; padding:6px 12px;">Reveal Full Account Number</button>
                        </form>
                    <?php } ?>

                    <?php if ($revealedBankAccount !== null) { ?>
                        <div class="flash-message flash-success" style="margin-top:12px;">
                            <strong>Revealed Account:</strong> <code><?php echo htmlspecialchars($revealedBankAccount !== '' ? $revealedBankAccount : 'Not Set'); ?></code>
                        </div>
                    <?php } ?>
                </div>
            <?php } ?>
        <?php } ?>
    </div>

    <!-- TAB: DOCUMENTS -->
    <div id="documents-panel" class="kyc-panel" role="tabpanel" aria-labelledby="tab-documents" tabindex="0">
        <div style="background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:16px;">
            <p style="margin:0 0 12px 0;"><strong>KYC Documents Count:</strong> <?php echo (int)$documentCount; ?></p>
            <?php if ($canSensitive) { ?>
                <a href="documents.php?employee_id=<?php echo $employeeId; ?>" class="btn-generate" style="display:inline-block; margin-bottom:12px;">Manage KYC Documents</a>
            <?php } else { ?>
                <p style="font-size:13px; color:#64748b;">Documents are managed by an authorized KYC Officer.</p>
            <?php } ?>
        </div>
    </div>

    <!-- TAB: BENEFITS -->
    <div id="benefits-panel" class="kyc-panel" role="tabpanel" aria-labelledby="tab-benefits" tabindex="0">
        <?php if (!$canSensitive) { ?>
            <div style="background:#f1f5f9; border:1px solid #cbd5e1; border-radius:8px; padding:14px;">
                <p style="color:#64748b; font-weight:600; margin:0;">Restricted Access</p>
                <p style="color:#64748b; font-size:13px; margin:8px 0 0 0;">Employee benefit information is restricted.</p>
            </div>
        <?php } else { ?>
            <div style="background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:16px;">
                <div style="display:grid; grid-template-columns:1fr 1fr; gap:16px; align-items:end; margin-bottom:16px;">
                    <div>
                        <p style="margin:0 0 8px 0; font-weight:600; font-size:13px;">Group Medical Insurance</p>
                        <div style="font-size:18px; font-weight:700; color:#0f172a;">
                            <?php echo htmlspecialchars(groupMedicalCoverageLabel($benefitStatus['group_medical_covered'] ?? null)); ?>
                        </div>
                    </div>

                    <form method="post" action="employee_kyc.php">
                        <?php echo csrfField(); ?>
                        <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                        <input type="hidden" name="action" value="save_benefit_status">
                        <select name="group_medical_covered" style="padding:8px 12px; border:1px solid #cbd5e1; border-radius:6px;">
                            <option value="NOT_SET" <?php echo (($benefitStatus['group_medical_covered'] ?? null) === null) ? 'selected' : ''; ?>>Not Set</option>
                            <option value="COVERED" <?php echo isset($benefitStatus['group_medical_covered']) && (int)$benefitStatus['group_medical_covered'] === 1 ? 'selected' : ''; ?>>Covered</option>
                            <option value="NOT_COVERED" <?php echo isset($benefitStatus['group_medical_covered']) && (int)$benefitStatus['group_medical_covered'] === 0 ? 'selected' : ''; ?>>Not Covered</option>
                        </select>
                        <button type="submit" class="btn-generate">Update</button>
                    </form>
                </div>

                <a href="../reports/group_medical_insurance.php" class="btn-secondary-link">View Medical Insurance Report</a>
            </div>
        <?php } ?>
    </div>

    <!-- TAB: HISTORY -->
    <div id="history-panel" class="kyc-panel" role="tabpanel" aria-labelledby="tab-history" tabindex="0">
        <div style="overflow-x:auto;">
            <table class="kyc-responsive-table" style="width:100%;">
                <thead>
                    <tr>
                        <th>Timestamp</th>
                        <th>Actor</th>
                        <th>Action</th>
                        <th>Transition</th>
                        <th>Remarks</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (!empty($kycHistory)) { ?>
                        <?php foreach ($kycHistory as $h) { ?>
                            <tr>
                                <td style="font-size:12px; color:#64748b;"><?php echo htmlspecialchars($h["created_at"]); ?></td>
                                <td><?php echo htmlspecialchars($h["actor_name"] ?? "System"); ?></td>
                                <td><code style="font-size:11px;"><?php echo htmlspecialchars($h["action"]); ?></code></td>
                                <td style="font-size:11px;">
                                    <?php echo htmlspecialchars($h["previous_status"]); ?> →
                                    <strong><?php echo htmlspecialchars($h["new_status"]); ?></strong>
                                </td>
                                <td style="font-size:12px;"><?php echo htmlspecialchars($h["remarks"] ?? ""); ?></td>
                            </tr>
                        <?php } ?>
                    <?php } else { ?>
                        <tr>
                            <td colspan="5" style="color:#64748b; text-align:center; padding:20px; font-size:13px;">No workflow history recorded yet.</td>
                        </tr>
                    <?php } ?>
                </tbody>
            </table>
        </div>
    </div>

</div>

<script>
function togglePermanentAddress(checkbox) {
    const wrap = checkbox.closest('.kyc-form-group')?.nextElementSibling;
    const input = wrap ? wrap.querySelector('input[name="permanent_address"]') : null;

    if (checkbox.checked) {
        if (wrap) wrap.style.display = 'none';
        if (input) input.value = '';
    } else {
        if (wrap) wrap.style.display = 'block';
    }
}

document.addEventListener('DOMContentLoaded', function() {
    document.documentElement.classList.add('kyc-js');

    const tabs = Array.from(document.querySelectorAll('.kyc-tabs button'));
    const panels = Array.from(document.querySelectorAll('.kyc-panel'));

    function activateTab(tabElement) {
        const tabName = tabElement.getAttribute('data-tab');
        const targetPanel = document.getElementById(tabName + '-panel');

        tabs.forEach(tab => {
            const isActive = tab === tabElement;
            tab.classList.toggle('active', isActive);
            tab.setAttribute('aria-selected', isActive ? 'true' : 'false');
            tab.tabIndex = isActive ? 0 : -1;
        });

        panels.forEach(panel => {
            const isActive = panel.id === targetPanel?.id;
            panel.classList.toggle('active', isActive);
            panel.hidden = !isActive;
        });
    }

    tabs.forEach((tab, index) => {
        tab.tabIndex = tab.classList.contains('active') ? 0 : -1;
        tab.addEventListener('click', function() {
            activateTab(this);
        });

        tab.addEventListener('keydown', function(event) {
            if (!['ArrowRight', 'ArrowLeft', 'Home', 'End'].includes(event.key)) {
                return;
            }

            event.preventDefault();
            let nextIndex = index;

            if (event.key === 'ArrowRight') {
                nextIndex = (index + 1) % tabs.length;
            } else if (event.key === 'ArrowLeft') {
                nextIndex = (index - 1 + tabs.length) % tabs.length;
            } else if (event.key === 'Home') {
                nextIndex = 0;
            } else if (event.key === 'End') {
                nextIndex = tabs.length - 1;
            }

            tabs[nextIndex].focus();
            activateTab(tabs[nextIndex]);
        });
    });

    const sameAsCurrent = document.querySelector('input[name="same_as_current"]');
    if (sameAsCurrent && sameAsCurrent.checked) {
        togglePermanentAddress(sameAsCurrent);
    }

    panels.forEach(panel => {
        panel.hidden = !panel.classList.contains('active');
    });
});
</script>

<?php require_once "../includes/footer.php"; ?>

    <!-- Left Column: Employee & KYC Status Summary -->
    <div class="panel-card">
        <div class="panel-title">Employee Details</div>

        <table style="width:100%; margin-bottom:16px;">
            <tr>
                <th style="width:140px; text-align:left;">Employee No:</th>
                <td><strong><?php echo htmlspecialchars($employee["employee_no"]); ?></strong></td>
            </tr>
            <tr>
                <th style="text-align:left;">Employee Name:</th>
                <td><?php echo htmlspecialchars($employee["employee_name"]); ?></td>
            </tr>
            <tr>
                <th style="text-align:left;">Branch:</th>
                <td><?php echo htmlspecialchars(getBranchName($conn, $employee["branch_id"])); ?></td>
            </tr>
            <tr>
                <th style="text-align:left;">Designation:</th>
                <td><?php echo htmlspecialchars($employee["designation"] ?? "N/A"); ?></td>
            </tr>
            <tr>
                <th style="text-align:left;">Category:</th>
                <td><?php echo htmlspecialchars($employee["employee_category"]); ?></td>
            </tr>
            <tr>
                <th style="text-align:left;">KYC Status:</th>
                <td>
                    <span class="role-badge <?php echo statusBadgeClass($kycStatus); ?>">
                        <?php
                        if ($kycStatus === 'VERIFIED') {
                            echo "Internally Verified";
                        } else {
                            echo htmlspecialchars(str_replace('_', ' ', $kycStatus));
                        }
                        ?>
                    </span>
                </td>
            </tr>
        </table>

        <?php if ($kycStatus === 'REJECTED' && !empty($kycProfile["rejection_reason"])) { ?>
            <div class="flash-message flash-error" style="margin-top:10px;">
                <strong>Rejection Reason:</strong> <?php echo htmlspecialchars($kycProfile["rejection_reason"]); ?>
            </div>
        <?php } ?>

        <div class="panel-title" style="margin-top:20px;">KYC Workflow Actions</div>

        <!-- Workflow Action Buttons -->
        <div style="margin-top:12px;">
            <?php if ($kycStatus === KYC_STATUS_NOT_STARTED && canUserTransitionKyc($userRole, KYC_STATUS_NOT_STARTED, KYC_STATUS_DRAFT)) { ?>
                <form method="post" action="employee_kyc.php" style="margin-bottom:10px;">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="start">
                    <button type="submit" class="btn-generate">Start KYC Profile</button>
                </form>
            <?php } ?>

            <?php if ($kycStatus === KYC_STATUS_DRAFT && canUserTransitionKyc($userRole, KYC_STATUS_DRAFT, KYC_STATUS_SUBMITTED)) { ?>
                <form method="post" action="employee_kyc.php" style="margin-bottom:10px;">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="submit">
                    <button type="submit" class="btn-generate">Submit for Verification Review</button>
                </form>
            <?php } ?>

            <?php if ($kycStatus === KYC_STATUS_SUBMITTED && (canUserTransitionKyc($userRole, KYC_STATUS_SUBMITTED, KYC_STATUS_UNDER_REVIEW) || $isKycOfficer)) { ?>
                <form method="post" action="employee_kyc.php" style="margin-bottom:10px;">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="start_review">
                    <button type="submit" class="btn-generate">Start Verification Review</button>
                </form>
            <?php } ?>

            <?php if ($kycStatus === KYC_STATUS_UNDER_REVIEW && canUserTransitionKyc($userRole, KYC_STATUS_UNDER_REVIEW, KYC_STATUS_VERIFIED)) { ?>
                <form method="post" action="employee_kyc.php" style="margin-bottom:16px;">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="verify">
                    <button type="submit" class="btn-generate" style="background:#0f766e;">Approve & Mark Internally Verified</button>
                </form>

                <div style="border-top:1px solid #e2e8f0; pt-3; margin-top:12px; padding-top:12px;">
                    <form method="post" action="employee_kyc.php">
                        <?php echo csrfField(); ?>
                        <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                        <input type="hidden" name="action" value="reject">
                        <label for="rejection_reason" style="font-weight:600;">Rejection Reason (Required):</label>
                        <input type="text" id="rejection_reason" name="rejection_reason" placeholder="Explain why profile is rejected" required style="width:100%; margin-bottom:10px; margin-top:4px;">
                        <button type="submit" class="btn-cancel" style="background:#b91c1c; color:#ffffff;">Reject Profile</button>
                    </form>
                </div>
            <?php } ?>

            <?php if ($kycStatus === KYC_STATUS_REJECTED && canUserTransitionKyc($userRole, KYC_STATUS_REJECTED, KYC_STATUS_DRAFT)) { ?>
                <form method="post" action="employee_kyc.php" style="margin-bottom:10px;">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="reopen">
                    <button type="submit" class="btn-generate">Re-open Profile for Draft Corrections</button>
                </form>
            <?php } ?>

            <?php if ($isVerified) { ?>
                <div style="background:#f0fdf4; border:1px solid #bbf7d0; padding:12px; border-radius:8px; margin-bottom:12px;">
                    <p style="color:#0f766e; font-weight:600; margin:0 0 4px 0;">✓ Internally Verified</p>
                    <p style="color:#475569; font-size:12px; margin:0;">Live verified profile is locked against direct edits.</p>
                </div>

                <?php if (!$activeAmendment) { ?>
                    <div style="border-top:1px solid #e2e8f0; padding-top:12px; margin-top:12px;">
                        <form method="post" action="employee_kyc.php">
                            <?php echo csrfField(); ?>
                            <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                            <input type="hidden" name="action" value="request_amendment">
                            <label for="request_reason" style="font-weight:600; font-size:13px;">Request Profile Amendment:</label>
                            <textarea id="request_reason" name="request_reason" placeholder="Explain why an amendment is requested (e.g. Address changed, PAN correction)" required style="width:100%; height:60px; margin-top:4px; margin-bottom:8px; font-size:13px;"></textarea>
                            <button type="submit" class="btn-generate" style="width:100%;">Request KYC Amendment</button>
                        </form>
                    </div>
                <?php } else { ?>
                    <div style="background:#fef3c7; border:1px solid #fde68a; padding:12px; border-radius:8px; margin-top:12px; margin-bottom:12px;">
                        <p style="color:#b45309; font-weight:700; margin:0 0 4px 0;">Amendment Active: <?php echo htmlspecialchars($amendmentStatus); ?></p>
                        <p style="color:#78350f; font-size:12px; margin:0 0 8px 0;">Reason: <?php echo htmlspecialchars($activeAmendment['request_reason']); ?></p>

                        <!-- Amendment Actions -->
                        <?php if ($amendmentStatus === 'DRAFT' || $amendmentStatus === 'REQUESTED') { ?>
                            <form method="post" action="employee_kyc.php" style="margin-bottom:8px;">
                                <?php echo csrfField(); ?>
                                <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                                <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                                <input type="hidden" name="action" value="submit_amendment">
                                <button type="submit" class="btn-generate" style="width:100%;">Submit Amendment for Review</button>
                            </form>

                            <form method="post" action="employee_kyc.php">
                                <?php echo csrfField(); ?>
                                <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                                <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                                <input type="hidden" name="action" value="cancel_amendment">
                                <button type="submit" class="btn-cancel" style="width:100%; background:#64748b; color:#ffffff;">Cancel Amendment</button>
                            </form>
                        <?php } ?>

                        <?php if ($amendmentStatus === 'SUBMITTED' && ($userRole === 'Admin' || $userRole === 'HO User' || $isKycOfficer)) { ?>
                            <form method="post" action="employee_kyc.php" style="margin-bottom:8px;">
                                <?php echo csrfField(); ?>
                                <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                                <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                                <input type="hidden" name="action" value="start_review_amendment">
                                <button type="submit" class="btn-generate" style="width:100%;">Start Amendment Review</button>
                            </form>
                        <?php } ?>

                        <?php if ($amendmentStatus === 'UNDER_REVIEW') { ?>
                            <?php if ($userRole === 'Admin') { ?>
                                <form method="post" action="employee_kyc.php" style="margin-bottom:12px;">
                                    <?php echo csrfField(); ?>
                                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                                    <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                                    <input type="hidden" name="action" value="approve_amendment">
                                    <button type="submit" class="btn-generate" style="width:100%; background:#0f766e;">Approve & Apply Amendment</button>
                                </form>

                                <form method="post" action="employee_kyc.php" style="margin-bottom:8px;">
                                    <?php echo csrfField(); ?>
                                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                                    <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                                    <input type="hidden" name="action" value="reject_amendment">
                                    <input type="text" name="rejection_reason" placeholder="Rejection reason (Required)" required style="width:100%; margin-bottom:6px; font-size:12px;">
                                    <button type="submit" class="btn-cancel" style="width:100%; background:#b91c1c; color:#ffffff;">Reject Amendment</button>
                                </form>
                            <?php } else { ?>
                                <p style="color:#64748b; font-size:12px;">Amendment is currently under review by Admin.</p>
                            <?php } ?>
                        <?php } ?>

                        <?php if ($amendmentStatus === 'REJECTED') { ?>
                            <p style="color:#b91c1c; font-size:12px; margin-bottom:8px;"><strong>Rejection Reason:</strong> <?php echo htmlspecialchars($activeAmendment['rejection_reason']); ?></p>
                            <form method="post" action="employee_kyc.php">
                                <?php echo csrfField(); ?>
                                <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                                <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                                <input type="hidden" name="action" value="revise_amendment">
                                <button type="submit" class="btn-generate" style="width:100%;">Re-open Amendment Draft</button>
                            </form>
                        <?php } ?>
                    </div>
                <?php } ?>
            <?php } ?>

            <?php if ($userRole === 'Branch User' && ($kycStatus === KYC_STATUS_SUBMITTED || $kycStatus === KYC_STATUS_UNDER_REVIEW)) { ?>
                <p style="color:#64748b; font-size:13px;">This profile is currently under review by Head Office / Admin.</p>
            <?php } ?>
        </div>

        <div class="form-actions" style="margin-top:20px;">
            <a href="../admin/employees.php" class="btn-secondary-link">Back to Employee Master</a>
        </div>
    </div>

    <!-- Right Column: Data Entry & Verification Sections -->
    <div>

        <?php if ($activeAmendment) { ?>
            <!-- Difference Summary Panel for Active Amendment -->
            <div class="panel-card" style="margin-bottom:16px; background:#fffbe1; border:1px solid #fde68a;">
                <div class="panel-title" style="color:#92400e;">Proposed Amendment Field Changes</div>
                <p style="font-size:12px; color:#78350f; margin-bottom:12px;">
                    Comparing current live verified profile vs proposed amendment draft.
                </p>

                <table style="width:100%; border-collapse:collapse; font-size:13px;">
                    <thead>
                        <tr style="border-bottom:1px solid #fcd34d; text-align:left;">
                            <th style="padding:6px 0;">Field</th>
                            <th style="padding:6px 0;">Change Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td style="padding:4px 0; font-weight:600;">Date of Birth</td>
                            <td><?php echo ($kycPrivate['date_of_birth'] ?? '') !== ($amendmentPrivate['date_of_birth'] ?? '') ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-size:11px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px; font-size:11px;">Unchanged</span>'; ?></td>
                        </tr>
                        <tr>
                            <td style="padding:4px 0; font-weight:600;">Mobile Number</td>
                            <td><?php echo ($kycPrivate['mobile_number'] ?? '') !== ($amendmentPrivate['mobile_number'] ?? '') ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-size:11px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px; font-size:11px;">Unchanged</span>'; ?></td>
                        </tr>
                        <tr>
                            <td style="padding:4px 0; font-weight:600;">Current Address</td>
                            <td><?php echo ($kycPrivate['current_address'] ?? '') !== ($amendmentPrivate['current_address'] ?? '') ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-size:11px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px; font-size:11px;">Unchanged</span>'; ?></td>
                        </tr>
                        <tr>
                            <td style="padding:4px 0; font-weight:600;">Permanent Address</td>
                            <td><?php echo ($kycPrivate['permanent_address'] ?? '') !== ($amendmentPrivate['permanent_address'] ?? '') ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-size:11px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px; font-size:11px;">Unchanged</span>'; ?></td>
                        </tr>
                        <tr>
                            <td style="padding:4px 0; font-weight:600;">PAN Identifier / Applicability</td>
                            <td><?php echo (($kycPrivate['pan_applicable'] ?? 0) !== ($amendmentPrivate['pan_applicable'] ?? 0) || ($kycPrivate['pan_hmac'] ?? '') !== ($amendmentPrivate['pan_hmac'] ?? '')) ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-size:11px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px; font-size:11px;">Unchanged</span>'; ?></td>
                        </tr>
                        <tr>
                            <td style="padding:4px 0; font-weight:600;">Aadhaar Identifier / Applicability</td>
                            <td><?php echo (($kycPrivate['aadhaar_applicable'] ?? 0) !== ($amendmentPrivate['aadhaar_applicable'] ?? 0) || ($kycPrivate['aadhaar_hmac'] ?? '') !== ($amendmentPrivate['aadhaar_hmac'] ?? '')) ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-size:11px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px; font-size:11px;">Unchanged</span>'; ?></td>
                        </tr>
                        <tr>
                            <td style="padding:4px 0; font-weight:600;">UAN Identifier / Applicability</td>
                            <td><?php echo (($kycPrivate['uan_applicable'] ?? 0) !== ($amendmentPrivate['uan_applicable'] ?? 0) || ($kycPrivate['uan_hmac'] ?? '') !== ($amendmentPrivate['uan_hmac'] ?? '')) ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-size:11px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px; font-size:11px;">Unchanged</span>'; ?></td>
                        </tr>
                        <tr>
                            <td style="padding:4px 0; font-weight:600;">ESIC Identifier / Applicability</td>
                            <td><?php echo (($kycPrivate['esic_applicable'] ?? 0) !== ($amendmentPrivate['esic_applicable'] ?? 0) || ($kycPrivate['esic_number_enc'] ?? '') !== ($amendmentPrivate['esic_number_enc'] ?? '')) ? '<span style="background:#fef3c7; color:#b45309; padding:2px 6px; border-radius:4px; font-size:11px; font-weight:700;">Changed</span>' : '<span style="background:#f1f5f9; color:#64748b; padding:2px 6px; border-radius:4px; font-size:11px;">Unchanged</span>'; ?></td>
                        </tr>
                    </tbody>
                </table>
            </div>

            <!-- Amendment Data Entry: Basic Personal Details -->
            <div class="panel-card" style="margin-bottom:16px;">
                <div class="panel-title">1. Proposed Amendment Basic Personal Details</div>

                <form method="post" action="employee_kyc.php">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                    <input type="hidden" name="action" value="save_amendment_basic">

                    <div class="form-grid">
                        <div>
                            <label for="date_of_birth">Date of Birth</label>
                            <input type="date" id="date_of_birth" name="date_of_birth"
                                   value="<?php echo htmlspecialchars($amendmentPrivate["date_of_birth"] ?? ""); ?>"
                                   <?php echo !$canEditAmendmentBasic ? 'disabled' : ''; ?>>
                        </div>

                        <div>
                            <label for="mobile_number">Mobile Number (10 digits)</label>
                            <input type="text" id="mobile_number" name="mobile_number" placeholder="e.g. 9876543210"
                                   value="<?php echo htmlspecialchars($amendmentPrivate["mobile_number"] ?? ""); ?>"
                                   <?php echo !$canEditAmendmentBasic ? 'disabled' : ''; ?>>
                        </div>

                        <div style="grid-column: 1 / -1;">
                            <label for="current_address">Current Address</label>
                            <input type="text" id="current_address" name="current_address" placeholder="Street, City, State, Pincode"
                                   value="<?php echo htmlspecialchars($amendmentPrivate["current_address"] ?? ""); ?>"
                                   <?php echo !$canEditAmendmentBasic ? 'disabled' : ''; ?>>
                        </div>

                        <div style="grid-column: 1 / -1;">
                            <label style="font-weight:normal; cursor:pointer;">
                                <input type="checkbox" id="same_as_current" name="same_as_current" value="1"
                                       <?php echo (!empty($amendmentPrivate["same_as_current"]) && (int)$amendmentPrivate["same_as_current"] === 1) ? 'checked' : ''; ?>
                                       <?php echo !$canEditAmendmentBasic ? 'disabled' : ''; ?>
                                       onchange="togglePermanentAddress(this)">
                                Permanent Address same as Current Address
                            </label>
                        </div>

                        <div style="grid-column: 1 / -1;" id="permanent_address_wrap">
                            <label for="permanent_address">Permanent Address</label>
                            <input type="text" id="permanent_address" name="permanent_address" placeholder="Street, City, State, Pincode"
                                   value="<?php echo htmlspecialchars($amendmentPrivate["permanent_address"] ?? ""); ?>"
                                   <?php echo !$canEditAmendmentBasic ? 'disabled' : ''; ?>>
                        </div>
                    </div>

                    <?php if ($canEditAmendmentBasic) { ?>
                        <div class="form-actions" style="margin-top:16px;">
                            <button type="submit" class="btn-generate">Save Amendment Basic Details</button>
                        </div>
                    <?php } ?>
                </form>
            </div>

            <!-- Amendment Data Entry: Statutory Details -->
            <div class="panel-card" style="margin-bottom:16px;">
                <div class="panel-title">2. Proposed Amendment Statutory Identifiers & Applicability</div>

                <?php if (!$canSensitive) { ?>
                    <p style="color:#64748b; font-size:13px; margin-bottom:12px;">
                        Statutory applicability and identifiers are managed by Head Office / Admin.
                    </p>
                <?php } else { ?>
                    <form method="post" action="employee_kyc.php">
                        <?php echo csrfField(); ?>
                        <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                        <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                        <input type="hidden" name="action" value="save_amendment_statutory">

                        <table style="width:100%; border-collapse:collapse; margin-bottom:16px;">
                            <thead>
                                <tr style="border-bottom:2px solid #e2e8f0; text-align:left;">
                                    <th style="padding:8px 0; width:140px;">Identifier</th>
                                    <th style="padding:8px 0; width:120px;">Applicable?</th>
                                    <th style="padding:8px 0; width:150px;">Masked Value</th>
                                    <th style="padding:8px 0;">New / Replacement Value</th>
                                </tr>
                            </thead>
                            <tbody>
                                <!-- PAN -->
                                <tr style="border-bottom:1px solid #f1f5f9;">
                                    <td style="padding:10px 0; font-weight:600;">PAN Number</td>
                                    <td>
                                        <label><input type="checkbox" name="pan_applicable" value="1" <?php echo (!empty($amendmentPrivate["pan_applicable"]) && (int)$amendmentPrivate["pan_applicable"] === 1) ? 'checked' : ''; ?> <?php echo !$canEditAmendmentStatutory ? 'disabled' : ''; ?>> Yes</label>
                                    </td>
                                    <td>
                                        <code><?php echo !empty($amendmentPrivate["pan_number_enc"]) ? htmlspecialchars(maskIdentifier(decryptKycField($amendmentPrivate["pan_number_enc"]))) : 'Not Set'; ?></code>
                                    </td>
                                    <td>
                                        <input type="text" name="pan_number" placeholder="Enter new PAN" style="width:180px; text-transform:uppercase;" <?php echo !$canEditAmendmentStatutory ? 'disabled' : ''; ?>>
                                    </td>
                                </tr>

                                <!-- Aadhaar -->
                                <tr style="border-bottom:1px solid #f1f5f9;">
                                    <td style="padding:10px 0; font-weight:600;">Aadhaar Number</td>
                                    <td>
                                        <label><input type="checkbox" name="aadhaar_applicable" value="1" <?php echo (!empty($amendmentPrivate["aadhaar_applicable"]) && (int)$amendmentPrivate["aadhaar_applicable"] === 1) ? 'checked' : ''; ?> <?php echo !$canEditAmendmentStatutory ? 'disabled' : ''; ?>> Yes</label>
                                    </td>
                                    <td>
                                        <code><?php echo !empty($amendmentPrivate["aadhaar_number_enc"]) ? htmlspecialchars(maskIdentifier(decryptKycField($amendmentPrivate["aadhaar_number_enc"]))) : 'Not Set'; ?></code>
                                    </td>
                                    <td>
                                        <input type="text" name="aadhaar_number" placeholder="Enter 12-digit Aadhaar" style="width:180px;" <?php echo !$canEditAmendmentStatutory ? 'disabled' : ''; ?>>
                                    </td>
                                </tr>

                                <!-- UAN -->
                                <tr style="border-bottom:1px solid #f1f5f9;">
                                    <td style="padding:10px 0; font-weight:600;">UAN (EPF)</td>
                                    <td>
                                        <label><input type="checkbox" name="uan_applicable" value="1" <?php echo (!empty($amendmentPrivate["uan_applicable"]) && (int)$amendmentPrivate["uan_applicable"] === 1) ? 'checked' : ''; ?> <?php echo !$canEditAmendmentStatutory ? 'disabled' : ''; ?>> Yes</label>
                                    </td>
                                    <td>
                                        <code><?php echo !empty($amendmentPrivate["uan_number_enc"]) ? htmlspecialchars(maskIdentifier(decryptKycField($amendmentPrivate["uan_number_enc"]))) : 'Not Set'; ?></code>
                                    </td>
                                    <td>
                                        <input type="text" name="uan_number" placeholder="Enter 12-digit UAN" style="width:180px;" <?php echo !$canEditAmendmentStatutory ? 'disabled' : ''; ?>>
                                    </td>
                                </tr>

                                <!-- ESIC -->
                                <tr style="border-bottom:1px solid #f1f5f9;">
                                    <td style="padding:10px 0; font-weight:600;">ESIC IP Number</td>
                                    <td>
                                        <label><input type="checkbox" name="esic_applicable" value="1" <?php echo (!empty($amendmentPrivate["esic_applicable"]) && (int)$amendmentPrivate["esic_applicable"] === 1) ? 'checked' : ''; ?> <?php echo !$canEditAmendmentStatutory ? 'disabled' : ''; ?>> Yes</label>
                                    </td>
                                    <td>
                                        <code><?php echo !empty($amendmentPrivate["esic_number_enc"]) ? htmlspecialchars(maskIdentifier(decryptKycField($amendmentPrivate["esic_number_enc"]))) : 'Not Set'; ?></code>
                                    </td>
                                    <td>
                                        <input type="text" name="esic_number" placeholder="Enter 17-digit ESIC" style="width:180px;" <?php echo !$canEditAmendmentStatutory ? 'disabled' : ''; ?>>
                                    </td>
                                </tr>
                            </tbody>
                        </table>

                        <?php if ($canEditAmendmentStatutory) { ?>
                            <div class="form-actions">
                                <button type="submit" class="btn-generate">Save Amendment Statutory Details</button>
                            </div>
                        <?php } ?>
                    </form>
                <?php } ?>
            </div>

            <div class="panel-card" style="margin-bottom:16px;">
                <div class="panel-title">3. Bank Details — Amendment</div>
                <?php if (!$canSensitive) { ?>
                    <p style="color:#64748b; font-size:13px;">Bank details are managed by an authorized KYC Officer.</p>
                <?php } elseif ($canEditAmendmentBank) { ?>
                    <form method="post" action="employee_kyc.php">
                        <?php echo csrfField(); ?>
                        <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                        <input type="hidden" name="amendment_id" value="<?php echo (int)$activeAmendment['amendment_id']; ?>">
                        <input type="hidden" name="action" value="save_amendment_bank">
                        <div class="form-grid">
                            <div><label for="amendment_account_number">New / Replacement Account Number</label><input type="text" id="amendment_account_number" name="account_number" inputmode="numeric" autocomplete="off"></div>
                            <div><label for="amendment_confirm_account_number">Confirm Account Number</label><input type="text" id="amendment_confirm_account_number" name="confirm_account_number" inputmode="numeric" autocomplete="off"></div>
                            <div><label for="amendment_ifsc_code">IFSC Code</label><input type="text" id="amendment_ifsc_code" name="ifsc_code" maxlength="11" style="text-transform:uppercase;" value="<?php echo htmlspecialchars($amendmentBank['ifsc_code'] ?? ''); ?>"></div>
                            <div><label for="amendment_account_type">Account Type</label><select id="amendment_account_type" name="account_type"><option value="">Select type</option><?php foreach (KYC_BANK_ACCOUNT_TYPES as $type) { ?><option value="<?php echo $type; ?>" <?php echo (($amendmentBank['account_type'] ?? '') === $type) ? 'selected' : ''; ?>><?php echo htmlspecialchars(ucfirst(strtolower($type))); ?></option><?php } ?></select></div>
                            <div style="grid-column:1 / -1;"><label for="amendment_branch_name">Bank Branch Name</label><input type="text" id="amendment_branch_name" name="branch_name" maxlength="150" value="<?php echo htmlspecialchars($amendmentBank['branch_name'] ?? ''); ?>"></div>
                        </div>
                        <div class="form-actions" style="margin-top:16px;"><button type="submit" class="btn-generate">Save Amendment Bank Details</button></div>
                    </form>
                <?php } else { ?>
                    <p>Account Number: <code><?php echo !empty($amendmentBank['account_number_enc']) ? htmlspecialchars(maskBankAccountNumber(decryptKycField($amendmentBank['account_number_enc']))) : 'Not Set'; ?></code></p>
                    <p>IFSC Code: <?php echo htmlspecialchars($amendmentBank['ifsc_code'] ?? 'Not Set'); ?></p>
                    <p>Account Type: <?php echo htmlspecialchars($amendmentBank['account_type'] ?? 'Not Set'); ?></p>
                    <p>Branch Name: <?php echo htmlspecialchars($amendmentBank['branch_name'] ?? 'Not Set'); ?></p>
                <?php } ?>
            </div>

        <?php } else { ?>

            <!-- Section 1: Basic Personal Data (Initial KYC) -->
            <div class="panel-card" style="margin-bottom:16px;">
                <div class="panel-title">1. Basic Personal Details</div>

                <form method="post" action="employee_kyc.php">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="save_basic">

                    <div class="form-grid">
                        <div>
                            <label for="date_of_birth">Date of Birth</label>
                            <input type="date" id="date_of_birth" name="date_of_birth"
                                   value="<?php echo htmlspecialchars($kycPrivate["date_of_birth"] ?? ""); ?>"
                                   <?php echo !$canEditBasic ? 'disabled' : ''; ?>>
                        </div>

                        <div>
                            <label for="mobile_number">Mobile Number (10 digits)</label>
                            <input type="text" id="mobile_number" name="mobile_number" placeholder="e.g. 9876543210"
                                   value="<?php echo htmlspecialchars($kycPrivate["mobile_number"] ?? ""); ?>"
                                   <?php echo !$canEditBasic ? 'disabled' : ''; ?>>
                        </div>

                        <div style="grid-column: 1 / -1;">
                            <label for="current_address">Current Address</label>
                            <input type="text" id="current_address" name="current_address" placeholder="Street, City, State, Pincode"
                                   value="<?php echo htmlspecialchars($kycPrivate["current_address"] ?? ""); ?>"
                                   <?php echo !$canEditBasic ? 'disabled' : ''; ?>>
                        </div>

                        <div style="grid-column: 1 / -1;">
                            <label style="font-weight:normal; cursor:pointer;">
                                <input type="checkbox" id="same_as_current" name="same_as_current" value="1"
                                       <?php echo (!empty($kycPrivate["same_as_current"]) && (int)$kycPrivate["same_as_current"] === 1) ? 'checked' : ''; ?>
                                       <?php echo !$canEditBasic ? 'disabled' : ''; ?>
                                       onchange="togglePermanentAddress(this)">
                                Permanent Address same as Current Address
                            </label>
                        </div>

                        <div style="grid-column: 1 / -1;" id="permanent_address_wrap">
                            <label for="permanent_address">Permanent Address</label>
                            <input type="text" id="permanent_address" name="permanent_address" placeholder="Street, City, State, Pincode"
                                   value="<?php echo htmlspecialchars($kycPrivate["permanent_address"] ?? ""); ?>"
                                   <?php echo !$canEditBasic ? 'disabled' : ''; ?>>
                        </div>
                    </div>

                    <?php if ($canEditBasic) { ?>
                        <div class="form-actions" style="margin-top:16px;">
                            <button type="submit" class="btn-generate">Save Basic Details</button>
                        </div>
                    <?php } ?>
                </form>
            </div>

            <!-- Section 2: Statutory Identifiers & Applicability (Initial KYC) -->
            <div class="panel-card" style="margin-bottom:16px;">
                <div class="panel-title">2. Statutory Identifiers & Applicability</div>

                <?php if (!$canSensitive) { ?>
                    <p style="color:#64748b; font-size:13px; margin-bottom:12px;">
                        Statutory applicability and identifiers are managed by Head Office / Admin.
                    </p>

                    <table style="width:100%; border-collapse:collapse;">
                        <tr>
                            <th style="text-align:left; padding:6px 0;">PAN Status:</th>
                            <td><?php echo (!empty($kycPrivate["pan_applicable"]) && (int)$kycPrivate["pan_applicable"] === 1) ? '<span style="color:#0f766e;font-weight:600;">Applicable</span> (' . htmlspecialchars(maskIdentifier(decryptKycField($kycPrivate["pan_number_enc"] ?? ''))) . ')' : '<span style="color:#9ca3af;">Not Applicable</span>'; ?></td>
                        </tr>
                        <tr>
                            <th style="text-align:left; padding:6px 0;">Aadhaar Status:</th>
                            <td><?php echo (!empty($kycPrivate["aadhaar_applicable"]) && (int)$kycPrivate["aadhaar_applicable"] === 1) ? '<span style="color:#0f766e;font-weight:600;">Applicable</span> (' . htmlspecialchars(maskIdentifier(decryptKycField($kycPrivate["aadhaar_number_enc"] ?? ''))) . ')' : '<span style="color:#9ca3af;">Not Applicable</span>'; ?></td>
                        </tr>
                        <tr>
                            <th style="text-align:left; padding:6px 0;">UAN Status:</th>
                            <td><?php echo (!empty($kycPrivate["uan_applicable"]) && (int)$kycPrivate["uan_applicable"] === 1) ? '<span style="color:#0f766e;font-weight:600;">Applicable</span> (' . htmlspecialchars(maskIdentifier(decryptKycField($kycPrivate["uan_number_enc"] ?? ''))) . ')' : '<span style="color:#9ca3af;">Not Applicable</span>'; ?></td>
                        </tr>
                        <tr>
                            <th style="text-align:left; padding:6px 0;">ESIC Status:</th>
                            <td><?php echo (!empty($kycPrivate["esic_applicable"]) && (int)$kycPrivate["esic_applicable"] === 1) ? '<span style="color:#0f766e;font-weight:600;">Applicable</span> (' . htmlspecialchars(maskIdentifier(decryptKycField($kycPrivate["esic_number_enc"] ?? ''))) . ')' : '<span style="color:#9ca3af;">Not Applicable</span>'; ?></td>
                        </tr>
                    </table>

                <?php } else { ?>

                    <form method="post" action="employee_kyc.php">
                        <?php echo csrfField(); ?>
                        <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                        <input type="hidden" name="action" value="save_statutory">

                        <table style="width:100%; border-collapse:collapse; margin-bottom:16px;">
                            <thead>
                                <tr style="border-bottom:2px solid #e2e8f0; text-align:left;">
                                    <th style="padding:8px 0; width:140px;">Identifier</th>
                                    <th style="padding:8px 0; width:120px;">Applicable?</th>
                                    <th style="padding:8px 0; width:150px;">Masked Value</th>
                                    <th style="padding:8px 0;">New / Replacement Value</th>
                                </tr>
                            </thead>
                            <tbody>
                                <!-- PAN -->
                                <tr style="border-bottom:1px solid #f1f5f9;">
                                    <td style="padding:10px 0; font-weight:600;">PAN Number</td>
                                    <td>
                                        <label><input type="checkbox" name="pan_applicable" value="1" <?php echo (!empty($kycPrivate["pan_applicable"]) && (int)$kycPrivate["pan_applicable"] === 1) ? 'checked' : ''; ?> <?php echo !$canEditStatutory ? 'disabled' : ''; ?>> Yes</label>
                                    </td>
                                    <td>
                                        <code><?php echo !empty($kycPrivate["pan_number_enc"]) ? htmlspecialchars(maskIdentifier(decryptKycField($kycPrivate["pan_number_enc"]))) : 'Not Set'; ?></code>
                                    </td>
                                    <td>
                                        <input type="text" name="pan_number" placeholder="Enter new PAN (10 chars)" style="width:180px; text-transform:uppercase;" <?php echo !$canEditStatutory ? 'disabled' : ''; ?>>
                                    </td>
                                </tr>

                                <!-- Aadhaar -->
                                <tr style="border-bottom:1px solid #f1f5f9;">
                                    <td style="padding:10px 0; font-weight:600;">Aadhaar Number</td>
                                    <td>
                                        <label><input type="checkbox" name="aadhaar_applicable" value="1" <?php echo (!empty($kycPrivate["aadhaar_applicable"]) && (int)$kycPrivate["aadhaar_applicable"] === 1) ? 'checked' : ''; ?> <?php echo !$canEditStatutory ? 'disabled' : ''; ?>> Yes</label>
                                    </td>
                                    <td>
                                        <code><?php echo !empty($kycPrivate["aadhaar_number_enc"]) ? htmlspecialchars(maskIdentifier(decryptKycField($kycPrivate["aadhaar_number_enc"]))) : 'Not Set'; ?></code>
                                    </td>
                                    <td>
                                        <input type="text" name="aadhaar_number" placeholder="Enter 12-digit Aadhaar" style="width:180px;" <?php echo !$canEditStatutory ? 'disabled' : ''; ?>>
                                    </td>
                                </tr>

                                <!-- UAN -->
                                <tr style="border-bottom:1px solid #f1f5f9;">
                                    <td style="padding:10px 0; font-weight:600;">UAN (EPF)</td>
                                    <td>
                                        <label><input type="checkbox" name="uan_applicable" value="1" <?php echo (!empty($kycPrivate["uan_applicable"]) && (int)$kycPrivate["uan_applicable"] === 1) ? 'checked' : ''; ?> <?php echo !$canEditStatutory ? 'disabled' : ''; ?>> Yes</label>
                                    </td>
                                    <td>
                                        <code><?php echo !empty($kycPrivate["uan_number_enc"]) ? htmlspecialchars(maskIdentifier(decryptKycField($kycPrivate["uan_number_enc"]))) : 'Not Set'; ?></code>
                                    </td>
                                    <td>
                                        <input type="text" name="uan_number" placeholder="Enter 12-digit UAN" style="width:180px;" <?php echo !$canEditStatutory ? 'disabled' : ''; ?>>
                                    </td>
                                </tr>

                                <!-- ESIC -->
                                <tr style="border-bottom:1px solid #f1f5f9;">
                                    <td style="padding:10px 0; font-weight:600;">ESIC IP Number</td>
                                    <td>
                                        <label><input type="checkbox" name="esic_applicable" value="1" <?php echo (!empty($kycPrivate["esic_applicable"]) && (int)$kycPrivate["esic_applicable"] === 1) ? 'checked' : ''; ?> <?php echo !$canEditStatutory ? 'disabled' : ''; ?>> Yes</label>
                                    </td>
                                    <td>
                                        <code><?php echo !empty($kycPrivate["esic_number_enc"]) ? htmlspecialchars(maskIdentifier(decryptKycField($kycPrivate["esic_number_enc"]))) : 'Not Set'; ?></code>
                                    </td>
                                    <td>
                                        <input type="text" name="esic_number" placeholder="Enter 17-digit ESIC" style="width:180px;" <?php echo !$canEditStatutory ? 'disabled' : ''; ?>>
                                    </td>
                                </tr>
                            </tbody>
                        </table>

                        <?php if ($canEditStatutory) { ?>
                            <div class="form-actions">
                                <button type="submit" class="btn-generate">Save Statutory Details</button>
                            </div>
                        <?php } ?>
                    </form>

                    <!-- Sensitive Value Reveal Section for Admin and KYC Officers -->
                    <div style="margin-top:20px; border-top:1px solid #e2e8f0; padding-top:16px;">
                        <div style="font-weight:600; margin-bottom:8px; font-size:14px;">Audit-Logged Sensitive Field Reveal (Admin / KYC Officer)</div>
                        <p style="font-size:12px; color:#64748b; margin-bottom:12px;">
                            Revealing full statutory values is recorded in the security audit log. Values are decrypted on request only and never stored in URLs or browser state.
                        </p>

                        <div style="display:flex; gap:10px; flex-wrap:wrap;">
                            <?php foreach (['pan' => 'PAN', 'aadhaar' => 'Aadhaar', 'uan' => 'UAN', 'esic' => 'ESIC'] as $fKey => $fLabel) { ?>
                                <form method="post" action="employee_kyc.php" style="display:inline;">
                                    <?php echo csrfField(); ?>
                                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                                    <input type="hidden" name="action" value="reveal">
                                    <input type="hidden" name="field_name" value="<?php echo $fKey; ?>">
                                    <button type="submit" class="btn-secondary-link" style="font-size:12px; padding:6px 12px;">Reveal <?php echo $fLabel; ?></button>
                                </form>
                            <?php } ?>
                        </div>

                        <?php if ($revealedField && $revealedValue !== null) { ?>
                            <div class="flash-message flash-success" style="margin-top:12px;">
                                <strong>Revealed <?php echo strtoupper($revealedField); ?>:</strong>
                                <code style="font-size:15px; font-weight:700; background:#ffffff; padding:2px 8px; border-radius:4px;"><?php echo htmlspecialchars($revealedValue !== '' ? $revealedValue : 'Not Set'); ?></code>
                            </div>
                        <?php } ?>
                    </div>

                <?php } ?>
            </div>

            <!-- Section 3: Optional Bank Details -->
            <div class="panel-card" style="margin-bottom:16px;">
                <div class="panel-title">3. Bank Details</div>
                <?php if (!$canSensitive) { ?>
                    <p style="color:#64748b; font-size:13px;">Bank details are managed by an authorized KYC Officer.</p>
                <?php } else { ?>
                <?php if (!$isVerified) { ?>
                    <form method="post" action="employee_kyc.php">
                        <?php echo csrfField(); ?>
                        <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                        <input type="hidden" name="action" value="save_bank">
                        <div class="form-grid">
                            <div><label for="account_number">Account Number</label><input type="text" id="account_number" name="account_number" inputmode="numeric" autocomplete="off" placeholder="6 to 24 digits"></div>
                            <div><label for="confirm_account_number">Confirm Account Number</label><input type="text" id="confirm_account_number" name="confirm_account_number" inputmode="numeric" autocomplete="off"></div>
                            <div><label for="ifsc_code">IFSC Code</label><input type="text" id="ifsc_code" name="ifsc_code" maxlength="11" style="text-transform:uppercase;" value="<?php echo htmlspecialchars($kycBank['ifsc_code'] ?? ''); ?>"></div>
                            <div><label for="account_type">Account Type</label><select id="account_type" name="account_type"><option value="">Select type</option><?php foreach (KYC_BANK_ACCOUNT_TYPES as $type) { ?><option value="<?php echo $type; ?>" <?php echo (($kycBank['account_type'] ?? '') === $type) ? 'selected' : ''; ?>><?php echo htmlspecialchars(ucfirst(strtolower($type))); ?></option><?php } ?></select></div>
                            <div style="grid-column:1 / -1;"><label for="branch_name">Bank Branch Name</label><input type="text" id="branch_name" name="branch_name" maxlength="150" value="<?php echo htmlspecialchars($kycBank['branch_name'] ?? ''); ?>"></div>
                        </div>
                        <p style="font-size:12px; color:#64748b;">Bank details are optional. If started, all four fields must be completed.</p>
                        <div class="form-actions" style="margin-top:16px;"><button type="submit" class="btn-generate">Save Bank Details</button></div>
                    </form>
                <?php } else { ?>
                    <p>Account Number: <code><?php echo !empty($kycBank['account_number_enc']) ? htmlspecialchars(maskBankAccountNumber(decryptKycField($kycBank['account_number_enc']))) : 'Not Set'; ?></code></p>
                    <p>IFSC Code: <?php echo htmlspecialchars($kycBank['ifsc_code'] ?? 'Not Set'); ?></p>
                    <p>Account Type: <?php echo htmlspecialchars($kycBank['account_type'] ?? 'Not Set'); ?></p>
                    <p>Branch Name: <?php echo htmlspecialchars($kycBank['branch_name'] ?? 'Not Set'); ?></p>
                <?php } ?>
                <?php if ($canSensitive && !empty($kycBank['account_number_enc'])) { ?>
                    <form method="post" action="employee_kyc.php" style="margin-top:12px;">
                        <?php echo csrfField(); ?><input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>"><input type="hidden" name="action" value="reveal_bank_account">
                        <button type="submit" class="btn-secondary-link">Reveal Account Number</button>
                    </form>
                <?php } ?>
                <?php if ($revealedBankAccount !== null) { ?><div class="flash-message flash-success" style="margin-top:12px;"><strong>Revealed Account Number:</strong> <code><?php echo htmlspecialchars($revealedBankAccount !== '' ? $revealedBankAccount : 'Not Set'); ?></code></div><?php } ?>
                <?php } ?>
            </div>

        <?php } ?>


        <div class="panel-card" style="margin-top:16px;">
            <div class="panel-title">KYC Documents</div>
            <?php if ($canSensitive) { ?>
                <p style="font-size:13px; color:#475569;">Managed document versions: <?php echo (int)$documentCount; ?></p>
                <a class="btn-secondary-link" href="documents.php?employee_id=<?php echo $employeeId; ?>">Manage KYC Documents</a>
            <?php } else { ?>
                <p style="font-size:13px; color:#64748b;">Documents are managed by an authorized KYC Officer.</p>
            <?php } ?>
        </div>

        <div class="panel-card" style="margin-top:16px;">
            <div class="panel-title">Employee Benefits</div>
            <?php if (!$canSensitive) { ?>
                <p style="font-size:13px; color:#64748b;">Employee benefit information is restricted.</p>
            <?php } else { ?>
                <p>Group Medical Insurance: <strong><?php echo htmlspecialchars(groupMedicalCoverageLabel($benefitStatus['group_medical_covered'] ?? null)); ?></strong></p>
                <form method="post" action="employee_kyc.php" style="margin-top:12px;">
                    <?php echo csrfField(); ?>
                    <input type="hidden" name="employee_id" value="<?php echo $employeeId; ?>">
                    <input type="hidden" name="action" value="save_benefit_status">
                    <label for="group_medical_covered">Group Medical Insurance</label>
                    <select id="group_medical_covered" name="group_medical_covered">
                        <option value="NOT_SET" <?php echo (($benefitStatus['group_medical_covered'] ?? null) === null) ? 'selected' : ''; ?>>Not Set</option>
                        <option value="COVERED" <?php echo isset($benefitStatus['group_medical_covered']) && (int)$benefitStatus['group_medical_covered'] === 1 ? 'selected' : ''; ?>>Covered</option>
                        <option value="NOT_COVERED" <?php echo isset($benefitStatus['group_medical_covered']) && (int)$benefitStatus['group_medical_covered'] === 0 ? 'selected' : ''; ?>>Not Covered</option>
                    </select>
                    <div class="form-actions" style="margin-top:12px;"><button type="submit" class="btn-generate">Save Benefit Status</button></div>
                </form>
                <p style="margin-top:12px;"><a class="btn-secondary-link" href="../reports/group_medical_insurance.php">Group Medical Insurance Report</a></p>
            <?php } ?>
        </div>

        <div class="table-wrap">
            <table>
                <thead>
                    <tr>
                        <th style="width:140px;">Timestamp</th>
                        <th style="width:110px;">Actor</th>
                        <th style="width:110px;">Action</th>
                        <th style="width:110px;">Transition</th>
                        <th>Remarks / Reason</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (!empty($kycHistory)) { ?>
                        <?php foreach ($kycHistory as $h) { ?>
                            <tr>
                                <td style="font-size:12px; color:#64748b;"><?php echo htmlspecialchars($h["created_at"]); ?></td>
                                <td><?php echo htmlspecialchars($h["actor_name"] ?? "System"); ?></td>
                                <td><code><?php echo htmlspecialchars($h["action"]); ?></code></td>
                                <td>
                                    <span style="font-size:11px; color:#475569;">
                                        <?php echo htmlspecialchars($h["previous_status"]); ?> →
                                        <strong><?php echo htmlspecialchars($h["new_status"]); ?></strong>
                                    </span>
                                </td>
                                <td><?php echo htmlspecialchars($h["remarks"] ?? ""); ?></td>
                            </tr>
                        <?php } ?>
                    <?php } else { ?>
                        <tr>
                            <td colspan="5" style="color:#64748b; text-align:center;">No workflow history recorded yet.</td>
                        </tr>
                    <?php } ?>
                </tbody>
            </table>
        </div>
    </div>

</div>

<?php require_once "../includes/footer.php"; ?>

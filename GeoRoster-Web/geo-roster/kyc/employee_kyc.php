<?php

require_once "../includes/auth_check.php";
require_once "../config/database.php";
require_once "../includes/security.php";
require_once "../includes/functions.php";
require_once "../includes/kyc_service.php";

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
    } elseif ($action === "reveal") {
        $fieldToReveal = trim($_POST["field_name"] ?? "");
        $revealedVal = revealKycField($conn, $employeeId, $fieldToReveal);
        $_SESSION["revealed_field"] = $fieldToReveal;
        $_SESSION["revealed_value"] = $revealedVal;
        $_SESSION["flash_message"] = "Unmasked value revealed for " . strtoupper($fieldToReveal) . " (Audit Logged).";
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
$kycStatus = $kycProfile ? $kycProfile["kyc_status"] : KYC_STATUS_NOT_STARTED;
$kycHistory = $kycProfile ? getKycHistory($conn, (int)($kycProfile["kyc_id"] ?? 0)) : [];

$activeAmendment = $kycProfile ? getKycActiveAmendment($conn, (int)$kycProfile["kyc_id"]) : null;
if (!$activeAmendment && $kycProfile) {
    $latestAmendment = getKycLatestAmendment($conn, (int)$kycProfile["kyc_id"]);
    if ($latestAmendment && $latestAmendment["amendment_status"] === AMENDMENT_STATUS_REJECTED) {
        $activeAmendment = $latestAmendment;
    }
}
$amendmentPrivate = $activeAmendment ? getKycAmendmentPrivateData($conn, (int)$activeAmendment["amendment_id"]) : null;
$amendmentStatus = $activeAmendment ? $activeAmendment["amendment_status"] : null;

if (isset($_SESSION["revealed_field"]) && isset($_SESSION["revealed_value"])) {
    $revealedField = $_SESSION["revealed_field"];
    $revealedValue = $_SESSION["revealed_value"];
    unset($_SESSION["revealed_field"], $_SESSION["revealed_value"]);
}

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
$canEditStatutory = ($userRole === 'Admin' || $userRole === 'HO User') && !$isVerified;
$canEditBasic = !$isVerified;

$canEditAmendmentBasic = $activeAmendment && in_array($amendmentStatus, ['DRAFT', 'REQUESTED'], true);
$canEditAmendmentStatutory = $activeAmendment && in_array($amendmentStatus, ['DRAFT', 'REQUESTED'], true) && ($userRole === 'Admin' || $userRole === 'HO User');
?>

<div class="module-two-col">

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

            <?php if ($kycStatus === KYC_STATUS_SUBMITTED && canUserTransitionKyc($userRole, KYC_STATUS_SUBMITTED, KYC_STATUS_UNDER_REVIEW)) { ?>
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

                        <?php if ($amendmentStatus === 'SUBMITTED' && ($userRole === 'Admin' || $userRole === 'HO User')) { ?>
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

                <?php if ($userRole === 'Branch User') { ?>
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

                <?php if ($userRole === 'Branch User') { ?>
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

                    <!-- Sensitive Value Reveal Section for Admin & HO Users -->
                    <div style="margin-top:20px; border-top:1px solid #e2e8f0; padding-top:16px;">
                        <div style="font-weight:600; margin-bottom:8px; font-size:14px;">Audit-Logged Sensitive Field Reveal (Admin / HO)</div>
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

        <?php } ?>


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

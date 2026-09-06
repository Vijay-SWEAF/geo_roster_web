<?php
if (!defined('APP_INCLUDED')) {
    http_response_code(403);
    exit('Forbidden');
}

if (!isset($basePath)) {
    $basePath = "";
}
?>

</div>
</div>

<div class="footer-license">
   Subscriber: <strong>Surge Marine Services Pvt. Ltd.</strong>
</div>


<div class="footer">
    © <?php echo date('Y'); ?> SWEAF®. All Rights Reserved. Registered Trademark in India.
</div>

<script src="<?php echo $basePath; ?>assets/js/attendance.js"></script>
<script src="<?php echo $basePath; ?>assets/js/management_dashboard.js"></script>

</body>
</html>
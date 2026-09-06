<?php
require_once "../includes/security.php";
startSecureSession();
applySecurityHeaders();
require_once "../config/database.php";

$error = "";
$currentYear = date("Y");

if ($_SERVER["REQUEST_METHOD"] == "POST") {

    $username = trim($_POST["username"] ?? "");
    $password = trim($_POST["password"] ?? "");

    if ($username === "" || $password === "") {
        $error = "Username and password are required.";
    } else {

        $stmt = $conn->prepare("SELECT * FROM users WHERE username = ? AND is_active = 1 LIMIT 1");
        $stmt->bind_param("s", $username);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result && $result->num_rows == 1) {

            $user = $result->fetch_assoc();
            $stored_password = $user["password_hash"] ?? "";

            $is_valid_login = false;
            $used_legacy_password = false;

            /* Support both old plain-text passwords and new hashed passwords */
            if ($stored_password !== "" && password_verify($password, $stored_password)) {
                $is_valid_login = true;
            } elseif ($stored_password !== "" && hash_equals($stored_password, $password)) {
                $is_valid_login = true;
                $used_legacy_password = true;
            }

            if ($is_valid_login) {

                session_regenerate_id(true);
                if ($used_legacy_password) {
                    $migrated_hash = password_hash($password, PASSWORD_DEFAULT);
                    $migrate = $conn->prepare("UPDATE users SET password_hash = ? WHERE user_id = ?");
                    $migrate->bind_param("si", $migrated_hash, $user["user_id"]);
                    $migrate->execute();
                }

                $_SESSION["user_id"] = $user["user_id"];
                $_SESSION["role"] = $user["role_name"];
                $_SESSION["full_name"] = $user["full_name"];

                unset($_SESSION["flash_error"], $_SESSION["flash_message"]);

                header("Location: ../dashboard.php");
                exit;

            } else {
                $error = "Invalid username or password.";
            }

        } else {
            $error = "Invalid username or password.";
        }
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GeoRoster Attendance Login</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            font-family: Arial, Helvetica, sans-serif;
        }

        body {
            background: linear-gradient(135deg, #0f172a, #1e293b, #334155);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            color: #1f2937;
        }

        .page-wrapper {
            flex: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 30px 15px;
        }

        .login-card {
            width: 100%;
            max-width: 420px;
            background: #ffffff;
            border-radius: 18px;
            box-shadow: 0 18px 45px rgba(0, 0, 0, 0.22);
            overflow: hidden;
        }

        .login-header {
            background: linear-gradient(135deg, #0f766e, #0ea5e9);
            padding: 28px 24px 22px;
            text-align: center;
            color: #ffffff;
        }

        .app-logo {
            width: 84px;
            height: 84px;
            object-fit: contain;
            background: #ffffff;
            border-radius: 16px;
            padding: 10px;
            box-shadow: 0 8px 18px rgba(0,0,0,0.18);
            margin-bottom: 14px;
        }

        .login-header h1 {
            font-size: 26px;
            font-weight: 700;
            margin-bottom: 8px;
            letter-spacing: 0.3px;
        }

        .login-header p {
            font-size: 14px;
            opacity: 0.95;
            line-height: 1.5;
        }

        .login-body {
            padding: 28px 24px 24px;
        }

        .form-group {
            margin-bottom: 18px;
        }

        .form-group label {
            display: block;
            margin-bottom: 8px;
            font-size: 14px;
            font-weight: 600;
            color: #374151;
        }

        .form-group input {
            width: 100%;
            padding: 13px 14px;
            border: 1px solid #cbd5e1;
            border-radius: 10px;
            font-size: 14px;
            outline: none;
            transition: 0.2s ease;
        }

        .form-group input:focus {
            border-color: #0ea5e9;
            box-shadow: 0 0 0 3px rgba(14, 165, 233, 0.15);
        }

        .login-btn {
            width: 100%;
            padding: 13px 16px;
            background: linear-gradient(135deg, #0f766e, #0284c7);
            color: #ffffff;
            border: none;
            border-radius: 10px;
            font-size: 15px;
            font-weight: 700;
            cursor: pointer;
            transition: 0.2s ease;
        }

        .login-btn:hover {
            transform: translateY(-1px);
            box-shadow: 0 8px 18px rgba(2, 132, 199, 0.25);
        }

        .error-box {
            background: #fef2f2;
            border: 1px solid #fecaca;
            color: #b91c1c;
            padding: 12px 14px;
            border-radius: 10px;
            margin-bottom: 18px;
            font-size: 14px;
        }

        .login-footer {
            margin-top: 22px;
            text-align: center;
            color: #6b7280;
            font-size: 13px;
            line-height: 1.6;
        }

        .company-logo-wrap {
            margin-top: 14px;
            text-align: center;
        }

        .company-logo {
            width: 110px;
            max-width: 100%;
            object-fit: contain;
            opacity: 0.95;
        }

        .site-footer {
            text-align: center;
            color: #e5e7eb;
            font-size: 13px;
            padding: 14px 16px 20px;
            line-height: 1.6;
        }

        .site-footer .rtm {
            font-weight: 700;
        }

        @media (max-width: 480px) {
            .login-header h1 {
                font-size: 22px;
            }

            .login-card {
                border-radius: 14px;
            }

            .login-body,
            .login-header {
                padding-left: 18px;
                padding-right: 18px;
            }
        }
    </style>
</head>
<body>

    <div class="page-wrapper">
        <div class="login-card">

            <div class="login-header">
                <img src="../assets/img/geo-roster.png" alt="GeoRoster Logo" class="app-logo">
                <h1>GeoRoster Attendance</h1>
                <p>Secure login for branch operations, head office monitoring, and attendance management.</p>
            </div>

            <div class="login-body">

                <?php if (!empty($error)) : ?>
                    <div class="error-box"><?php echo $error; ?></div>
                <?php endif; ?>

                <form method="post" action="">
                    <div class="form-group">
                        <label for="username">Username</label>
                        <input type="text" id="username" name="username" placeholder="Enter your username" required>
                    </div>

                    <div class="form-group">
                        <label for="password">Password</label>
                        <input type="password" id="password" name="password" placeholder="Enter your password" required>
                    </div>

                    <button type="submit" class="login-btn">Sign In</button>
                </form>

                <div class="login-footer">
                    Developed and managed by
                    <div class="company-logo-wrap">
                        <img src="../assets/img/SWEAF_R_Logo.png" alt="SWEAF Logo" class="company-logo">
                    </div>
                </div>

            </div>
        </div>
    </div>

    <div class="site-footer">
        &copy; <?php echo $currentYear; ?> SWEAF<sup>&reg;</sup>. All Rights Reserved. Registered Trademark in India.
    </div>

</body>
</html>
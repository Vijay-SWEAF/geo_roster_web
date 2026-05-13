import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_utils.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _otpSent = false;
  int _resendCooldown = 0;
  Timer? _resendTimer;
  bool _isLoading = false;

  String _cleanErrorMessage(Object error) {
    final message = error.toString().trim();
    const prefix = 'Exception:';
    if (message.startsWith(prefix)) {
      return message.substring(prefix.length).trim();
    }
    return message;
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
        return;
      }
      setState(() => _resendCooldown -= 1);
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !AppUtils.isValidEmail(email)) {
      AppUtils.showSnack(context, AppL10n.of(context).invalidEmail, isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).requestEmailPasscode(email: email);
      if (!mounted) return;
      setState(() => _otpSent = true);
      _startResendCooldown();
      AppUtils.showSnack(
        context,
        AppL10n.of(context).otpSentMessage,
      );
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnack(context, _cleanErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).verifyEmailPasscode(
            email: _emailCtrl.text.trim(),
            passcode: _otpCtrl.text.trim(),
          );
      if (mounted) context.go('/home');
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnack(context, _cleanErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                // Logo area
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Image.asset(
                          'playstore/app_icon_green.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(AppL10n.of(context).appName, style: AppTextStyles.h1),
                      const SizedBox(height: 4),
                      Text(
                        AppL10n.of(context).preserveRoots,
                        style: AppTextStyles.bodySmall
                            .copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Text(l10n.loginWelcome, style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text(
                  l10n.loginOtpHint,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_otpSent || _isLoading == false,
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.emailRequired;
                    if (!AppUtils.isValidEmail(v)) return l10n.invalidEmail;
                    return null;
                  },
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.otpLabel,
                      hintText: l10n.otpHint,
                      prefixIcon: const Icon(Icons.mark_email_read_outlined),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return l10n.otpRequired;
                      if (!RegExp(r'^\d{6,8}$').hasMatch(value)) {
                        return l10n.otpInvalid;
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: (_isLoading || _resendCooldown > 0)
                      ? null
                      : _sendOtp,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(_otpSent
                          ? (_resendCooldown > 0
                              ? l10n.resendIn(_resendCooldown)
                              : l10n.resendPasscode)
                          : l10n.sendPasscode),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    child: Text(l10n.verifyAndSignIn),
                  ),
                ],
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    l10n.loginOtpNote,
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

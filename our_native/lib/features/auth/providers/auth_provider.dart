import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';

/// Auth state provider — holds the current Supabase User or null.
final authProvider = NotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

class AuthNotifier extends Notifier<User?> {
  StreamSubscription<AuthState>? _authSub;

  @override
  User? build() {
    _authSub = SupabaseService.instance.authStateChanges.listen((event) {
      state = event.session?.user;
    });

    ref.onDispose(() {
      _authSub?.cancel();
    });

    return SupabaseService.instance.currentUser;
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    state = res.user;
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await supabase.auth.signUp(
      email: email,
      password: password,
    );
    state = res.user;
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    state = null;
  }

  /// Request email OTP/passcode for passwordless login.
  Future<void> requestEmailPasscode({
    required String email,
  }) async {
    await supabase.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      // true = creates account automatically for new users (OTP-only signup)
      shouldCreateUser: true,
    );
  }

  Future<void> verifyEmailPasscode({
    required String email,
    required String passcode,
  }) async {
    // Try both OtpType.email and OtpType.magiclink to handle both
    // Supabase OTP variants (which vary by SDK version).
    for (final type in [OtpType.email, OtpType.magiclink]) {
      try {
        final res = await supabase.auth.verifyOTP(
          email: email.trim().toLowerCase(),
          token: passcode.trim(),
          type: type,
        );
        state = res.user;
        return;
      } catch (_) {
        // Try next type.
      }
    }
    throw Exception(
      'Code is invalid or expired. Request a new code and enter the latest one.',
    );
  }
}

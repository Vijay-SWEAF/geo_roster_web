import 'package:flutter_test/flutter_test.dart';

import 'package:our_native/core/router/app_router.dart';

void main() {
  group('resolveAppRedirect', () {
    test('redirects unauthenticated protected route to login', () {
      final result = resolveAppRedirect(
        location: '/home',
        isLoggedIn: false,
        hasCommunity: false,
        isApproved: false,
      );

      expect(result, '/login');
    });

    test('redirects authenticated user without community to profile setup', () {
      final result = resolveAppRedirect(
        location: '/home',
        isLoggedIn: true,
        hasCommunity: false,
        isApproved: false,
      );

      expect(result, '/profile-setup');
    });

    test('redirects authenticated community user away from login', () {
      final result = resolveAppRedirect(
        location: '/login',
        isLoggedIn: true,
        hasCommunity: true,
        isApproved: true,
      );

      expect(result, '/home');
    });

    test('blocks unapproved user from posting routes', () {
      final result = resolveAppRedirect(
        location: '/create-post',
        isLoggedIn: true,
        hasCommunity: true,
        isApproved: false,
      );

      expect(result, '/home');
    });

    test('allows approved user to create post', () {
      final result = resolveAppRedirect(
        location: '/create-post',
        isLoggedIn: true,
        hasCommunity: true,
        isApproved: true,
      );

      expect(result, isNull);
    });
  });
}

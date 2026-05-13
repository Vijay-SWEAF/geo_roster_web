import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:our_native/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('login screen toggles between passcode and signup modes',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Passcode Login'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    expect(find.byType(TextFormField), findsOneWidget);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Create Account'), findsNWidgets(2));

    await tester.tap(find.text('Passcode Login'));
    await tester.pumpAndSettle();

    expect(find.text('Send Passcode'), findsOneWidget);
    expect(find.text('Verify and Sign In'), findsOneWidget);
  });
}

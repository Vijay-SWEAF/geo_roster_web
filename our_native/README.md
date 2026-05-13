# our_native

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase OTP Email (Free Tier Friendly)

This app uses built-in Supabase email OTP via `signInWithOtp` and verifies via `verifyOTP`.

If you receive a login link in the email instead of a code, update your Supabase email template:

1. Open Supabase Dashboard -> Authentication -> Email Templates.
2. Edit the OTP / Magic Link template body.
3. Include the token variable in the message body, for example:

```html
<h2>Your OurNative passcode</h2>
<p>Use this code to sign in:</p>
<p style="font-size:32px;letter-spacing:4px;"><strong>{{ .Token }}</strong></p>
<p>This code expires soon.</p>
```

Notes:

- Keep OTP enabled in your auth settings.
- App verification call remains `verifyOTP(email, token, type: OtpType.email)`.

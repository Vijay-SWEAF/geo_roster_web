// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Our Native';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get getStarted => 'Get Started';

  @override
  String get onboarding1Title => 'Our village.\nOur memories.\nOur people.';

  @override
  String get onboarding1Subtitle =>
      'Preserve old photos, stories, and values that connect generations.';

  @override
  String get onboarding2Title => 'Stronger together,\nalways.';

  @override
  String get onboarding2Subtitle =>
      'Share with care, help each other, and keep our bonds growing.';

  @override
  String get onboarding3Title => 'One day,\nthese stories\nwill be history.';

  @override
  String get onboarding3Subtitle =>
      'Preserve our stories, traditions, and memories so future generations always know where they belong.';

  @override
  String get onboarding4Title => 'Kind words,\nopen hearts,\none family.';

  @override
  String get onboarding4Subtitle =>
      'Respect first, speak gently, and build a community where everyone belongs.';

  @override
  String get loginTitle => 'Our Native';

  @override
  String get loginSubtitle => 'Welcome back to your village';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get loginButton => 'Sign In';

  @override
  String get signupPrompt => 'New here?';

  @override
  String get signupLink => 'Sign up';

  @override
  String get homeTitle => 'Our Native';

  @override
  String get memories => 'Memories';

  @override
  String get help => 'Help';

  @override
  String get events => 'Events';

  @override
  String get ourVillage => 'Our Village';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get preserveRoots => 'Preserve roots. Rebuild bonds.';

  @override
  String get loginWelcome => 'Welcome';

  @override
  String get loginPasscodeHint => 'Secure access with email passcode';

  @override
  String get loginOtpHint =>
      'Enter your email to receive a one-time code. New users are registered automatically.';

  @override
  String get passcodeLogin => 'Passcode Login';

  @override
  String get createAccount => 'Create Account';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get invalidEmail => 'Enter a valid email';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

  @override
  String get passcodeLabel => 'Email Passcode';

  @override
  String get passcodeHint => 'Enter 8-digit code';

  @override
  String get passcodeRequired => 'Passcode is required';

  @override
  String get passcodeInvalid => 'Enter a valid 8-digit passcode';

  @override
  String get otpLabel => 'One-Time Code';

  @override
  String get otpHint => 'Enter 8-digit code';

  @override
  String get otpRequired => 'Code is required';

  @override
  String get otpInvalid => 'Enter the 8-digit code from your email';

  @override
  String get otpSentMessage => 'Code sent! Check your inbox (and spam folder).';

  @override
  String get loginOtpNote =>
      'New user? Your account is created automatically when you verify the code.';

  @override
  String get sendPasscode => 'Send Passcode';

  @override
  String get resendPasscode => 'Resend Passcode';

  @override
  String resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get verifyAndSignIn => 'Verify and Sign In';

  @override
  String get didntGetCode =>
      'Didn\'t get a code? Check spam or request resend in 30s.';

  @override
  String get accountsNote =>
      'Accounts are community-scoped. Login requires email passcode after confirmation.';

  @override
  String get tabHome => 'Home';

  @override
  String get profile => 'Profile';

  @override
  String get myProfile => 'My Profile';

  @override
  String get edit => 'Edit';

  @override
  String get account => 'Account';

  @override
  String get myMemories => 'My Memories';

  @override
  String get myHelpPosts => 'My Help Posts';

  @override
  String get savedEvents => 'Saved Events';

  @override
  String get notifications => 'Notifications';

  @override
  String get privacy => 'Privacy';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutTitle => 'Sign Out?';

  @override
  String get signOutConfirm => 'Are you sure you want to sign out?';

  @override
  String get cancel => 'Cancel';

  @override
  String get posts => 'Posts';

  @override
  String get helped => 'Helped';
}

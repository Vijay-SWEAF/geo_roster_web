import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_mr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('mr'),
    Locale('en'),
  ];

  /// App name in Marathi
  ///
  /// In mr, this message translates to:
  /// **'आपलं गाव'**
  String get appName;

  /// Next button
  ///
  /// In mr, this message translates to:
  /// **'पुढे'**
  String get next;

  /// Skip button
  ///
  /// In mr, this message translates to:
  /// **'वगळा'**
  String get skip;

  /// Get started button on last onboarding screen
  ///
  /// In mr, this message translates to:
  /// **'सुरू करा'**
  String get getStarted;

  /// Onboarding screen 1 title
  ///
  /// In mr, this message translates to:
  /// **'आपलं गाव.\nआपल्या आठवणी.\nआपली माणसं.'**
  String get onboarding1Title;

  /// Onboarding screen 1 subtitle
  ///
  /// In mr, this message translates to:
  /// **'जुन्या छायाचित्रांचा, स्मृतीकथांचा आणि पिढ्यान्‌पिढ्या जपल्या गेलेल्या संस्कारमूल्यांचा जतनपूर्वक वारसा पुढील पिढ्यांपर्यंत पोहोचवूया.'**
  String get onboarding1Subtitle;

  /// Onboarding screen 2 title
  ///
  /// In mr, this message translates to:
  /// **'एकत्र असलो\nतर अजिंक्य.'**
  String get onboarding2Title;

  /// Onboarding screen 2 subtitle
  ///
  /// In mr, this message translates to:
  /// **'एकमेकांशी सवांद साधून, परस्परांना सहाय्य करूया आणि आपल्या नातेसंबंधांचा ऋणानुबंध अधिक दृढ व अखंड ठेवूया.'**
  String get onboarding2Subtitle;

  /// Onboarding screen 3 title
  ///
  /// In mr, this message translates to:
  /// **'एक दिवस,\nया गोष्टी\nइतिहास होतील.'**
  String get onboarding3Title;

  /// Onboarding screen 3 subtitle
  ///
  /// In mr, this message translates to:
  /// **'आपल्या कथा, परंपरा आणि स्मृती यांचा जतनपूर्वक वारसा पुढील पिढ्यांसाठी सांभाळूया, जेणेकरून त्यांना आपल्या मुळांची आणि आपलेपणाची जाणीव सदैव राहील.'**
  String get onboarding3Subtitle;

  /// Onboarding screen 4 title
  ///
  /// In mr, this message translates to:
  /// **'मृदू शब्द,\nउघडी मने,\nएक कुटुंब.'**
  String get onboarding4Title;

  /// Onboarding screen 4 subtitle
  ///
  /// In mr, this message translates to:
  /// **'परस्परांचा मान ठेवून, सौम्य व आदरयुक्त संवाद साधूया आणि प्रत्येकाला आपलेपणाची अनुभूती देणारा सुसंस्कृत समुदाय घडवूया.'**
  String get onboarding4Subtitle;

  /// Login screen title
  ///
  /// In mr, this message translates to:
  /// **'आपलं गाव'**
  String get loginTitle;

  /// Login screen subtitle
  ///
  /// In mr, this message translates to:
  /// **'आपल्या गावात स्वागत आहे'**
  String get loginSubtitle;

  /// Email field label
  ///
  /// In mr, this message translates to:
  /// **'ईमेल'**
  String get emailLabel;

  /// Password field label
  ///
  /// In mr, this message translates to:
  /// **'पासवर्ड'**
  String get passwordLabel;

  /// Login button
  ///
  /// In mr, this message translates to:
  /// **'आत या'**
  String get loginButton;

  /// Sign up prompt
  ///
  /// In mr, this message translates to:
  /// **'नवीन आहात?'**
  String get signupPrompt;

  /// Sign up link
  ///
  /// In mr, this message translates to:
  /// **'नोंदणी करा'**
  String get signupLink;

  /// Home screen app bar title
  ///
  /// In mr, this message translates to:
  /// **'आपलं गाव'**
  String get homeTitle;

  /// Memories tab/section
  ///
  /// In mr, this message translates to:
  /// **'आठवणी'**
  String get memories;

  /// Help tab/section
  ///
  /// In mr, this message translates to:
  /// **'मदत'**
  String get help;

  /// Events tab/section
  ///
  /// In mr, this message translates to:
  /// **'कार्यक्रम'**
  String get events;

  /// Our village tab/section
  ///
  /// In mr, this message translates to:
  /// **'आपलं गाव'**
  String get ourVillage;

  /// Settings
  ///
  /// In mr, this message translates to:
  /// **'सेटिंग्ज'**
  String get settings;

  /// Language setting label
  ///
  /// In mr, this message translates to:
  /// **'भाषा'**
  String get language;

  /// Login screen tagline
  ///
  /// In mr, this message translates to:
  /// **'मुळे जपा. नाती जोडा.'**
  String get preserveRoots;

  /// Welcome heading on login screen
  ///
  /// In mr, this message translates to:
  /// **'स्वागत'**
  String get loginWelcome;

  /// Login screen subheading
  ///
  /// In mr, this message translates to:
  /// **'ईमेल पासकोडद्वारे सुरक्षित प्रवेश'**
  String get loginPasscodeHint;

  /// OTP-only login screen subtitle
  ///
  /// In mr, this message translates to:
  /// **'ईमेल प्रविष्ट करा, एक-वेळचा कोड पाठवला जाईल. नवीन वापरकर्ते आपोआप नोंदणी होतात.'**
  String get loginOtpHint;

  /// Segmented button - passcode tab
  ///
  /// In mr, this message translates to:
  /// **'पासकोड लॉगिन'**
  String get passcodeLogin;

  /// Create account button / segmented tab
  ///
  /// In mr, this message translates to:
  /// **'खाते तयार करा'**
  String get createAccount;

  /// Email required validation error
  ///
  /// In mr, this message translates to:
  /// **'ईमेल आवश्यक आहे'**
  String get emailRequired;

  /// Invalid email validation error
  ///
  /// In mr, this message translates to:
  /// **'योग्य ईमेल प्रविष्ट करा'**
  String get invalidEmail;

  /// Password required validation error
  ///
  /// In mr, this message translates to:
  /// **'पासवर्ड आवश्यक आहे'**
  String get passwordRequired;

  /// Password too short validation error
  ///
  /// In mr, this message translates to:
  /// **'पासवर्ड किमान ८ अक्षरांचा असावा'**
  String get passwordTooShort;

  /// Passcode field label
  ///
  /// In mr, this message translates to:
  /// **'ईमेल पासकोड'**
  String get passcodeLabel;

  /// Passcode field hint
  ///
  /// In mr, this message translates to:
  /// **'८-अंकी कोड प्रविष्ट करा'**
  String get passcodeHint;

  /// Passcode required validation error
  ///
  /// In mr, this message translates to:
  /// **'पासकोड आवश्यक आहे'**
  String get passcodeRequired;

  /// Invalid passcode validation error
  ///
  /// In mr, this message translates to:
  /// **'योग्य ८-अंकी पासकोड प्रविष्ट करा'**
  String get passcodeInvalid;

  /// OTP field label
  ///
  /// In mr, this message translates to:
  /// **'एक-वेळचा कोड'**
  String get otpLabel;

  /// OTP field hint
  ///
  /// In mr, this message translates to:
  /// **'८-अंकी कोड प्रविष्ट करा'**
  String get otpHint;

  /// OTP required validation error
  ///
  /// In mr, this message translates to:
  /// **'कोड आवश्यक आहे'**
  String get otpRequired;

  /// Invalid OTP validation error
  ///
  /// In mr, this message translates to:
  /// **'ईमेलमधील ८-अंकी कोड प्रविष्ट करा'**
  String get otpInvalid;

  /// Snackbar after OTP sent
  ///
  /// In mr, this message translates to:
  /// **'कोड पाठवला! तुमचा इनबॉक्स (आणि स्पॅम) तपासा.'**
  String get otpSentMessage;

  /// Note at bottom of login for new users
  ///
  /// In mr, this message translates to:
  /// **'नवीन वापरकर्ता? कोड सत्यापित केल्यावर खाते आपोआप तयार होते.'**
  String get loginOtpNote;

  /// Send passcode button
  ///
  /// In mr, this message translates to:
  /// **'पासकोड पाठवा'**
  String get sendPasscode;

  /// Resend passcode button
  ///
  /// In mr, this message translates to:
  /// **'पासकोड पुन्हा पाठवा'**
  String get resendPasscode;

  /// Resend countdown label
  ///
  /// In mr, this message translates to:
  /// **'{seconds} से. मध्ये पुन्हा पाठवा'**
  String resendIn(int seconds);

  /// Verify and sign in button
  ///
  /// In mr, this message translates to:
  /// **'सत्यापन करा आणि आत या'**
  String get verifyAndSignIn;

  /// Passcode help hint
  ///
  /// In mr, this message translates to:
  /// **'कोड मिळाला नाही? स्पॅम तपासा किंवा ३० से. नंतर पुन्हा मागवा.'**
  String get didntGetCode;

  /// Account scope note at bottom of login
  ///
  /// In mr, this message translates to:
  /// **'खाती समुदाय-स्तरीय आहेत. प्रवेशासाठी ईमेल पासकोड आवश्यक आहे.'**
  String get accountsNote;

  /// Home tab label
  ///
  /// In mr, this message translates to:
  /// **'मुख्यपृष्ठ'**
  String get tabHome;

  /// Profile tab label
  ///
  /// In mr, this message translates to:
  /// **'प्रोफाइल'**
  String get profile;

  /// My profile screen title
  ///
  /// In mr, this message translates to:
  /// **'माझी प्रोफाइल'**
  String get myProfile;

  /// Edit button
  ///
  /// In mr, this message translates to:
  /// **'संपादित करा'**
  String get edit;

  /// Account section header
  ///
  /// In mr, this message translates to:
  /// **'खाते'**
  String get account;

  /// My memories menu item
  ///
  /// In mr, this message translates to:
  /// **'माझ्या आठवणी'**
  String get myMemories;

  /// My help posts menu item
  ///
  /// In mr, this message translates to:
  /// **'माझ्या मदत पोस्ट'**
  String get myHelpPosts;

  /// Saved events menu item
  ///
  /// In mr, this message translates to:
  /// **'जतन केलेले कार्यक्रम'**
  String get savedEvents;

  /// Notifications menu item
  ///
  /// In mr, this message translates to:
  /// **'सूचना'**
  String get notifications;

  /// Privacy menu item
  ///
  /// In mr, this message translates to:
  /// **'गोपनीयता'**
  String get privacy;

  /// Sign out menu item
  ///
  /// In mr, this message translates to:
  /// **'बाहेर पडा'**
  String get signOut;

  /// Sign out confirmation dialog title
  ///
  /// In mr, this message translates to:
  /// **'बाहेर पडायचे?'**
  String get signOutTitle;

  /// Sign out confirmation dialog body
  ///
  /// In mr, this message translates to:
  /// **'तुम्हाला खरोखर बाहेर पडायचे आहे का?'**
  String get signOutConfirm;

  /// Cancel button
  ///
  /// In mr, this message translates to:
  /// **'रद्द करा'**
  String get cancel;

  /// Posts stat label
  ///
  /// In mr, this message translates to:
  /// **'पोस्ट'**
  String get posts;

  /// Helped stat label
  ///
  /// In mr, this message translates to:
  /// **'मदत केली'**
  String get helped;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'mr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'mr':
      return AppL10nMr();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

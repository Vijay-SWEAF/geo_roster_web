// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Marathi (`mr`).
class AppL10nMr extends AppL10n {
  AppL10nMr([String locale = 'mr']) : super(locale);

  @override
  String get appName => 'आपलं गाव';

  @override
  String get next => 'पुढे';

  @override
  String get skip => 'वगळा';

  @override
  String get getStarted => 'सुरू करा';

  @override
  String get onboarding1Title => 'आपलं गाव.\nआपल्या आठवणी.\nआपली माणसं.';

  @override
  String get onboarding1Subtitle =>
      'जुन्या छायाचित्रांचा, स्मृतीकथांचा आणि पिढ्यान्‌पिढ्या जपल्या गेलेल्या संस्कारमूल्यांचा जतनपूर्वक वारसा पुढील पिढ्यांपर्यंत पोहोचवूया.';

  @override
  String get onboarding2Title => 'एकत्र असलो\nतर अजिंक्य.';

  @override
  String get onboarding2Subtitle =>
      'एकमेकांशी सवांद साधून, परस्परांना सहाय्य करूया आणि आपल्या नातेसंबंधांचा ऋणानुबंध अधिक दृढ व अखंड ठेवूया.';

  @override
  String get onboarding3Title => 'एक दिवस,\nया गोष्टी\nइतिहास होतील.';

  @override
  String get onboarding3Subtitle =>
      'आपल्या कथा, परंपरा आणि स्मृती यांचा जतनपूर्वक वारसा पुढील पिढ्यांसाठी सांभाळूया, जेणेकरून त्यांना आपल्या मुळांची आणि आपलेपणाची जाणीव सदैव राहील.';

  @override
  String get onboarding4Title => 'मृदू शब्द,\nउघडी मने,\nएक कुटुंब.';

  @override
  String get onboarding4Subtitle =>
      'परस्परांचा मान ठेवून, सौम्य व आदरयुक्त संवाद साधूया आणि प्रत्येकाला आपलेपणाची अनुभूती देणारा सुसंस्कृत समुदाय घडवूया.';

  @override
  String get loginTitle => 'आपलं गाव';

  @override
  String get loginSubtitle => 'आपल्या गावात स्वागत आहे';

  @override
  String get emailLabel => 'ईमेल';

  @override
  String get passwordLabel => 'पासवर्ड';

  @override
  String get loginButton => 'आत या';

  @override
  String get signupPrompt => 'नवीन आहात?';

  @override
  String get signupLink => 'नोंदणी करा';

  @override
  String get homeTitle => 'आपलं गाव';

  @override
  String get memories => 'आठवणी';

  @override
  String get help => 'मदत';

  @override
  String get events => 'कार्यक्रम';

  @override
  String get ourVillage => 'आपलं गाव';

  @override
  String get settings => 'सेटिंग्ज';

  @override
  String get language => 'भाषा';

  @override
  String get preserveRoots => 'मुळे जपा. नाती जोडा.';

  @override
  String get loginWelcome => 'स्वागत';

  @override
  String get loginPasscodeHint => 'ईमेल पासकोडद्वारे सुरक्षित प्रवेश';

  @override
  String get loginOtpHint =>
      'ईमेल प्रविष्ट करा, एक-वेळचा कोड पाठवला जाईल. नवीन वापरकर्ते आपोआप नोंदणी होतात.';

  @override
  String get passcodeLogin => 'पासकोड लॉगिन';

  @override
  String get createAccount => 'खाते तयार करा';

  @override
  String get emailRequired => 'ईमेल आवश्यक आहे';

  @override
  String get invalidEmail => 'योग्य ईमेल प्रविष्ट करा';

  @override
  String get passwordRequired => 'पासवर्ड आवश्यक आहे';

  @override
  String get passwordTooShort => 'पासवर्ड किमान ८ अक्षरांचा असावा';

  @override
  String get passcodeLabel => 'ईमेल पासकोड';

  @override
  String get passcodeHint => '८-अंकी कोड प्रविष्ट करा';

  @override
  String get passcodeRequired => 'पासकोड आवश्यक आहे';

  @override
  String get passcodeInvalid => 'योग्य ८-अंकी पासकोड प्रविष्ट करा';

  @override
  String get otpLabel => 'एक-वेळचा कोड';

  @override
  String get otpHint => '८-अंकी कोड प्रविष्ट करा';

  @override
  String get otpRequired => 'कोड आवश्यक आहे';

  @override
  String get otpInvalid => 'ईमेलमधील ८-अंकी कोड प्रविष्ट करा';

  @override
  String get otpSentMessage => 'कोड पाठवला! तुमचा इनबॉक्स (आणि स्पॅम) तपासा.';

  @override
  String get loginOtpNote =>
      'नवीन वापरकर्ता? कोड सत्यापित केल्यावर खाते आपोआप तयार होते.';

  @override
  String get sendPasscode => 'पासकोड पाठवा';

  @override
  String get resendPasscode => 'पासकोड पुन्हा पाठवा';

  @override
  String resendIn(int seconds) {
    return '$seconds से. मध्ये पुन्हा पाठवा';
  }

  @override
  String get verifyAndSignIn => 'सत्यापन करा आणि आत या';

  @override
  String get didntGetCode =>
      'कोड मिळाला नाही? स्पॅम तपासा किंवा ३० से. नंतर पुन्हा मागवा.';

  @override
  String get accountsNote =>
      'खाती समुदाय-स्तरीय आहेत. प्रवेशासाठी ईमेल पासकोड आवश्यक आहे.';

  @override
  String get tabHome => 'मुख्यपृष्ठ';

  @override
  String get profile => 'प्रोफाइल';

  @override
  String get myProfile => 'माझी प्रोफाइल';

  @override
  String get edit => 'संपादित करा';

  @override
  String get account => 'खाते';

  @override
  String get myMemories => 'माझ्या आठवणी';

  @override
  String get myHelpPosts => 'माझ्या मदत पोस्ट';

  @override
  String get savedEvents => 'जतन केलेले कार्यक्रम';

  @override
  String get notifications => 'सूचना';

  @override
  String get privacy => 'गोपनीयता';

  @override
  String get signOut => 'बाहेर पडा';

  @override
  String get signOutTitle => 'बाहेर पडायचे?';

  @override
  String get signOutConfirm => 'तुम्हाला खरोखर बाहेर पडायचे आहे का?';

  @override
  String get cancel => 'रद्द करा';

  @override
  String get posts => 'पोस्ट';

  @override
  String get helped => 'मदत केली';
}

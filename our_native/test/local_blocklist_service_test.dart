import 'package:flutter_test/flutter_test.dart';
import 'package:our_native/services/local_blocklist_service.dart';

void main() {
  final svc = LocalBlocklistService.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // normalizeText
  // ─────────────────────────────────────────────────────────────────────────
  group('normalizeText', () {
    test('lowercases text', () {
      expect(svc.normalizeText('Hello World'), 'hello world');
    });

    test('converts leet chars', () {
      expect(svc.normalizeText('m@d@rch0d'), 'madarchod');
      expect(svc.normalizeText('ch00t'), 'choot');
      expect(svc.normalizeText('l@nd'), 'land');
      expect(svc.normalizeText('g@nd'), 'gand');
    });

    test('collapses 3+ repeated ASCII letters to 2', () {
      expect(svc.normalizeText('gaaaaaand'), 'gaand');  // 6 a's → 2
      expect(svc.normalizeText('chooood'), 'chood');    // 4 o's → 2
      expect(svc.normalizeText('beeehenchod'), 'beehenchod'); // 3 e's → 2
    });

    test('replaces hyphens and symbols with spaces', () {
      final result = svc.normalizeText('c-h-o-d');
      // hyphens become spaces → "c h o d"
      expect(result.contains('c'), isTrue);
      expect(result.contains('h'), isTrue);
    });

    test('strips asterisks', () {
      expect(svc.normalizeText('b*h*o*s*d*i'), contains('bhosdi'));
    });

    test('preserves Devanagari code points', () {
      const devanagari = 'नमस्कार';
      expect(svc.normalizeText(devanagari), devanagari);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // compactNormalizeText
  // ─────────────────────────────────────────────────────────────────────────
  group('compactNormalizeText', () {
    test('removes spaces and joins letters', () {
      expect(svc.compactNormalizeText('b h o s d i'), 'bhosdi');
      expect(svc.compactNormalizeText('m a d a r c h o d'), 'madarchod');
    });

    test('applies leet substitution', () {
      expect(svc.compactNormalizeText('m@darch0d'), 'madarchod');
      expect(svc.compactNormalizeText('bh0sd1k3'), 'bhosdike');
    });

    test('collapses repeated chars (2+ → 1 for evasion detection)', () {
      // compactNormalizeText is more aggressive than normalizeText:
      // ANY repeated run collapses to 1, not just 3+.
      expect(svc.compactNormalizeText('gaaaaand'), 'gand'); // all a's → 1
      expect(svc.compactNormalizeText('gaand'), 'gand');    // aa → a
    });

    test('removes digits after leet substitution', () {
      // '5' has no leet mapping and is a digit → stripped
      expect(svc.compactNormalizeText('ch5od'), 'chod');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Safe / clean text — must NOT be blocked
  // ─────────────────────────────────────────────────────────────────────────
  group('safe text — should NOT be blocked', () {
    final safeSentences = [
      // Clean Marathi
      'नमस्कार मंडळी',
      'आपण उद्या भेटूया',
      'आज हवामान चांगले आहे',
      'गावाकडील जत्रा सुरू आहे',
      'माझ्या आईने जेवण बनवले',  // contains आई but not abusive phrase
      // Clean Hindi
      'नमस्ते दोस्त',
      'आज मौसम अच्छा है',
      'हम कल मिलेंगे',
      // Clean English
      'Hello everyone, how are you?',
      'The event starts at 5 pm.',
      // Words that contain risky substrings but are innocent
      'abc',              // contains 'bc' but not as standalone word
      'mcgregor',         // starts with 'mc' but is a name
      'cubicle',          // contains 'bc'
      'scatter',          // contains 'at'
      'background check', // 'bc' is not a separate token here
      'landmark',         // contains 'land' (leet for 'l@nd' → land)
      'chandelier',       // contains 'and'
      // Normal usage of mild words
      'saala yaar kya baat hai', // friendly/informal usage — should ideally pass
                                  // (saala removed from flat blocklist)
    ];

    for (final text in safeSentences) {
      test('"$text"', () {
        expect(svc.isBlocked(text), isFalse,
            reason: '"$text" should be clean');
      });
    }
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Devanagari abuse — must be blocked
  // ─────────────────────────────────────────────────────────────────────────
  group('Devanagari abuse — should be blocked', () {
    final abusiveDevanagari = [
      'मादरचोद साला',
      'भोसडी बंद कर',
      'गांडू आहेस तू',
      'रांड कुठली',
      'हरामी कुठे आहेस',
      'तू भडवा आहेस',
      'लंड आहे तुझा',
      'चूत दाखव',
      'झवा तुला',
      'वेश्या सारखी वागतेस',
      'हिजडा कुठला',
    ];

    for (final text in abusiveDevanagari) {
      test('"$text"', () {
        expect(svc.isBlocked(text), isTrue,
            reason: '"$text" should be blocked');
      });
    }
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Romanised / Latin abuse — must be blocked
  // ─────────────────────────────────────────────────────────────────────────
  group('Romanised abuse — should be blocked', () {
    final abusiveLatin = [
      'madarchod sala',
      'bhenchod teri maa',
      'bhosdi band kar',
      'chutiya hai tu',
      'gaand maar apni',
      'lund hai tera',
      'randi jaise',
      'harami kahin ka',
      'bhadwa hai tu',
      'lavda dikhata hai',
      'zavadlela aahes',
      'hijra nikal yahan se',
    ];

    for (final text in abusiveLatin) {
      test('"$text"', () {
        expect(svc.isBlocked(text), isTrue,
            reason: '"$text" should be blocked');
      });
    }
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Leet-speak / evasion — must be blocked after normalization
  // ─────────────────────────────────────────────────────────────────────────
  group('Leetspeak/evasion — should be blocked', () {
    test('m@darch0d', () => expect(svc.isBlocked('m@darch0d'), isTrue));
    test('bh0sd1k3', () => expect(svc.isBlocked('bh0sd1k3'), isTrue));
    test('ch00tiya', () => expect(svc.isBlocked('ch00tiya'), isTrue));
    test('g@nd', () => expect(svc.isBlocked('tu g@nd hai'), isTrue));
    test('l@vda', () => expect(svc.isBlocked('l@vda dikhata'), isTrue));
    test('jh@@vla — @@ becomes aa, compact collapses to jhavla',
        () => expect(svc.isBlocked('jh@@vla'), isTrue));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Space-separated / symbol-separated evasion — must be blocked
  // ─────────────────────────────────────────────────────────────────────────
  group('Space/symbol-separated evasion — should be blocked', () {
    test('b h o s d i',
        () => expect(svc.isBlocked('b h o s d i'), isTrue));
    test('m a d a r c h o d',
        () => expect(svc.isBlocked('m a d a r c h o d'), isTrue));
    test('b*h*o*s*d*i',
        () => expect(svc.isBlocked('b*h*o*s*d*i'), isTrue));
    test('c-h-o-d',
        () => expect(svc.isBlocked('yaar c-h-o-d hi hai tu'), isTrue));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Repeated-character evasion — must be blocked
  // ─────────────────────────────────────────────────────────────────────────
  group('Repeated-char evasion — should be blocked', () {
    test('gaaaand', () => expect(svc.isBlocked('gaaaand'), isTrue));
    test('behennnchod', () => expect(svc.isBlocked('behennnchod'), isTrue));
    test('chhoootiya — double-h + triple-o evasion of chutiya',
        () => expect(svc.isBlocked('chhoootiya'), isTrue));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // bc / mc — must block standalone but NOT inside normal words
  // ─────────────────────────────────────────────────────────────────────────
  group('bc/mc short-term boundary matching', () {
    test('standalone "bc" is blocked', () {
      expect(svc.isBlocked('bc'), isTrue);
      expect(svc.isBlocked('abe bc chal'), isTrue);
    });

    test('"bc" inside a word is NOT blocked', () {
      expect(svc.isBlocked('abc'), isFalse);
      expect(svc.isBlocked('cubicle is nice'), isFalse);
    });

    test('standalone "mc" is blocked', () {
      expect(svc.isBlocked('mc sala'), isTrue);
    });

    test('"mc" as part of a name is NOT blocked', () {
      expect(svc.isBlocked('mcgregor won the fight'), isFalse);
    });

    test('"mc bc" phrase is blocked', () {
      expect(svc.isBlocked('mc bc nikal'), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // findViolation returns the matched term
  // ─────────────────────────────────────────────────────────────────────────
  group('findViolation return value', () {
    test('returns null for clean text', () {
      expect(svc.findViolation('Hello world'), isNull);
    });

    test('returns matched term for blocked text', () {
      final result = svc.findViolation('you are a madarchod');
      expect(result, isNotNull);
      expect(result, isA<String>());
    });

    test('returns matched Devanagari term', () {
      final result = svc.findViolation('हरामी आहेस');
      expect(result, isNotNull);
    });
  });
}

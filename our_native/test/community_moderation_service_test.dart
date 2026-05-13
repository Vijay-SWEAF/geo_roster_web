import 'package:flutter_test/flutter_test.dart';
import 'package:our_native/services/community_moderation_service.dart';

void main() {
  final svc = CommunityModerationService.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // normalizeText
  // ─────────────────────────────────────────────────────────────────────────
  group('normalizeText', () {
    test('lowercases text', () {
      expect(svc.normalizeText('Hello World'), 'hello world');
    });

    test('applies leet substitutions', () {
      expect(svc.normalizeText('h1ndu'), 'hindu');
      expect(svc.normalizeText('j1h@d1'), 'jihadi');
      expect(svc.normalizeText('ch@@mar'), 'chaamar');
    });

    test('collapses 3+ repeated chars to 2', () {
      expect(svc.normalizeText('jihaadi'), 'jihaadi'); // 2 a's → unchanged
      expect(svc.normalizeText('jihaaadi'), 'jihaadi'); // 3 a's → 2
    });

    test('preserves Devanagari', () {
      const text = 'नमस्कार मंडळी';
      expect(svc.normalizeText(text), text);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // compactNormalizeText
  // ─────────────────────────────────────────────────────────────────────────
  group('compactNormalizeText', () {
    test('removes spaces to catch spaced evasion', () {
      expect(svc.compactNormalizeText('j i h a d i'), 'jihadi');
      expect(svc.compactNormalizeText('c h a m a r'), 'chamar');
      expect(svc.compactNormalizeText('b j p'), 'bjp');
    });

    test('applies leet before stripping', () {
      expect(svc.compactNormalizeText('ch@@mar'), 'chamar');
      expect(svc.compactNormalizeText('h1ndu'), 'hindu');
    });

    test('collapses any repeated chars to 1', () {
      expect(svc.compactNormalizeText('jihaadi'), 'jihadi');
      expect(svc.compactNormalizeText('chaaamar'), 'chamar');
    });

    test('removes * (m*slim → mslim)', () {
      expect(svc.compactNormalizeText('m*slim'), 'mslim');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // ModerationSeverity scoring
  // ─────────────────────────────────────────────────────────────────────────
  group('severity thresholds', () {
    ModerationSeverity s(int score) =>
        CommunityModerationService.severityFromScore(score);

    test('0 → safe', () => expect(s(0), ModerationSeverity.safe));
    test('1 → lowRisk', () => expect(s(1), ModerationSeverity.lowRisk));
    test('3 → lowRisk', () => expect(s(3), ModerationSeverity.lowRisk));
    test('4 → mediumRisk', () => expect(s(4), ModerationSeverity.mediumRisk));
    test('6 → mediumRisk', () => expect(s(6), ModerationSeverity.mediumRisk));
    test('7 → highRisk', () => expect(s(7), ModerationSeverity.highRisk));
    test('9 → highRisk', () => expect(s(9), ModerationSeverity.highRisk));
    test('10 → blocked', () => expect(s(10), ModerationSeverity.blocked));
    test('25 → blocked', () => expect(s(25), ModerationSeverity.blocked));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Safe text — must NOT be flagged
  // ─────────────────────────────────────────────────────────────────────────
  group('safe text — must NOT be flagged', () {
    final safeCases = {
      // Devotional / festival greetings
      'राम नवमीच्या शुभेच्छा': 'Marathi Ram Navami greeting',
      'Eid Mubarak to everyone': 'Eid greeting',
      'Happy Diwali to all': 'Diwali greeting',
      'Christmas wishes to all': 'Christmas greeting',
      // Neutral civic/cultural
      'आज मतदान सुट्टी आहे': 'Marathi voting holiday notice',
      'मराठा इतिहास वाचत होतो': 'Marathi reading history',
      'भारतीय संविधान महत्त्वाचे आहे': 'Indian constitution mention',
      'आज हवामान चांगले आहे': 'Clean Marathi sentence',
      'नमस्ते दोस्त, कसे आहात': 'Clean Hindi greeting',
      'The village temple renovation is complete': 'Temple neutral mention',
      // Normal English
      'Hello everyone, hope you are doing well': 'Plain English',
      'The event starts at 5 pm today': 'Event notice',
      // Words containing risky substrings but innocent
      'framework is easy to learn': 'contains ram as substring',
      'the program was excellent': 'contains ram as substring',
      'mcgregor is a popular name': 'starts with mc',
      'commodity prices are rising': 'contains bc substring',
    };

    for (final entry in safeCases.entries) {
      test('${entry.value}: "${entry.key}"', () {
        final result = svc.evaluate(entry.key);
        expect(
          result.isFlagged,
          isFalse,
          reason: '"${entry.key}" should be safe (score=${result.score}, '
              'severity=${result.severity})',
        );
      });
    }
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Communal hate — must be flagged
  // ─────────────────────────────────────────────────────────────────────────
  group('communal hate — must be flagged', () {
    test('kill hindus → blocked (score ≥ 10)', () {
      final r = svc.evaluate('we should kill hindus');
      expect(r.severity, ModerationSeverity.blocked);
    });

    test('kill muslims → blocked', () {
      final r = svc.evaluate('we should kill muslims');
      expect(r.severity, ModerationSeverity.blocked);
    });

    test('remove muslims → blocked', () {
      final r = svc.evaluate('remove muslims from this area');
      expect(r.severity, ModerationSeverity.blocked);
    });

    test('love jihad → mediumRisk or higher', () {
      final r = svc.evaluate('love jihad is happening everywhere');
      expect(r.score, greaterThanOrEqualTo(4));
    });

    test('jihadi → mediumRisk or higher', () {
      final r = svc.evaluate('that man is a jihadi');
      expect(r.score, greaterThanOrEqualTo(4));
    });

    test('anti hindu → mediumRisk or higher', () {
      final r = svc.evaluate('this is anti hindu propaganda');
      expect(r.score, greaterThanOrEqualTo(4));
    });

    test('terrorist religion → blocked', () {
      final r = svc.evaluate('that is a terrorist religion');
      expect(r.severity, ModerationSeverity.blocked);
    });

    test('Devanagari धर्मयुद्ध → mediumRisk or higher', () {
      final r = svc.evaluate('हे धर्मयुद्ध आहे');
      expect(r.score, greaterThanOrEqualTo(4));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Caste hate — must be flagged
  // ─────────────────────────────────────────────────────────────────────────
  group('caste hate — must be flagged', () {
    test('chamar → highRisk (score ≥ 7)', () {
      final r = svc.evaluate('you are a chamar');
      expect(r.score, greaterThanOrEqualTo(7));
    });

    test('bhangi → highRisk', () {
      final r = svc.evaluate('stop behaving like a bhangi');
      expect(r.score, greaterThanOrEqualTo(7));
    });

    test('dalit dogs → blocked', () {
      final r = svc.evaluate('dalit dogs should leave');
      expect(r.severity, ModerationSeverity.blocked);
    });

    test('brahmin dogs → blocked', () {
      final r = svc.evaluate('brahmin dogs control everything');
      expect(r.severity, ModerationSeverity.blocked);
    });

    test('जातिवादी (Devanagari) → highRisk', () {
      final r = svc.evaluate('हे जातिवादी लोक आहेत');
      expect(r.score, greaterThanOrEqualTo(7));
    });

    test('reservation parasite → mediumRisk', () {
      final r = svc.evaluate('these reservation parasites take all jobs');
      expect(r.score, greaterThanOrEqualTo(4));
    });

    test('upper caste supremacy → mediumRisk', () {
      final r = svc.evaluate('upper caste supremacy must end discussion');
      expect(r.score, greaterThanOrEqualTo(4));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Political propaganda — must be flagged
  // ─────────────────────────────────────────────────────────────────────────
  group('political propaganda — must be flagged', () {
    test('vote for bjp → mediumRisk or higher', () {
      final r = svc.evaluate('vote for bjp in next election');
      expect(r.score, greaterThanOrEqualTo(4));
    });

    test('Marathi propaganda: सर्वांना पाठवा → mediumRisk or higher', () {
      final r = svc.evaluate('हा मेसेज सर्वांना पाठवा');
      expect(r.score, greaterThanOrEqualTo(4));
    });

    test('andhbhakt + deshdrohi → mediumRisk (2 baiting terms = +6)', () {
      final r = svc.evaluate('all andhbhakt deshdrohi should leave');
      expect(r.score, greaterThanOrEqualTo(4)); // mediumRisk
    });

    test('it cell + godi media → mediumRisk (2 baiting terms = +6)', () {
      final r = svc.evaluate('it cell and godi media are destroying this country');
      expect(r.score, greaterThanOrEqualTo(4)); // mediumRisk
    });

    test('tukde tukde → mediumRisk (scored +4)', () {
      final r = svc.evaluate('tukde tukde gang is behind this');
      expect(r.score, greaterThanOrEqualTo(4)); // mediumRisk
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Neutral political mentions — low or safe
  // ─────────────────────────────────────────────────────────────────────────
  group('neutral political mentions — lowRisk or safe', () {
    test('single party name stays lowRisk or safe', () {
      final r = svc.evaluate('BJP won the recent election');
      expect(r.severity, anyOf(ModerationSeverity.safe, ModerationSeverity.lowRisk));
    });

    test('single leader name stays lowRisk or safe', () {
      final r = svc.evaluate('Modi inaugurated the highway today');
      expect(r.severity, anyOf(ModerationSeverity.safe, ModerationSeverity.lowRisk));
    });

    test('neutral comparison of two parties stays lowRisk or safe', () {
      final r = svc.evaluate('BJP and Congress have different views on this');
      expect(r.severity, anyOf(ModerationSeverity.safe, ModerationSeverity.lowRisk));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Leet-speak / evasion — must be flagged
  // ─────────────────────────────────────────────────────────────────────────
  group('leetspeak/evasion — must be flagged', () {
    test('h1ndu k1ll (leet) → flagged', () {
      // Combines h1ndu→hindu with kill hindus phrase variant
      final r = svc.evaluate('we must k1ll h1ndus');
      expect(r.isFlagged, isTrue);
    });

    test('ch@@mar (leet caste slur) → flagged', () {
      final r = svc.evaluate('ch@@mar log hain ye');
      expect(r.score, greaterThanOrEqualTo(7));
    });

    test('j i h a d i (spaced) → flagged via compact', () {
      final r = svc.evaluate('he is a j i h a d i');
      expect(r.score, greaterThanOrEqualTo(4));
    });

    test('b j p (spaced) → scored via compact', () {
      final r = svc.evaluate('vote for b j p');
      // "vote for" (+5) + spaced bjp compact match
      expect(r.score, greaterThanOrEqualTo(5));
    });

    test('m*slim evasion → flagged via compact (mslim)', () {
      final r = svc.evaluate('remove all m*slims');
      // "remove" + mslim compact → should be caught
      expect(r.score, greaterThanOrEqualTo(4));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Repeated-character evasion — must be flagged
  // ─────────────────────────────────────────────────────────────────────────
  group('repeated-char evasion — must be flagged', () {
    test('jihaaadi → flagged (collapses to jihadi)', () {
      final r = svc.evaluate('he is a jihaaadi');
      expect(r.score, greaterThanOrEqualTo(4));
    });

    test('chhaamar → flagged (collapses to chamar)', () {
      final r = svc.evaluate('chhaamar log hain ye');
      expect(r.score, greaterThanOrEqualTo(7));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // False positive protection
  // ─────────────────────────────────────────────────────────────────────────
  group('false positive protection', () {
    test('"Ram Navami" does not flag (Ram is not scored)', () {
      final r = svc.evaluate('Ram Navami celebration in our village');
      expect(r.isFlagged, isFalse);
    });

    test('"Eid Mubarak" does not flag', () {
      final r = svc.evaluate('Eid Mubarak to all our Muslim brothers and sisters');
      expect(r.isFlagged, isFalse);
    });

    test('"mandir renovation" is safe', () {
      final r = svc.evaluate('Our village mandir renovation is complete');
      expect(r.isFlagged, isFalse);
    });

    test('"temple and mosque" neutral mention is safe', () {
      final r = svc.evaluate('Both temple and mosque are places of peace');
      expect(r.isFlagged, isFalse);
    });

    test('caste history discussion stays safe', () {
      final r =
          svc.evaluate('We are reading about caste history in India today');
      expect(r.isFlagged, isFalse);
    });

    test('"mast" does not trigger via compact mslim check', () {
      // "mast" compact → "mast" — should NOT match "mslim"
      final r = svc.evaluate('mast din tha aaj');
      expect(r.isFlagged, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // findViolation return values
  // ─────────────────────────────────────────────────────────────────────────
  group('CommunityModerationResult fields', () {
    test('safe text returns score 0, severity safe', () {
      final r = svc.evaluate('नमस्कार मंडळी');
      expect(r.score, 0);
      expect(r.severity, ModerationSeverity.safe);
      expect(r.primaryReason, isNull);
      expect(r.triggeredTerms, isEmpty);
    });

    test('flagged text returns non-null primaryReason', () {
      final r = svc.evaluate('kill hindus');
      expect(r.primaryReason, isNotNull);
      expect(r.triggeredTerms, isNotEmpty);
    });

    test('isFlagged is true for highRisk', () {
      final r = svc.evaluate('chamar log hain sab');
      expect(r.isFlagged, isTrue);
    });

    test('isFlagged is false for lowRisk', () {
      final r = svc.evaluate('BJP won the election');
      expect(r.isFlagged, isFalse);
    });
  });
}

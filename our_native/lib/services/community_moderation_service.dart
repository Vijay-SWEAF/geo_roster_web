// ignore_for_file: dangling_library_doc_comments
// Community harmony moderation service — see class doc below.

// ─────────────────────────────────────────────────────────────────────────────
// Severity enum
// ─────────────────────────────────────────────────────────────────────────────

enum ModerationSeverity {
  safe,        // 0
  lowRisk,     // 1–3
  mediumRisk,  // 4–6
  highRisk,    // 7–9
  blocked,     // 10+
}

extension ModerationSeverityX on ModerationSeverity {
  bool get shouldBlock =>
      this == ModerationSeverity.mediumRisk ||
      this == ModerationSeverity.highRisk ||
      this == ModerationSeverity.blocked;
}

// (top-level alias removed — use CommunityModerationService.severityFromScore)

// ─────────────────────────────────────────────────────────────────────────────
// Result type
// ─────────────────────────────────────────────────────────────────────────────

class CommunityModerationResult {
  final int score;
  final ModerationSeverity severity;

  /// Human-readable reason to show in UI or admin logs.
  final String? primaryReason;

  /// All terms that contributed to the score (for admin audit).
  final List<String> triggeredTerms;

  const CommunityModerationResult({
    required this.score,
    required this.severity,
    this.primaryReason,
    this.triggeredTerms = const [],
  });

  bool get isFlagged => severity.shouldBlock;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class CommunityModerationService {
  CommunityModerationService._();
  static final CommunityModerationService instance =
      CommunityModerationService._();

  // ───────────────────────────────────────────────────────────────────────────
  // Dataset: Political  (+score per term)
  // ───────────────────────────────────────────────────────────────────────────

  /// Political party names. Scored at +1 each (mere mention, not inherently
  /// harmful). Total contribution from this set is capped at 3 to avoid
  /// over-penalising neutral comparative discussion.
  static const _partyNames = <String>{
    'bjp', 'congress', 'inc', 'shivsena', 'shiv sena', 'ncp', 'aap', 'aimim',
    'cpi', 'cpm', 'manse', 'nda', 'mva', 'mahayuti', 'india alliance',
    // Devanagari party names
    'भाजप', 'शिवसेना', 'काँग्रेस', 'राष्ट्रवादी', 'आप', 'मनसे', 'महायुती',
    'महाविकास', 'भाजपा',
  };

  /// Political leader names. Same cap as party names.
  static const _leaderNames = <String>{
    'modi', 'narendra modi', 'rahul gandhi', 'sonia gandhi', 'amit shah',
    'uddhav thackeray', 'raj thackeray', 'eknath shinde', 'ajit pawar',
    'sharad pawar', 'arvind kejriwal', 'yogi',
  };

  /// Divisive political insults/slang. +3 each.
  /// Note: 'bhakt' literally means devotee and is common in devotional text;
  /// it scores +2 here instead of +3 to reduce false positives.
  static const _baitingTerms = <String>{
    'andhbhakt',     // blind follower (political insult)
    'libtard',
    'sickular',
    'presstitute',
    'pappu',
    'godi media',
    'urban naxal',
    'tukde tukde',   // scored at +4 (charged accusation, see evaluate())
    'anti national',
    'deshdrohi',
    'it cell',
    'whatsapp university',
    'paid media',
    'vote bank politics',
    'bhakt',         // context-sensitive; scored at +2 in evaluate()
  };

  /// Explicit propaganda phrases intended to spread/campaign. +5 each.
  static const _propagandaPhrases = <String>{
    'vote for',
    'vote do',
    'join party',
    'join campaign',
    'share to all groups',
    'viral kara',
    // Marathi
    'सर्वांना पाठवा',
    'प्रचार करा',
    'मत द्या',
    'हा मेसेज पसरवा',
  };

  // ───────────────────────────────────────────────────────────────────────────
  // Dataset: Religion / Communal
  // ───────────────────────────────────────────────────────────────────────────

  /// Religion keywords — stored for future amplification logic.
  /// A message containing both a religion keyword AND a baiting term could
  /// score higher in a future version. Currently scored at +0 to avoid
  /// blocking devotional/festival content. Kept here for reference.
  // ignore: unused_field
  static const _religionKeywords = <String>{
    'hindu', 'muslim', 'islam', 'christian', 'sikh', 'jain', 'buddhist',
    'mandir', 'masjid', 'church', 'temple', 'mosque', 'allah', 'jesus',
    'shivaji maharaj',
    // 'ram' intentionally omitted — too many false positives in normal words
    // like "framework", "program", "random".
  };

  /// Communal baiting terms (religion used as weapon). +6 each.
  static const _communalBaitingTerms = <String>{
    'anti hindu', 'anti muslim', 'anti christian',
    'kattar hindu', 'kattar muslim',
    'religious war',
    'convert them',
    'love jihad',
    'fake secular',
    'jihadi',
    'terror religion',
    'mandir vs masjid',
    // Devanagari
    'धर्मयुद्ध',
    'कट्टर',
    'देशद्रोही धर्म',
    'समुदाय विरोध',
  };

  /// Violent communal threats. Each triggers +10 → instant block.
  static const _communalHighRiskPhrases = <String>{
    'remove muslims',
    'remove hindus',
    'remove christians',
    'kill muslims',
    'kill hindus',
    'kill christians',
    'boycott muslims',
    'boycott hindus',
    'this religion is superior',
    'that religion is dirty',
    'terrorist religion',
    'all muslims are',
    'all hindus are',
    'all christians are',
  };

  // ───────────────────────────────────────────────────────────────────────────
  // Dataset: Caste / Community
  // ───────────────────────────────────────────────────────────────────────────

  /// Direct caste slurs. +8 each.
  /// These are unambiguous slurs with no legitimate neutral usage.
  static const _casteSlurs = <String>{
    'chamar', 'bhangi', 'mahar', 'dhed',
    // Devanagari
    'अस्पृश्य',
    'नीच जात',
    'घटिया जात',
    'जातिवादी',
    'जातिवाद',
  };

  /// Caste-baiting terms that could appear educationally but are often used
  /// disparagingly. +4 each. Context-sensitive; scored conservatively.
  static const _casteBaitingTerms = <String>{
    'achhut',              // untouchable — historical but often used as slur
    'untouchable',
    'upper caste supremacy',
    'reservation parasite',
    'quota people',
    'lower caste people',  // pejorative framing
    // Devanagari
    'दलित hate',
    'ओबीसी hate',
    'मराठा hate',
  };

  /// Violent caste hate phrases. +10 each → instant block.
  static const _casteHighRiskPhrases = <String>{
    'this caste is dirty',
    'remove this caste',
    'brahmin dogs',
    'dalit dogs',
    'maratha dogs',
    'caste parasites',
    // Devanagari
    'जात संपवा',
    'जातीय द्वेष',
  };

  // ───────────────────────────────────────────────────────────────────────────
  // Dataset: Evasion patterns (checked against compact-normalized text)
  // These are canonical forms that evasion variants collapse into:
  //   "ch@@mar" → compactNormalize → "chamar"
  //   "j i h a d i" → compactNormalize → "jihadi"
  //   "b j p" → compactNormalize → "bjp" (only scored in evasion context)
  // ───────────────────────────────────────────────────────────────────────────

  // ignore: unused_field  — kept as readable documentation of what compact forms are checked
  static const _evasionTerms = <String>{
    // Caste slurs (caught even when evaded via spaces/leet)
    'chamar', 'bhangi', 'mahar', 'dhed',
    // Communal baiting
    'jihadi', 'lovejihad', 'kattarhindu', 'kattarmuslim',
    // Political abuse
    'andhbhakt', 'deshdrohi',
    // "m*slim" with * removed → "mslim"
    'mslim',
  };

  /// Score to award per evasion term category when matched in compact form.
  /// Keys are the raw (non-compact) evasion terms as declared in [_evasionTerms].
  static const _evasionScoreMap = <String, int>{
    'chamar': 8, 'bhangi': 8, 'mahar': 8, 'dhed': 8,     // caste slurs
    'jihadi': 6, 'lovejihad': 6,                           // communal baiting
    'kattarhindu': 6, 'kattarmuslim': 6, 'mslim': 6,      // communal baiting
    'andhbhakt': 3, 'deshdrohi': 3,                        // political abuse
  };

  /// Precomputed map of compact-normalized term → score.
  static final Map<String, int> _compactEvasionScores = Map.unmodifiable({
    for (final entry in _evasionScoreMap.entries)
      _compactNormalize(entry.key): entry.value,
  });

  // Helper used only during static field initialization.
  static String _compactNormalize(String text) {
    var s = text.toLowerCase()
        .replaceAll('@', 'a')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('*', '');
    s = s.replaceAll(RegExp(r'[^a-z\u0900-\u097F]'), '');
    return s.replaceAllMapped(RegExp(r'([a-z])\1+'), (m) => m[1]!);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Regex boundary cache
  // ───────────────────────────────────────────────────────────────────────────

  static final Map<String, RegExp> _boundaryCache = {};

  static RegExp _wb(String term) => _boundaryCache.putIfAbsent(
        term,
        () => RegExp(
          r'(?<![a-z0-9\u0900-\u097F])' +
              RegExp.escape(term) +
              r'(?![a-z0-9\u0900-\u097F])',
          caseSensitive: false,
        ),
      );

  // ───────────────────────────────────────────────────────────────────────────
  // Text normalization
  // ───────────────────────────────────────────────────────────────────────────

  /// Full normalization for primary matching.
  /// - Lowercase
  /// - Leet substitution (@ → a, 0 → o, 1 → i, 3 → e, 4 → a, $ → s)
  /// - Symbols/punctuation → space (hyphen, dot, underscore used as separators)
  /// - Collapse 3+ repeated ASCII letters to 2 ("gaaaaand" → "gaand")
  /// - Preserves Devanagari (U+0900–U+097F)
  String normalizeText(String text) {
    var s = text.toLowerCase();
    s = s
        .replaceAll('@', 'a')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('*', '');
    // Replace non-word, non-Devanagari chars with space
    s = s.replaceAll(RegExp(r'[^\w\s\u0900-\u097F]'), ' ');
    // Collapse 3+ repeated ASCII letters to 2
    s = s.replaceAllMapped(
      RegExp(r'([a-z])\1{2,}'),
      (m) => '${m[1]}${m[1]}',
    );
    return s.trim();
  }

  /// Compact normalization for evasion detection.
  /// Removes ALL whitespace and symbols, applies leet, collapses any
  /// repeated chars to 1: "j i h a d i" → "jihadi", "ch@@mar" → "chamar".
  String compactNormalizeText(String text) {
    var s = text.toLowerCase();
    s = s
        .replaceAll('@', 'a')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('*', '');
    s = s.replaceAll(RegExp(r'[^a-z\u0900-\u097F]'), '');
    // Collapse any repeated ASCII letters to 1 (more aggressive than normalizeText)
    s = s.replaceAllMapped(RegExp(r'([a-z])\1+'), (m) => m[1]!);
    return s;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Scoring engine
  // ───────────────────────────────────────────────────────────────────────────

  /// Evaluate [text] and return a [CommunityModerationResult] with a score,
  /// severity, and the terms that triggered the score.
  CommunityModerationResult evaluate(String text) {
    if (text.trim().isEmpty) {
      return const CommunityModerationResult(
          score: 0, severity: ModerationSeverity.safe);
    }

    final norm = normalizeText(text);
    final compact = compactNormalizeText(text);

    int score = 0;
    final triggered = <String>[];
    String? primaryReason;

    void addScore(int points, String term, String reason) {
      score += points;
      triggered.add(term);
      primaryReason ??= reason;
    }

    // ── Step 1: High-risk phrases (+10 each → instant block) ──────────────
    // Check these first so we can short-circuit early.
    for (final phrase in _communalHighRiskPhrases) {
      if (norm.contains(normalizeText(phrase))) {
        addScore(10, phrase,
            'Content promotes communal hatred or religious violence.');
      }
    }
    for (final phrase in _casteHighRiskPhrases) {
      if (norm.contains(normalizeText(phrase))) {
        addScore(10, phrase, 'Content contains caste-based hate speech.');
      }
    }

    if (score >= 10) {
      // No need to continue — already blocked.
      return CommunityModerationResult(
        score: score,
        severity: ModerationSeverity.blocked,
        primaryReason: primaryReason,
        triggeredTerms: List.unmodifiable(triggered),
      );
    }

    // ── Step 2: Propaganda phrases (+5 each) ──────────────────────────────
    for (final phrase in _propagandaPhrases) {
      if (norm.contains(normalizeText(phrase))) {
        addScore(5, phrase,
            'Content appears to contain political propaganda or campaigning.');
      }
    }

    // ── Step 3: Communal baiting (+6 each) ────────────────────────────────
    for (final term in _communalBaitingTerms) {
      if (_wb(term).hasMatch(norm)) {
        addScore(
            6, term, 'Content may promote religious division or communal hate.');
      }
    }

    // ── Step 4: Caste slurs (+8 each) ─────────────────────────────────────
    for (final slur in _casteSlurs) {
      if (_wb(slur).hasMatch(norm)) {
        addScore(8, slur, 'Content contains caste-based slurs.');
      }
    }

    // ── Step 5: Caste baiting (+4 each) ───────────────────────────────────
    for (final term in _casteBaitingTerms) {
      if (norm.contains(normalizeText(term))) {
        addScore(
            4, term, 'Content may promote caste-based discrimination.');
      }
    }

    // ── Step 6: Political baiting (+3 per term, with special cases) ────────────
    for (final term in _baitingTerms) {
      if (_wb(term).hasMatch(norm)) {
        // 'bhakt' is a common devotional word — score lower to reduce false hits.
        // 'tukde tukde' is an accusatory political phrase — score +4 (mediumRisk).
        final pts = switch (term) {
          'bhakt' => 2,
          'tukde tukde' => 4,
          _ => 3,
        };
        addScore(pts, term, 'Content contains divisive political language.');
      }
    }

    // ── Step 7: Party / leader names (+4 each, no cap) ──────────────────
    // For a village community app, ANY political party/leader mention in a
    // post title or body is treated as political content and blocked.
    // Score +4 per name so a single mention reaches mediumRisk (≥4) → blocked.
    for (final name in {..._partyNames, ..._leaderNames}) {
      if (_wb(name).hasMatch(norm)) {
        addScore(4, name, 'Post contains political party or leader references, which are not allowed in community posts.');
      }
    }

    // ── Step 8: Evasion detection (compact normalized matching) ───────────
    // Catches "ch@@mar", "j i h a d i", "m*slim", "b j p" etc.
    // [_compactEvasionScores] maps compact-form → score so each term gets its
    // correct category score (caste=+8, communal=+6, political=+3).
    for (final entry in _compactEvasionScores.entries) {
      final compactTerm = entry.key;
      final evasionScore = entry.value;
      if (compact.contains(compactTerm) && !triggered.contains(compactTerm)) {
        final reason = evasionScore >= 8
            ? 'Content contains disguised caste slurs.'
            : evasionScore >= 6
                ? 'Content contains disguised communal baiting language.'
                : 'Content contains disguised divisive political language.';
        addScore(evasionScore, '$compactTerm (evasion)', reason);
      }
    }

    return CommunityModerationResult(
      score: score,
      severity: CommunityModerationService.severityFromScore(score),
      primaryReason: primaryReason,
      triggeredTerms: List.unmodifiable(triggered),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Convenience API
  // ───────────────────────────────────────────────────────────────────────────

  /// Maps a numeric score to its [ModerationSeverity] bucket.
  /// Exposed as public static so tests and admin tooling can verify thresholds.
  static ModerationSeverity severityFromScore(int score) {
    if (score <= 0) return ModerationSeverity.safe;
    if (score <= 3) return ModerationSeverity.lowRisk;
    if (score <= 6) return ModerationSeverity.mediumRisk;
    if (score <= 9) return ModerationSeverity.highRisk;
    return ModerationSeverity.blocked;
  }

  /// Returns true if [text] should be hard-blocked (highRisk or blocked).
  bool isHarmful(String text) => evaluate(text).isFlagged;
}

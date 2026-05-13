import 'dart:core';

/// Client-side keyword blocklist for Marathi and Hindi abusive language.
///
/// Architecture:
///   Layer 1 — Instant client blocklist (this file) — runs offline, zero latency.
///   Layer 2 — OpenAI moderation API via Supabase Edge Function.
///
/// Matching strategy:
///   1. [_devanagariTerms]   — Devanagari script slurs. Matched against normalized
///      text using word-boundary regex where possible.
///   2. [_latinTerms]        — Romanised transliterations. Matched after leet
///      normalization (@ → a, 0 → o, etc.) using word-boundary regex.
///   3. [_phraseTerms]       — Multi-word abusive phrases. Matched against the
///      full normalised string via simple containment (phrases provide context).
///   4. [_highRiskShortTerms]— Very short abbreviations (≤3 chars) that are abusive
///      ONLY when they stand alone as a word. Matched with strict word boundaries so
///      they don't fire inside normal words (e.g. "abc", "mcgregor" stay clean).
///   5. Compact/evasion check — text is also stripped of all spaces/symbols and
///      collapsed for repeated chars, then tested against [_evasionTerms].
///
/// Maintaining this list:
///   - All terms stored lowercase; matching is always case-insensitive.
///   - Avoid raw common words that appear in legitimate sentences.
///   - Use [_phraseTerms] for contextual words that are only abusive in combination.
class LocalBlocklistService {
  LocalBlocklistService._();
  static final LocalBlocklistService instance = LocalBlocklistService._();

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Devanagari terms (Marathi + Hindi)
  // ─────────────────────────────────────────────────────────────────────────
  static const _devanagariTerms = <String>{
    // Mother-related abuse
    'मादरचोद', 'माँचोद', 'माकीचूत', 'माकिचूत', 'आईझव', 'आईला', 'आईची',
    'तुझ्या आईला',
    // Sister-related abuse
    'बहनचोद', 'भेनचोद', 'भेंचोद', 'बहिणीची', 'तुझ्या बहिणीला',
    // Genitalia
    'भोसडी', 'भोसडीच्या', 'भोसडीचा', 'भोसडीकर', 'भोसडा', 'भोसड्या',
    'भोसड', 'भोसडिके', 'भोसडीवाला', 'गांड', 'गांडू', 'गांडफाड',
    'गांडफट', 'गांडमारी', 'गांडमारा', 'गांडीचा', 'चूत', 'चुत', 'चुतड',
    'चूतड़', 'लंड', 'लंडू', 'लौड़ा', 'लौंडा', 'लौड़े', 'लोड़ा', 'लवडा',
    'लवडे', 'लवड्या', 'झाट', 'झांट', 'झाटू', 'बोचा', 'बोचवा',
    // Sex acts
    'झवा', 'झवणे', 'झवाड', 'झवाडलेला', 'झवला', 'झवली', 'झवतो', 'झवते',
    'झव', 'चोद', 'चोदा', 'चोदतो', 'चोदू',
    // Insults
    'भडवा', 'भडवी', 'भडव्या', 'भिकारचोट', 'हरामी', 'हरामखोर',
    'हरामजादा', 'हरामजादी', 'कमिना', 'कमीना', 'कमीनी', 'हलकट',
    'थेरडा', 'थेरडी', 'दलाल', 'लफंगा', 'निकम्मा', 'टपोरी', 'गटरछाप',
    // Sex workers / slurs
    'रांड', 'रांडेचा', 'रांडेच्या', 'रंडी', 'वेश्या', 'छिनाल',
    // Bigoted slurs
    'हिजडा', 'छक्का', 'नपुंसक',
    // Animal insults
    'कुत्र्या', 'कुत्री', 'कुत्ता', 'कुत्ती', 'कुतिया', 'सुअर',
    // Hindi cross-usage
    'बहन के लोडे', 'बहन के लौड़े', 'सुअर की औलाद', 'चुतिया', 'चूतिया',
    'चुतिये', 'मुर्ख', 'बेवकूफ', 'घाणेरडा',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Latin / Romanised terms (matched after leet normalization)
  // ─────────────────────────────────────────────────────────────────────────
  static const _latinTerms = <String>{
    // Mother-related
    'madarchod', 'maadarchod', 'maachod', 'maa ki chut', 'maa ki choot',
    'maa ka bhosda', 'maa ke lode', 'maa ke laude', 'mkc', 'tmkc',
    'aaila', 'aaizav', 'tuzya aila',
    // Sister-related
    'bhenchod', 'behenchod', 'behnchod', 'behen ke lode', 'behen ke laude',
    'bhen ke lode', 'tuzya bahinila',
    // Genitalia
    'bhosdi', 'bhosd', 'bhosdike', 'bhosadike', 'bhosad', 'bhosdika',
    'bhosdikaa', 'bhosdiche', 'bhosdya', 'gaand', 'gandu', 'gaandu',
    'gaandfat', 'gaandfaad', 'gaandmara', 'chut', 'choot', 'lund', 'lodu',
    'loda', 'lauda', 'lavda', 'lawda', 'lawde', 'lavdya', 'lavde',
    'jhaat', 'jhant', 'jhaantu', 'jhat', 'bocha', 'bochi',
    // Explicit sexual content (standalone) — inappropriate as community post titles
    'sex', 'sexy', 'sexting', 'sexii', 'sexi', 'porn', 'pornographic',
    'nude', 'naked', 'xxx', 'boobs', 'boob', 'dick', 'cock', 'pussy',
    'vagina', 'penis', 'anal', 'orgasm', 'masturbate', 'masturbation',
    'horny', 'erotic', 'erection', 'ejaculate', 'seductive', 'slutty',
    'slut', 'whore',
    // Sex acts
    'chod', 'chodu', 'chodto', 'jhavad', 'jhavla', 'jhavli', 'jhavto',
    'jhavte', 'jhavne', 'zavad', 'zavadlela',
    // Insults
    'bhadwa', 'bhadwi', 'bhadve', 'bhadvya', 'harami', 'haramkhor',
    'haramzada', 'haramzaada', 'halkat', 'therda', 'kamina', 'kaminey',
    'kamini', 'dalal', 'chapri', 'tapori', 'lafanga', 'nikamma', 'gatarchap',
    'kutrya', 'kutra', 'kutri', 'kutta', 'kutte', 'kutti', 'kutiya',
    // Sex workers / slurs
    'rand', 'randi', 'randwa', 'veshya', 'chhinal', 'chinal',
    // Bigoted slurs
    'hijda', 'hijra', 'chakka',
    // Common abbreviations — matched as WHOLE WORDS only (see _highRiskShortTerms)
    // 'bc', 'mc' handled separately below
    'bsdk', 'bkl', 'mkb', 'rmd',
    // Chutiya variants
    'chutiya', 'chuutiya', 'chootiya', 'chutiye',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Multi-word phrase terms (abusive only in combination)
  //    These are checked via simple containment on the normalised string
  //    because context makes them unambiguously offensive.
  // ─────────────────────────────────────────────────────────────────────────
  static const _phraseTerms = <String>{
    'maa ki chut', 'maa ki choot', 'maa ka bhosda', 'maa ke lode',
    'maa ke laude', 'behen ke lode', 'behen ke laude', 'bhen ke lode',
    'suvar ki aulad', 'tere baap ka', 'teri maa ki', 'teri behen ki',
    'tuzya aila', 'tuzya bahinila', 'fk bc', 'mc bc',
    'तुझ्या आईला', 'तुझ्या बहिणीला', 'सुअर की औलाद', 'बहन के लोडे',
    'बहन के लौड़े',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // 4. High-risk SHORT terms (≤4 chars)
  //    ONLY blocked when they appear as standalone words (surrounded by
  //    word boundaries), NOT inside longer innocent words.
  //    e.g. "bc" fires on "bc!", "saala bc" but NOT on "abc" or "cubicle".
  // ─────────────────────────────────────────────────────────────────────────
  static const _highRiskShortTerms = <String>{
    'bc',   // bhenchod abbreviation
    'mc',   // madarchod abbreviation
    'gand', // standalone "gand" is unambiguously abusive in context
  };

  // ─────────────────────────────────────────────────────────────────────────
  // 5. Evasion / compact terms
  //    Checked against compactNormalizeText() — all spaces/symbols removed,
  //    leet substituted, repeated chars collapsed.
  // ─────────────────────────────────────────────────────────────────────────
  static const _evasionTerms = <String>{
    'madarchod', 'bhenchod', 'bhosdi', 'bhosdike', 'chutiya', 'chootiya',
    'choot', 'gaand', 'lavda', 'lund', 'jhavad', 'jhavla', 'aaizav',
    'aaila', 'chod', 'bhadwa', 'harami', 'randi', 'haramzada',
  };

  /// Compact-normalized cache of [_evasionTerms], computed once at startup.
  /// All terms are run through [compactNormalizeText] so that matching is
  /// apples-to-apples when comparing against compact-normalized user input.
  static final Set<String> _compactEvasionTerms = _evasionTerms
      .map((t) => LocalBlocklistService.instance.compactNormalizeText(t))
      .toSet();

  // ─────────────────────────────────────────────────────────────────────────
  // Pre-compiled regex cache (built lazily on first use)
  // ─────────────────────────────────────────────────────────────────────────
  static final Map<String, RegExp> _boundaryCache = {};

  static RegExp _wordBoundary(String term) {
    return _boundaryCache.putIfAbsent(
      term,
      // \b works only on ASCII word chars. For terms that may contain non-ASCII
      // we fall back to lookahead/lookbehind for space/start/end.
      () => RegExp(r'(?<![a-z0-9])' + RegExp.escape(term) + r'(?![a-z0-9])',
          caseSensitive: false),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Text normalization
  // ─────────────────────────────────────────────────────────────────────────

  /// Full normalization used for primary matching.
  ///
  /// Steps:
  ///   1. Lowercase.
  ///   2. Leet substitution: @ → a, 0 → o, 1 → i, 3 → e, 4 → a, $ → s.
  ///   3. Remove `*` and other punctuation noise, keep Devanagari (U+0900–U+097F).
  ///   4. Collapse repeated ASCII letters (e.g. "gaaaaand" → "gaand",
  ///      "chhhoood" → "chod"). Devanagari chars are left as-is.
  String normalizeText(String text) {
    var s = text.toLowerCase();

    // Leet substitutions
    s = s
        .replaceAll('@', 'a')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('*', '');

    // Remove characters that are neither Latin letters/digits, spaces, nor
    // Devanagari code points. Hyphens, dots, underscores used as separators
    // (e.g. "c-h-o-d") are replaced with a space so boundary matching still works.
    s = s.replaceAllMapped(
      RegExp(r'[^\w\s\u0900-\u097F]'),
      (m) => ' ',
    );

    // Collapse runs of 3+ identical ASCII letters down to 2 to handle
    // "gaaaaaand" → "gaand", "chhoood" → "chood".
    // We do NOT collapse Devanagari because vowel matras can repeat legitimately.
    s = s.replaceAllMapped(
      RegExp(r'([a-z])\1{2,}'),
      (m) => '${m[1]}${m[1]}',
    );

    return s.trim();
  }

  /// Compact normalization used for evasion detection.
  ///
  /// Strips ALL spaces and symbols, applies leet substitution, collapses
  /// repeated chars, and returns only Latin letters and Devanagari.
  /// "b h o s d i" → "bhosdi", "m@darch0d" → "madarchod".
  String compactNormalizeText(String text) {
    var s = text.toLowerCase();

    // Leet substitutions (same as above)
    s = s
        .replaceAll('@', 'a')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('*', '');

    // Keep only Latin letters and Devanagari (strip spaces, digits, symbols)
    s = s.replaceAll(RegExp(r'[^a-z\u0900-\u097F]'), '');

    // Aggressively collapse ANY run of repeated ASCII letters down to 1.
    // This is intentionally more aggressive than normalizeText (which keeps 2)
    // so that 'jhaavla' (from jh@@vla) → 'jhavla' and
    // 'chhootiya' → 'chotiya' both match their canonical evasion terms.
    s = s.replaceAllMapped(
      RegExp(r'([a-z])\1+'),
      (m) => m[1]!,
    );

    return s;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the matched term if [text] contains a blocked word or phrase;
  /// otherwise returns null (text is clean).
  String? findViolation(String text) {
    final normalized = normalizeText(text);
    final compact = compactNormalizeText(text);

    // 1. Phrase terms — simple containment (phrases carry their own context).
    for (final phrase in _phraseTerms) {
      final normPhrase = normalizeText(phrase);
      if (normalized.contains(normPhrase)) return phrase;
    }

    // 2. Devanagari terms — word-boundary regex on normalized text.
    for (final term in _devanagariTerms) {
      if (_wordBoundary(term).hasMatch(normalized)) return term;
    }

    // 3. Latin terms — word-boundary regex on normalized text.
    for (final term in _latinTerms) {
      if (_wordBoundary(term).hasMatch(normalized)) return term;
    }

    // 4. High-risk short terms — strict word boundary only.
    //    "bc" or "mc" standalone are abusive; "abc", "mcgregor" are not.
    for (final term in _highRiskShortTerms) {
      if (_wordBoundary(term).hasMatch(normalized)) return term;
    }

    // 5. Evasion check — match compact-normalized input against compact-normalized
    //    evasion terms. Both sides go through compactNormalizeText so that
    //    'jh@@vla'→'jhavla' and 'chhoootiya'→'chotiya' hit their canonical forms.
    for (final term in _compactEvasionTerms) {
      if (compact.contains(term)) return term;
    }

    return null;
  }

  /// Convenience: returns true if text should be blocked.
  bool isBlocked(String text) => findViolation(text) != null;
}

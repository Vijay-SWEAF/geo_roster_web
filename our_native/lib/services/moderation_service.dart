import '../services/supabase_service.dart';
import 'community_moderation_service.dart';
import 'local_blocklist_service.dart';

/// Result of an AI content moderation check.
class ModerationResult {
  final bool flagged;
  final String? reason;

  const ModerationResult({required this.flagged, this.reason});

  /// Passes = not flagged, safe to submit.
  bool get passes => !flagged;
}

/// Content moderation pipeline (4 layers):
///
///  1. **Local abusive blocklist** — instant, no network. Marathi/Hindi/English
///     slurs. Returns immediately on match.
///  2. **Community harmony scoring** — instant, no network. Detects political
///     propaganda, communal hate, caste slurs, divisive content. Blocks if
///     severity is highRisk or blocked.
///  3. **OpenAI Moderation API** — via Supabase Edge Function. Catches nuanced
///     English violations (threats, sexual content, etc.). Also runs for
///     mediumRisk community content so a second opinion is obtained.
///  4. **Admin queue** — every post/comment requires admin approval regardless.
///
/// Fail-open on layer 3: if the Edge Function is unavailable the check is
/// skipped and content proceeds to admin review.
class ModerationService {
  ModerationService._();
  static final ModerationService instance = ModerationService._();

  /// Check [text] through all moderation layers.
  /// Returns as soon as a violation is detected — no extra network calls.
  Future<ModerationResult> check(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const ModerationResult(flagged: false);

    // ── Layer 1: local abusive blocklist (instant, Marathi/Hindi/English) ───
    final blocked = LocalBlocklistService.instance.findViolation(trimmed);
    if (blocked != null) {
      return ModerationResult(
        flagged: true,
        reason: 'This content contains inappropriate language.',
      );
    }

    // ── Layer 2: community harmony scoring (instant, no network) ────────────
    final communityResult =
        CommunityModerationService.instance.evaluate(trimmed);
    if (communityResult.isFlagged) {
      return ModerationResult(
        flagged: true,
        reason: communityResult.primaryReason ??
            'This content may be harmful to community harmony.',
      );
    }

    // ── Layer 3: OpenAI moderation (network call) ────────────────────────────
    // Also runs for mediumRisk community content to get a second opinion.
    try {
      final response = await supabase.functions.invoke(
        'moderate-content',
        body: {'text': trimmed},
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null) return const ModerationResult(flagged: false);

      final flagged = data['flagged'] as bool? ?? false;
      final reason = data['reason'] as String?;
      return ModerationResult(flagged: flagged, reason: reason);
    } catch (_) {
      // Fail-open: never block a user due to moderation service downtime.
      return const ModerationResult(flagged: false);
    }
  }
}

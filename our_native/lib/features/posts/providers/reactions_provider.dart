import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../../posts/models/post.dart';

// ---------------------------------------------------------------------------
// State: per-post reaction the current user has made.
// key = postId, value = ReactionType | null (null means no reaction).
// ---------------------------------------------------------------------------

class UserReactionsNotifier extends Notifier<Map<String, ReactionType?>> {
  @override
  Map<String, ReactionType?> build() => const {};

  /// Bulk-load reactions from a list of post IDs (called after feed loads).
  Future<void> fetchForPosts(List<String> postIds) async {
    if (postIds.isEmpty) return;
    try {
      final result = await supabase.rpc(
        'get_my_reactions',
        params: {'p_post_ids': postIds},
      ) as Map<String, dynamic>?;

      if (result == null) return;
      final updated = Map<String, ReactionType?>.from(state);
      for (final entry in result.entries) {
        updated[entry.key] = entry.value != null
            ? ReactionType.fromString(entry.value as String)
            : null;
      }
      state = updated;
    } catch (_) {
      // Non-fatal — reactions simply show unselected
    }
  }

  /// Optimistically toggle a reaction, then call the DB RPC.
  /// Returns updated reaction_counts map.
  Future<Map<String, int>> toggle({
    required String postId,
    required ReactionType reaction,
  }) async {
    final current = state[postId];
    // Optimistic update
    state = {
      ...state,
      postId: current == reaction ? null : reaction,
    };

    try {
      final result = await supabase.rpc(
        'toggle_reaction',
        params: {
          'p_post_id': postId,
          'p_reaction_type': reaction.value,
        },
      ) as Map<String, dynamic>?;

      return result != null
          ? Map<String, int>.from(
              result.map((k, v) => MapEntry(k, (v as num).toInt())))
          : const {};
    } catch (e) {
      // Roll back optimistic update
      state = {...state, postId: current};
      rethrow;
    }
  }
}

final userReactionsProvider =
    NotifierProvider<UserReactionsNotifier, Map<String, ReactionType?>>(
  UserReactionsNotifier.new,
);

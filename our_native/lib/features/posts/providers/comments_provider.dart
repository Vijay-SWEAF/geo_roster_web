import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../../../services/moderation_service.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../posts/models/post.dart';

// ---------------------------------------------------------------------------
// A per-post comment with author name (joined by query).
// ---------------------------------------------------------------------------

class CommentWithAuthor {
  final Comment comment;
  final String authorName;

  const CommentWithAuthor({required this.comment, required this.authorName});
}

// ---------------------------------------------------------------------------
// Provider: load comments for a specific post.
// ---------------------------------------------------------------------------

final commentsProvider = FutureProvider.family.autoDispose<List<CommentWithAuthor>, String>(
  (ref, postId) async {
    final rows = await supabase
        .from('comments')
        .select(
          'id,post_id,author_id,body,status,created_at,'
          'author:user_profiles!comments_author_id_fkey(full_name)',
        )
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .limit(50);

    return (rows as List).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final author = row['author'] as Map<String, dynamic>?;
      return CommentWithAuthor(
        comment: Comment.fromJson(row),
        authorName: author?['full_name'] as String? ?? 'Community Member',
      );
    }).toList();
  },
);

// ---------------------------------------------------------------------------
// Notifier: posting a new comment (manages loading/error state).
// ---------------------------------------------------------------------------

class PostCommentNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> post({
    required String postId,
    required String body,
    required void Function() onSuccess,
  }) async {
    if (body.trim().isEmpty) return false;
    state = const AsyncLoading();
    try {
      final profile = await ref.read(userProfileProvider.future);
      if (profile == null) {
        state = AsyncError(
          'Set up your profile before commenting.',
          StackTrace.current,
        );
        return false;
      }

      // AI moderation check before inserting comment
      final modResult = await ModerationService.instance.check(body);
      if (modResult.flagged) {
        state = AsyncError(
          modResult.reason ??
              'Comment contains content that violates community guidelines.',
          StackTrace.current,
        );
        return false;
      }

      final autoApprove =
          profile.role.name == 'admin' || profile.role.name == 'moderator';

      await supabase.from('comments').insert({
        'post_id': postId,
        'author_id': profile.id,
        'body': body.trim(),
        'status': autoApprove ? 'approved' : 'pending_review',
      });
      state = const AsyncData(null);
      onSuccess();
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final postCommentProvider =
    NotifierProvider<PostCommentNotifier, AsyncValue<void>>(
  PostCommentNotifier.new,
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_utils.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/user_profile_provider.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class PendingComment {
  final String id;
  final String body;
  final String postId;
  final String postTitle;
  final String authorName;
  final String authorRole;
  final DateTime createdAt;

  const PendingComment({
    required this.id,
    required this.body,
    required this.postId,
    required this.postTitle,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
  });

  factory PendingComment.fromJson(Map<String, dynamic> j) => PendingComment(
        id: j['id'] as String,
        body: j['body'] as String,
        postId: j['post_id'] as String,
        postTitle: j['post_title'] as String? ?? 'Unknown Post',
        authorName: j['author_name'] as String? ?? 'Unknown',
        authorRole: j['author_role'] as String? ?? 'member',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final pendingCommentsProvider =
    FutureProvider.autoDispose<List<PendingComment>>((ref) async {
  final communityId = ref.watch(currentCommunityIdProvider);
  if (communityId == null) return [];

  final result = await supabase.rpc(
    'admin_get_pending_comments',
    params: {'p_community_id': communityId},
  );

  final list = (result as List?) ?? [];
  return list
      .map((e) => PendingComment.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PendingCommentsScreen extends ConsumerStatefulWidget {
  const PendingCommentsScreen({super.key});

  @override
  ConsumerState<PendingCommentsScreen> createState() =>
      _PendingCommentsScreenState();
}

class _PendingCommentsScreenState
    extends ConsumerState<PendingCommentsScreen> {
  final _processing = <String>{};

  Future<void> _moderate(PendingComment comment, String action) async {
    setState(() => _processing.add(comment.id));
    try {
      await supabase.rpc('moderate_comment', params: {
        'p_comment_id': comment.id,
        'p_action': action,
      });
      if (!mounted) return;
      final label = action == 'approve' ? 'Approved' : 'Removed';
      AppUtils.showSnack(context, '$label comment.');
      ref.invalidate(pendingCommentsProvider);
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnack(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processing.remove(comment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(pendingCommentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Comments'),
        backgroundColor: AppColors.primaryBrown,
        foregroundColor: Colors.white,
      ),
      body: commentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load: $e',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body))),
        data: (comments) {
          if (comments.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mark_chat_read_outlined,
                      size: 60,
                      color: AppColors.primaryGreen.withValues(alpha: 0.7)),
                  const SizedBox(height: 16),
                  Text('No pending comments', style: AppTextStyles.h3),
                  const SizedBox(height: 4),
                  Text('All comments are reviewed.',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingCommentsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: comments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _PendingCommentCard(
                comment: comments[i],
                isProcessing: _processing.contains(comments[i].id),
                onApprove: () => _moderate(comments[i], 'approve'),
                onReject: () => _moderate(comments[i], 'reject'),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card widget
// ---------------------------------------------------------------------------

class _PendingCommentCard extends StatelessWidget {
  final PendingComment comment;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingCommentCard({
    required this.comment,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post context
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: AppColors.backgroundBeige,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                const Icon(Icons.article_outlined,
                    size: 14, color: AppColors.primaryBrown),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    comment.postTitle,
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryBrown,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  AppUtils.timeAgo(comment.createdAt),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Comment body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text(comment.body,
                style: AppTextStyles.body, maxLines: 4,
                overflow: TextOverflow.ellipsis),
          ),
          // Author
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  '${comment.authorName} · ${comment.authorRole}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (isProcessing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.divider),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

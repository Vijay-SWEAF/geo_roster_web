import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_utils.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../posts/models/post.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class PendingPost {
  final String id;
  final String postType;
  final String title;
  final String? body;
  final String? coverImageUrl;
  final String authorName;
  final String authorRole;
  final DateTime createdAt;

  const PendingPost({
    required this.id,
    required this.postType,
    required this.title,
    this.body,
    this.coverImageUrl,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
  });

  factory PendingPost.fromJson(Map<String, dynamic> j) => PendingPost(
        id: j['id'] as String,
        postType: j['post_type'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        coverImageUrl: j['cover_image_url'] as String?,
        authorName: j['author_name'] as String? ?? 'Unknown',
        authorRole: j['author_role'] as String? ?? 'member',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final pendingPostsProvider =
    FutureProvider.autoDispose<List<PendingPost>>((ref) async {
  final communityId = ref.watch(currentCommunityIdProvider);
  if (communityId == null) return [];

  final result = await supabase.rpc(
    'admin_get_pending_posts',
    params: {'p_community_id': communityId},
  );

  final list = (result as List?) ?? [];
  return list
      .map((e) => PendingPost.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PendingPostsScreen extends ConsumerStatefulWidget {
  const PendingPostsScreen({super.key});

  @override
  ConsumerState<PendingPostsScreen> createState() => _PendingPostsScreenState();
}

class _PendingPostsScreenState extends ConsumerState<PendingPostsScreen> {
  final _processing = <String>{};

  Future<void> _moderate(PendingPost post, String action) async {
    String? note;
    if (action == 'reject') {
      note = await _askRejectionReason(post.title);
      if (note == null) return; // cancelled
    }

    setState(() => _processing.add(post.id));
    try {
      await supabase.rpc('moderate_post', params: {
        'p_post_id': post.id,
        'p_action': action,
        // ignore: use_null_aware_elements
        if (note != null) 'p_note': note,
      });
      if (!mounted) return;
      final label = action == 'approve' ? 'Approved' : 'Rejected';
      AppUtils.showSnack(context, '$label: "${post.title}"');
      ref.invalidate(pendingPostsProvider);
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnack(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processing.remove(post.id));
    }
  }

  Future<String?> _askRejectionReason(String postTitle) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejection Reason'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"$postTitle"',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'Tell the author why this post was rejected (they will see this)...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(pendingPostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Posts'),
        backgroundColor: AppColors.primaryBrown,
        foregroundColor: Colors.white,
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load: $e',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body))),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 60,
                      color: AppColors.primaryGreen.withValues(alpha: 0.7)),
                  const SizedBox(height: 16),
                  Text('No pending posts', style: AppTextStyles.h3),
                  const SizedBox(height: 4),
                  Text('All posts have been reviewed.',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingPostsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _PendingPostCard(
                post: posts[i],
                isProcessing: _processing.contains(posts[i].id),
                onApprove: () => _moderate(posts[i], 'approve'),
                onReject: () => _moderate(posts[i], 'reject'),
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

class _PendingPostCard extends StatelessWidget {
  final PendingPost post;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingPostCard({
    required this.post,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  Color get _typeColor {
    switch (post.postType) {
      case 'memory':       return AppColors.primaryBrown;
      case 'story':        return const Color(0xFF7B4F2E);
      case 'elder_wisdom': return AppColors.accentGold;
      case 'help_request': return AppColors.success;
      case 'event':        return AppColors.primaryGreen;
      case 'achievement':  return AppColors.info;
      default:             return AppColors.primaryBrown;
    }
  }

  String get _typeEmoji {
    switch (post.postType) {
      case 'memory':       return '📷';
      case 'story':        return '📖';
      case 'elder_wisdom': return '🙏';
      case 'help_request': return '🤝';
      case 'event':        return '🎉';
      case 'achievement':  return '🏆';
      case 'announcement': return '📢';
      default:             return '📝';
    }
  }

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
          // Type badge + author
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_typeEmoji ${PostType.fromString(post.postType).displayName}',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: _typeColor, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text(
                  AppUtils.timeAgo(post.createdAt),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Text(post.title,
                style: AppTextStyles.h3,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          // Body preview
          if (post.body != null && post.body!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Text(
                post.body!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Author
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  '${post.authorName} · ${post.authorRole}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // Action buttons
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
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
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

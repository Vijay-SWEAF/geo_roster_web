import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_utils.dart';
import '../../features/posts/models/post.dart';
import 'reaction_bar.dart';
import 'moderation_status_chip.dart';

/// Universal post card used in home feed for all content types.
class PostCard extends StatelessWidget {
  final Post post;
  final String authorName;
  final String? authorPhotoUrl;
  final String? authorRole;
  final Map<String, int> reactionCounts;
  final int commentCount;
  final ReactionType? myReaction;
  final VoidCallback? onTap;
  final void Function(ReactionType)? onReact;
  final VoidCallback? onComment;
  final VoidCallback? onReport;

  const PostCard({
    super.key,
    required this.post,
    required this.authorName,
    this.authorPhotoUrl,
    this.authorRole,
    this.reactionCounts = const {},
    this.commentCount = 0,
    this.myReaction,
    this.onTap,
    this.onReact,
    this.onComment,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (post.coverImageUrl != null) _buildCoverImage(),
            _buildBody(),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.backgroundBeige,
            backgroundImage: authorPhotoUrl != null
                ? CachedNetworkImageProvider(authorPhotoUrl!)
                : null,
            child: authorPhotoUrl == null
                ? Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.primaryBrown),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(authorName, style: AppTextStyles.labelLarge),
                Text(
                  AppUtils.timeAgo(post.createdAt),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          // Post type chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              post.postType.displayName,
              style: AppTextStyles.labelSmall
                  .copyWith(color: _typeColor, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                size: 20, color: AppColors.textHint),
            onSelected: (v) {
              if (v == 'report') onReport?.call();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Report'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: post.coverImageUrl!,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            height: 200,
            color: AppColors.backgroundBeige,
            child: const Center(
              child: Icon(Icons.image_outlined,
                  size: 40, color: AppColors.textHint),
            ),
          ),
          errorWidget: (_, _, _) => Container(
            height: 200,
            color: AppColors.backgroundBeige,
            child: const Center(
              child: Icon(Icons.broken_image_outlined,
                  size: 40, color: AppColors.textHint),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.title, style: AppTextStyles.h3),
          if (post.body != null && post.body!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              post.body!,
              style: AppTextStyles.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (post.status != PostStatus.approved) ...[
            const SizedBox(height: 8),
            ModerationStatusChip(status: post.status),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final totalReactions =
        reactionCounts.values.fold(0, (a, b) => a + b);

    // Build sorted per-type emoji bubbles (top 3 by count)
    final sortedReactions = reactionCounts.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topReactions = sortedReactions.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        children: [
          if (totalReactions > 0 || commentCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Per-type emoji summary
                  if (topReactions.isNotEmpty) ...[
                    ...topReactions.map((e) {
                      final rt = ReactionType.fromString(e.key);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(rt.emoji,
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 2),
                            Text('${e.value}',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      );
                    }),
                  ],
                  const Spacer(),
                  if (commentCount > 0)
                    Text(
                      '$commentCount ${commentCount == 1 ? "comment" : "comments"}',
                      style: AppTextStyles.caption,
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ReactionBar(
                  currentReaction: myReaction,
                  onReactionSelected: onReact,
                ),
              ),
              if (!post.commentsDisabled) ...[
                const SizedBox(width: 8),
                _footerButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Comment',
                  onTap: onComment,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _footerButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.bodySmall),
          ],
        ),
      );

  Color get _typeColor {
    switch (post.postType) {
      case PostType.memory:       return AppColors.primaryBrown;
      case PostType.story:        return AppColors.primaryGold;
      case PostType.elderWisdom:  return AppColors.accentGold;
      case PostType.helpRequest:  return AppColors.error;
      case PostType.event:        return AppColors.primaryGreen;
      case PostType.achievement:  return AppColors.success;
      case PostType.announcement: return AppColors.info;
    }
  }
}

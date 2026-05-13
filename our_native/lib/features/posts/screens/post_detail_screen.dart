import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_utils.dart';
import '../models/post.dart';
import '../providers/reactions_provider.dart';
import '../providers/comments_provider.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../../core/widgets/reaction_bar.dart';

/// Full-page detail view for any post type.
/// Route: /posts/:id  with HomeFeedItem passed via extra.
class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  final String postTitle;
  final String? postBody;
  final String? coverImageUrl;
  final Post post;
  final String authorName;
  final String? authorRole;
  final Map<String, int> initialReactionCounts;
  final int initialCommentCount;

  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.postTitle,
    required this.postBody,
    this.coverImageUrl,
    required this.post,
    required this.authorName,
    this.authorRole,
    this.initialReactionCounts = const {},
    this.initialCommentCount = 0,
  });

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  late Map<String, int> _reactionCounts;
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _reactionCounts = Map.from(widget.initialReactionCounts);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleReaction(ReactionType reaction) async {
    try {
      final updated = await ref
          .read(userReactionsProvider.notifier)
          .toggle(postId: widget.postId, reaction: reaction);
      if (mounted) {
        setState(() => _reactionCounts = updated);
      }
    } catch (e) {
      if (mounted) AppUtils.showSnack(context, 'Could not save reaction');
    }
  }

  Future<void> _postComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _submitting = true);

    final ok = await ref.read(postCommentProvider.notifier).post(
          postId: widget.postId,
          body: body,
          onSuccess: () {
            _commentCtrl.clear();
            ref.invalidate(commentsProvider(widget.postId));
          },
        );

    if (mounted) {
      setState(() => _submitting = false);
      if (!ok) AppUtils.showSnack(context, 'Could not post comment');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myReaction = ref.watch(userReactionsProvider)[widget.postId];
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    final profile = ref.watch(userProfileProvider).asData?.value;
    final totalReactions = _reactionCounts.values.fold(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: AppColors.backgroundIvory,
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          // ── App bar with cover image or solid colour ──────────────────────
          SliverAppBar(
            expandedHeight: widget.coverImageUrl != null ? 260 : 0,
            pinned: true,
            backgroundColor: AppColors.backgroundIvory,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: widget.coverImageUrl != null
                ? FlexibleSpaceBar(
                    background: CachedNetworkImage(
                      imageUrl: widget.coverImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: AppColors.backgroundBeige,
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.backgroundBeige,
                        child: const Icon(Icons.broken_image_outlined,
                            size: 48, color: AppColors.textHint),
                      ),
                    ),
                  )
                : null,
          ),

          // ── Post content ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post type chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.post.postType.displayName,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: _typeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.postTitle, style: AppTextStyles.h1),
                  const SizedBox(height: 8),
                  _buildAuthorRow(),
                  if (widget.postBody != null &&
                      widget.postBody!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(widget.postBody!, style: AppTextStyles.bodyLarge),
                  ],
                ],
              ),
            ),
          ),

          // ── Reaction summary ──────────────────────────────────────────────
          if (totalReactions > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  '$totalReactions ${totalReactions == 1 ? "reaction" : "reactions"}',
                  style: AppTextStyles.caption,
                ),
              ),
            ),

          // ── Reaction + comment action row ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: ReactionBar(
                          currentReaction: myReaction,
                          onReactionSelected: _handleReaction,
                        ),
                      ),
                      if (!widget.post.commentsDisabled) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => FocusScope.of(context).requestFocus(
                            FocusNode(),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text('Comment',
                                  style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Divider(),
                ],
              ),
            ),
          ),

          // ── Comments section header ───────────────────────────────────────
          if (!widget.post.commentsDisabled)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text('Comments', style: AppTextStyles.h3),
              ),
            ),

          // ── Comments list ─────────────────────────────────────────────────
          if (!widget.post.commentsDisabled)
            commentsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Could not load comments',
                      style: AppTextStyles.caption),
                ),
              ),
              data: (comments) {
                if (comments.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Text('No comments yet. Be the first!',
                          style: AppTextStyles.caption),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _CommentTile(item: comments[i]),
                    childCount: comments.length,
                  ),
                );
              },
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),

      // ── Comment input bar ─────────────────────────────────────────────────
      bottomNavigationBar: widget.post.commentsDisabled
          ? null
          : _buildCommentBar(profile?.fullName),
    );
  }

  Widget _buildAuthorRow() {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.backgroundBeige,
          child: Text(
            widget.authorName.isNotEmpty
                ? widget.authorName[0].toUpperCase()
                : 'U',
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.primaryBrown),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.authorName, style: AppTextStyles.label),
            Text(AppUtils.timeAgo(widget.post.createdAt),
                style: AppTextStyles.caption),
          ],
        ),
        if (widget.authorRole != null) ...[
          const SizedBox(width: 8),
          Text(
            widget.authorRole!,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.primaryGreen),
          ),
        ],
      ],
    );
  }

  Widget _buildCommentBar(String? userName) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 8,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.backgroundBeige,
              child: Text(
                (userName?.isNotEmpty == true ? userName![0] : 'U')
                    .toUpperCase(),
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.primaryBrown),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _commentCtrl,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Write a comment…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundBeige,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _submitting
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: AppColors.primaryGreen),
                    onPressed: _postComment,
                  ),
          ],
        ),
      ),
    );
  }

  Color get _typeColor {
    switch (widget.post.postType) {
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

// ---------------------------------------------------------------------------
// Comment tile widget
// ---------------------------------------------------------------------------

class _CommentTile extends StatelessWidget {
  final CommentWithAuthor item;

  const _CommentTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.backgroundBeige,
            child: Text(
              item.authorName.isNotEmpty
                  ? item.authorName[0].toUpperCase()
                  : 'U',
              style:
                  AppTextStyles.labelSmall.copyWith(color: AppColors.primaryBrown),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.authorName, style: AppTextStyles.label),
                      const SizedBox(width: 8),
                      Text(
                        AppUtils.timeAgo(item.comment.createdAt),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.comment.body, style: AppTextStyles.body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

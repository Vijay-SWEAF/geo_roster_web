import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/utils/app_utils.dart';
import '../../posts/models/post.dart';
import '../../posts/screens/post_detail_screen.dart';
import '../../posts/providers/reactions_provider.dart';
import '../models/help_request.dart';
import '../providers/help_provider.dart';

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  @override
  Widget build(BuildContext context) {
    final helpAsync = ref.watch(helpRequestsProvider);

    // Fetch reactions for visible posts when data arrives
    helpAsync.whenData((items) {
      if (items.isNotEmpty) {
        final ids = items.map((i) => i.post.id).toList();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(userReactionsProvider.notifier).fetchForPosts(ids);
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Help'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => context.push('/help/create'),
            tooltip: 'Request Help',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(helpRequestsProvider);
          await ref.read(helpRequestsProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHelpBanner()),
            SliverToBoxAdapter(child: _buildQuickTypes(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Open Requests', style: AppTextStyles.h2),
              ),
            ),
            ..._buildHelpSlivers(helpAsync),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHelpSlivers(AsyncValue<List<HelpFeedItem>> asyncData) {
    return asyncData.when(
      loading: () => [
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (error, _) => [
        SliverFillRemaining(
          child: AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(helpRequestsProvider),
          ),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return [
            SliverFillRemaining(
              child: AppEmptyState(
                icon: Icons.volunteer_activism_outlined,
                title: 'No help requests',
                subtitle: 'The community is doing well! Post if you need any help.',
                action: ElevatedButton(
                  onPressed: () => context.push('/help/create'),
                  child: const Text('Request Help'),
                ),
              ),
            ),
          ];
        }

        return [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final item = items[i];
                return _HelpRequestCard(
                  post: item.post,
                  helpRequest: item.helpRequest,
                  authorName: item.authorName,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(
                        postId: item.post.id,
                        postTitle: item.post.title,
                        postBody: item.post.body,
                        coverImageUrl: item.post.coverImageUrl,
                        post: item.post,
                        authorName: item.authorName,
                        initialReactionCounts: Map<String, int>.from(
                            item.post.reactionCounts ?? {}),
                        initialCommentCount: item.post.commentCount ?? 0,
                      ),
                    ),
                  ),
                );
              },
              childCount: items.length,
            ),
          ),
        ];
      },
    );
  }

  Widget _buildHelpBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('🤝', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Help someone today.\nEvery small act of kindness builds a stronger community.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.success, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTypes(BuildContext context) {
    const types = [
      HelpType.blood,
      HelpType.hospital,
      HelpType.education,
      HelpType.volunteer,
      HelpType.emergency,
    ];
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: types.length,
        itemBuilder: (_, i) => _HelpTypeCard(
          type: types[i],
          onTap: () => context.push('/help/create'),
        ),
      ),
    );
  }
}

class _HelpTypeCard extends StatelessWidget {
  final HelpType type;
  final VoidCallback onTap;
  const _HelpTypeCard({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(type.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              type.displayName.split(' ').first,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpRequestCard extends StatelessWidget {
  final Post post;
  final HelpRequest helpRequest;
  final String authorName;
  final VoidCallback? onTap;

  const _HelpRequestCard({
    required this.post,
    required this.helpRequest,
    required this.authorName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = helpRequest.urgency == HelpUrgency.high ||
        helpRequest.urgency == HelpUrgency.critical;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent ? AppColors.error.withValues(alpha: 0.3) : AppColors.divider,
          width: isUrgent ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(helpRequest.helpType.emoji,
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(post.title, style: AppTextStyles.h3),
                ),
                if (isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'URGENT',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.error),
                    ),
                  ),
              ],
            ),
            if (post.body != null) ...[
              const SizedBox(height: 8),
              Text(
                post.body!,
                style: AppTextStyles.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(authorName, style: AppTextStyles.caption),
                const SizedBox(width: 12),
                const Icon(Icons.access_time_outlined,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(AppUtils.timeAgo(post.createdAt),
                    style: AppTextStyles.caption),
                const Spacer(),
                _StatusChip(status: helpRequest.helpStatus),
              ],
            ),
            if (helpRequest.contactPhone != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.phone_outlined, size: 16),
                label: Text('Contact ${helpRequest.contactName ?? ""}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final HelpStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label,
        style:
            AppTextStyles.caption.copyWith(color: _color, fontWeight: FontWeight.w700),
      ),
    );
  }

  String get _label {
    switch (status) {
      case HelpStatus.open:         return 'Open';
      case HelpStatus.inProgress:   return 'In Progress';
      case HelpStatus.helpReceived: return 'Help Received';
      case HelpStatus.closed:       return 'Closed';
    }
  }

  Color get _color {
    switch (status) {
      case HelpStatus.open:         return AppColors.warning;
      case HelpStatus.inProgress:   return AppColors.info;
      case HelpStatus.helpReceived: return AppColors.success;
      case HelpStatus.closed:       return AppColors.textHint;
    }
  }
}

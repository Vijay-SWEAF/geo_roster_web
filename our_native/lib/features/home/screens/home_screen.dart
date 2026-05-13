import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/post_card.dart';
import '../../../features/posts/screens/post_detail_screen.dart';
import '../../../features/posts/providers/reactions_provider.dart';
import '../../../features/events/models/event.dart';
import '../../../core/utils/app_utils.dart';
import '../providers/home_feed_provider.dart';
import '../providers/event_strip_provider.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/welcome_banner.dart';
import '../../../core/widgets/event_chip.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../notifications/providers/notifications_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Local override map for reaction counts updated after a toggle
  final Map<String, Map<String, int>> _reactionOverrides = {};

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final communityLabel = profile?.nativeVillage?.trim().isNotEmpty == true
        ? profile!.nativeVillage!
        : 'your community';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeFeedProvider);
          setState(() => _reactionOverrides.clear());
        },
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverToBoxAdapter(child: WelcomeBanner(communityLabel: communityLabel)),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Upcoming Events',
                seeAllRoute: '/events',
                onSeeAll: () => context.go('/events'),
              ),
            ),
            SliverToBoxAdapter(
              child: Consumer(
                builder: (context, ref, _) {
                  final eventsAsync = ref.watch(homeEventStripProvider);
                  return eventsAsync.when(
                    data: (events) => _buildEventStrip(context, events),
                    loading: () => const SizedBox(
                      height: 130,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, st) => const SizedBox(
                      height: 130,
                      child: Center(child: Text('Failed to load events', style: TextStyle(color: Colors.red))),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Today in $communityLabel',
              ),
            ),
            Consumer(
              builder: (context, ref, _) {
                final feedAsync = ref.watch(homeFeedProvider);
                final myReactions = ref.watch(userReactionsProvider);

                return feedAsync.when(
                  data: (feed) {
                    // Prefetch current user's reactions for visible posts
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final ids = feed.map((f) => f.post.id).toList();
                      ref.read(userReactionsProvider.notifier).fetchForPosts(ids);
                    });

                    if (feed.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Center(
                            child: Text(
                              'No posts yet.\nBe the first to share something!',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body,
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final item = feed[i];
                          final counts = _reactionOverrides[item.post.id] ?? item.reactionCounts;
                          final isPinned = item.post.isPinned;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isPinned)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.push_pin_rounded,
                                          size: 13, color: AppColors.primaryGold),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Pinned announcement',
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.primaryGold,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              PostCard(
                                post: item.post,
                                authorName: item.authorName,
                                authorRole: item.authorRole,
                                reactionCounts: counts,
                                commentCount: item.commentCount,
                                myReaction: myReactions[item.post.id],
                                onTap: () => _openPost(context, item),
                                onReact: (reaction) async {
                                  final updated = await ref
                                      .read(userReactionsProvider.notifier)
                                      .toggle(
                                          postId: item.post.id,
                                          reaction: reaction);
                                  if (mounted) {
                                    setState(() => _reactionOverrides[item
                                        .post.id] = updated);
                                  }
                                },
                                onComment: () => _openPost(context, item),
                                onReport: () => _showReportDialog(context, item.post.id),
                              ),
                            ],
                          );
                        },
                        childCount: feed.length,
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (e, st) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Center(child: Text('Failed to load feed', style: TextStyle(color: Colors.red))),
                    ),
                  ),
                );
              },
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  Future<void> _openPost(BuildContext context, HomeFeedItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          postId: item.post.id,
          postTitle: item.post.title,
          postBody: item.post.body,
          coverImageUrl: item.post.coverImageUrl,
          post: item.post,
          authorName: item.authorName,
          authorRole: item.authorRole,
          initialReactionCounts: _reactionOverrides[item.post.id] ?? item.reactionCounts,
          initialCommentCount: item.commentCount,
        ),
      ),
    );
    // After returning, refresh reaction state
    if (mounted) {
      ref.invalidate(homeFeedProvider);
      setState(() => _reactionOverrides.clear());
    }
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppColors.backgroundIvory,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.divider,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'playstore/app_icon_green.png',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Text(AppL10n.of(context).appName, style: AppTextStyles.h2),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => context.push('/search'),
          tooltip: 'Search',
        ),
        Consumer(
          builder: (context, ref, _) {
            final unread = ref.watch(unreadNotificationsCountProvider);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push('/notifications'),
                  tooltip: 'Notifications',
                ),
                if (unread > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1.2),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }


  Widget _buildEventStrip(BuildContext context, List<Event> events) {
    if (events.isEmpty) {
      return SizedBox(
        height: 130,
        child: Center(child: Text('No upcoming events')),
      );
    }
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: events.length,
        itemBuilder: (_, i) {
          final event = events[i];
          return EventChip(
            event: event,
            onTap: () => context.push('/events/${event.id}'),
          );
        },
      ),
    );
  }

  void _showReportDialog(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Report Post', style: AppTextStyles.h3),
        content: Text(
          'Why are you reporting this post?',
          style: AppTextStyles.body,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              AppUtils.showSnack(
                  context, 'Post reported. A moderator will review it.');
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }
}


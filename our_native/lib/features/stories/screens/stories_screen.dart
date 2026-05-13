import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/post_card.dart';
import '../../posts/screens/post_detail_screen.dart';
import '../../posts/providers/reactions_provider.dart';
import '../providers/stories_provider.dart';

class StoriesScreen extends ConsumerStatefulWidget {
  const StoriesScreen({super.key});

  @override
  ConsumerState<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends ConsumerState<StoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final storiesAsync = ref.watch(storiesProvider);

    storiesAsync.whenData((items) {
      if (items.isNotEmpty) {
        final ids = items.map((i) => i.post.id).toList();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(userReactionsProvider.notifier).fetchForPosts(ids);
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Stories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => context.push('/create-post?type=story'),
            tooltip: 'Share a Story',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(storiesProvider);
          await ref.read(storiesProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            ..._buildFeed(storiesAsync),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeed(AsyncValue<List<StoryFeedItem>> asyncData) {
    return asyncData.when(
      loading: () => [
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (e, _) => [
        SliverFillRemaining(
          child: AppErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(storiesProvider),
          ),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return [
            SliverFillRemaining(
              child: AppEmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No stories yet',
                subtitle:
                    'Share folk tales, personal journeys, or wisdom in Marathi or English.',
                action: ElevatedButton(
                  onPressed: () => context.push('/create-post?type=story'),
                  child: const Text('Share a Story'),
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
                final myReactions = ref.watch(userReactionsProvider);
                return PostCard(
                  post: item.post,
                  authorName: item.authorName,
                  reactionCounts:
                      Map<String, int>.from(item.post.reactionCounts ?? {}),
                  commentCount: item.post.commentCount ?? 0,
                  myReaction: myReactions[item.post.id],
                  onReact: (reaction) => ref
                      .read(userReactionsProvider.notifier)
                      .toggle(postId: item.post.id, reaction: reaction),
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

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B4F2E), AppColors.primaryBrown],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📖 Stories From the Village',
              style: AppTextStyles.h2.copyWith(color: AppColors.textOnDark)),
          const SizedBox(height: 6),
          Text(
            'Folk tales, personal journeys, and stories in Marathi and English — told by your own community.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textOnDark.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/post_card.dart';
import '../../posts/screens/post_detail_screen.dart';
import '../../posts/providers/reactions_provider.dart';
import '../providers/elders_provider.dart';

class EldersScreen extends ConsumerStatefulWidget {
  const EldersScreen({super.key});

  @override
  ConsumerState<EldersScreen> createState() => _EldersScreenState();
}

class _EldersScreenState extends ConsumerState<EldersScreen> {
  @override
  Widget build(BuildContext context) {
    final eldersAsync = ref.watch(elderPostsProvider);

    // Fetch reactions
    eldersAsync.whenData((items) {
      if (items.isNotEmpty) {
        final ids = items.map((i) => i.post.id).toList();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(userReactionsProvider.notifier).fetchForPosts(ids);
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Elders\' Wisdom')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(elderPostsProvider);
          await ref.read(elderPostsProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            ..._buildFeed(eldersAsync),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeed(AsyncValue<List<ElderPostItem>> asyncData) {
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
            onRetry: () => ref.invalidate(elderPostsProvider),
          ),
        ),
      ],
      data: (items) {
        if (items.isEmpty) {
          return [
            SliverFillRemaining(
              child: AppEmptyState(
                icon: Icons.elderly_outlined,
                title: 'No wisdom posts yet',
                subtitle:
                    'Elders and approved members can share traditional knowledge here.',
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
        color: AppColors.primaryBrown,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🙏 Wisdom of the Ages',
              style: AppTextStyles.h2.copyWith(color: AppColors.textOnDark)),
          const SizedBox(height: 6),
          Text(
            'Preserving knowledge passed down by our village elders — traditions, farming, medicine, philosophy.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textOnDark.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/post_card.dart';
import '../../../core/widgets/app_states.dart';
import '../../../features/posts/screens/post_detail_screen.dart';
import '../../../features/posts/providers/reactions_provider.dart';
import '../models/memory.dart';
import '../providers/memories_provider.dart';

class MemoriesScreen extends ConsumerStatefulWidget {
  const MemoriesScreen({super.key});

  @override
  ConsumerState<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends ConsumerState<MemoriesScreen> {
  MemoryCategory? _selectedCategory;
  String? _selectedDecade; // e.g. '1980s'

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(memoriesFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Archive'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(memoriesFeedProvider);
          await ref.read(memoriesFeedProvider.future);
        },
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildArchiveHeader()),
          SliverToBoxAdapter(child: _buildCategoryScroll()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Golden Memories', style: AppTextStyles.h2),
            ),
          ),
          ..._buildMemoriesSliver(memoriesAsync),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
        ),
      ),
    );
  }

  List<Widget> _buildMemoriesSliver(AsyncValue<List<MemoryFeedItem>> asyncData) {
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
            onRetry: () => ref.invalidate(memoriesFeedProvider),
          ),
        ),
      ],
      data: (items) {
        var filtered = _selectedCategory == null
            ? items
            : items
                .where((item) => item.memory?.category == _selectedCategory)
                .toList();

        if (_selectedDecade != null) {
          final decade = int.tryParse(_selectedDecade!.replaceAll('s', ''));
          if (decade != null) {
            filtered = filtered.where((item) {
              final year = int.tryParse(item.memory?.approxYear ?? '');
              if (year == null) return false;
              return year >= decade && year < decade + 10;
            }).toList();
          }
        }

        if (filtered.isEmpty) {
          return [
            SliverFillRemaining(
              child: AppEmptyState(
                icon: Icons.photo_album_outlined,
                title: 'No memories yet',
                subtitle:
                    'Be the first to share an old photo or memory from the village.',
                action: ElevatedButton(
                  onPressed: () => context.push('/memories/create'),
                  child: const Text('Share a Memory'),
                ),
              ),
            ),
          ];
        }

        return [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final item = filtered[i];
                final post = item.post;
                final myReactions = ref.watch(userReactionsProvider);
                return PostCard(
                  post: post,
                  authorName: item.authorName,
                  reactionCounts: Map<String, int>.from(post.reactionCounts ?? {}),
                  commentCount: post.commentCount ?? 0,
                  myReaction: myReactions[post.id],
                  onReact: (reaction) => ref
                      .read(userReactionsProvider.notifier)
                      .toggle(postId: post.id, reaction: reaction),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(
                        postId: post.id,
                        postTitle: post.title,
                        postBody: post.body,
                        coverImageUrl: post.coverImageUrl,
                        post: post,
                        authorName: item.authorName,
                        initialReactionCounts: Map<String, int>.from(post.reactionCounts ?? {}),
                        initialCommentCount: post.commentCount ?? 0,
                      ),
                    ),
                  ),
                );
              },
              childCount: filtered.length,
            ),
          ),
        ];
      },
    );
  }

  Widget _buildArchiveHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryBrown,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Before It Disappears',
                  style: AppTextStyles.h2
                      .copyWith(color: AppColors.textOnDark),
                ),
                const SizedBox(height: 4),
                Text(
                  'Preserve our golden era 1970–2000 and beyond.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textOnDark.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          const Text('📷', style: TextStyle(fontSize: 40)),
        ],
      ),
    );
  }

  Widget _buildCategoryScroll() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _CategoryChip(
            label: 'All',
            emoji: '🌟',
            isSelected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          ...MemoryCategory.values.map(
            (c) => _CategoryChip(
              label: c.displayName,
              emoji: c.emoji,
              isSelected: _selectedCategory == c,
              onTap: () => setState(() => _selectedCategory = c),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter Memories', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              Text('Filter by decade', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['1960s', '1970s', '1980s', '1990s', '2000s', '2010s']
                    .map(
                      (decade) => FilterChip(
                        label: Text(decade),
                        selected: _selectedDecade == decade,
                        onSelected: (selected) {
                          setSheetState(() {});
                          setState(() {
                            _selectedDecade = selected ? decade : null;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              if (_selectedDecade != null)
                TextButton(
                  onPressed: () {
                    setState(() => _selectedDecade = null);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Clear filter'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBrown
              : AppColors.backgroundBeige,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryBrown : AppColors.divider,
          ),
        ),
        child: Text(
          '$emoji $label',
          style: AppTextStyles.labelSmall.copyWith(
            color: isSelected ? AppColors.textOnDark : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

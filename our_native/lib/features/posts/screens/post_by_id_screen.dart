import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/supabase_service.dart';
import '../../home/providers/home_feed_provider.dart';
import '../../posts/models/post.dart';
import '../../posts/screens/post_detail_screen.dart';

/// Fetches a single post by ID and shows PostDetailScreen.
/// Used when navigating from notifications.
class PostByIdScreen extends ConsumerWidget {
  final String postId;
  const PostByIdScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(_postByIdProvider(postId));

    return postAsync.when(
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: AppColors.backgroundIvory),
            backgroundColor: AppColors.backgroundIvory,
            body: Center(
              child: Text('Post not found', style: AppTextStyles.bodyLarge),
            ),
          );
        }
        return PostDetailScreen(
          postId: item.post.id,
          postTitle: item.post.title,
          postBody: item.post.body,
          coverImageUrl: item.post.coverImageUrl,
          post: item.post,
          authorName: item.authorName,
          authorRole: item.authorRole,
          initialReactionCounts: item.reactionCounts,
          initialCommentCount: item.commentCount,
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.backgroundIvory,
        appBar: AppBar(backgroundColor: AppColors.backgroundIvory),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        backgroundColor: AppColors.backgroundIvory,
        appBar: AppBar(backgroundColor: AppColors.backgroundIvory),
        body: Center(
          child: Text('Could not load post', style: AppTextStyles.bodyLarge),
        ),
      ),
    );
  }
}

final _postByIdProvider =
    FutureProvider.autoDispose.family<HomeFeedItem?, String>((ref, postId) async {
  final row = await supabase
      .from('posts')
      .select(
        'id,community_id,author_id,post_type,title,body,cover_image_url,status,'
        'visibility,comments_disabled,is_pinned,created_at,updated_at,'
        'reaction_counts,comment_count,'
        'author:user_profiles!posts_author_id_fkey(full_name,role)',
      )
      .eq('id', postId)
      .maybeSingle();

  if (row == null) return null;
  final data = Map<String, dynamic>.from(row);
  final post = Post.fromJson(data);
  final author = data['author'] as Map<String, dynamic>?;

  return HomeFeedItem(
    post: post,
    authorName: author?['full_name'] as String? ?? 'Unknown',
    authorRole: author?['role'] as String?,
    reactionCounts: Map<String, int>.from(post.reactionCounts ?? {}),
    commentCount: post.commentCount ?? 0,
  );
});

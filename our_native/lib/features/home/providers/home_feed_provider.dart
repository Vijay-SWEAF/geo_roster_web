import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../posts/models/post.dart';

class HomeFeedItem {
  final Post post;
  final String authorName;
  final String? authorRole;
  final Map<String, int> reactionCounts;
  final int commentCount;

  const HomeFeedItem({
    required this.post,
    required this.authorName,
    this.authorRole,
    this.reactionCounts = const {},
    this.commentCount = 0,
  });
}

final homeFeedProvider = FutureProvider<List<HomeFeedItem>>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  final communityId = profile?.communityId;
  if (communityId == null) return const [];

  final rows = await supabase
      .from('posts')
      .select(
        'id,community_id,author_id,post_type,title,body,cover_image_url,status,visibility,comments_disabled,is_pinned,created_at,updated_at,reaction_counts,comment_count,'
        'author:user_profiles!posts_author_id_fkey(full_name,role)'
      )
      .eq('community_id', communityId)
      .order('is_pinned', ascending: false)
      .order('created_at', ascending: false)
      .limit(30);

  return (rows as List).map((raw) {
    final row = Map<String, dynamic>.from(raw as Map);
    final post = Post.fromJson(row);
    final author = row['author'] as Map<String, dynamic>?;
    return HomeFeedItem(
      post: post,
      authorName: author?['full_name'] ?? 'Unknown',
      authorRole: author?['role'],
      reactionCounts: Map<String, int>.from(post.reactionCounts ?? {}),
      commentCount: post.commentCount ?? 0,
    );
  }).toList();
});

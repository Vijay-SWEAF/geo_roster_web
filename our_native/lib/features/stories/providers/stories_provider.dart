import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supabase_service.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../posts/models/post.dart';

class StoryFeedItem {
  final Post post;
  final String authorName;

  const StoryFeedItem({required this.post, required this.authorName});
}

final storiesProvider = FutureProvider<List<StoryFeedItem>>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  final communityId = profile?.communityId;
  if (communityId == null) return const [];

  final rows = await supabase
      .from('posts')
      .select(
        'id,community_id,author_id,post_type,title,body,cover_image_url,status,visibility,comments_disabled,is_pinned,created_at,updated_at,reaction_counts,comment_count,'
        'author:user_profiles!posts_author_id_fkey(full_name)',
      )
      .eq('community_id', communityId)
      .eq('post_type', 'story')
      .eq('status', 'approved')
      .order('created_at', ascending: false);

  final result = <StoryFeedItem>[];
  for (final raw in rows as List) {
    final row = Map<String, dynamic>.from(raw as Map);
    final post = Post.fromJson(row);
    final authorNode = row['author'];
    final authorName = (authorNode is Map && authorNode['full_name'] != null)
        ? authorNode['full_name'] as String
        : 'Community Member';
    result.add(StoryFeedItem(post: post, authorName: authorName));
  }
  return result;
});

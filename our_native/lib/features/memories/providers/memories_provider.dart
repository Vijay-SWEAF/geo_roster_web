import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supabase_service.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../posts/models/post.dart';
import '../models/memory.dart';

class MemoryFeedItem {
  final Post post;
  final Memory? memory;
  final String authorName;

  const MemoryFeedItem({
    required this.post,
    required this.memory,
    required this.authorName,
  });
}

final memoriesFeedProvider = FutureProvider<List<MemoryFeedItem>>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  final communityId = profile?.communityId;
  if (communityId == null) return const [];

  final rows = await supabase
      .from('posts')
      .select(
        'id,community_id,author_id,post_type,title,body,cover_image_url,status,visibility,comments_disabled,is_pinned,created_at,updated_at,reaction_counts,comment_count,'
        'memories(id,post_id,approx_year,location_name,people_names,category,is_vintage,then_image_url,now_image_url),'
        'author:user_profiles!posts_author_id_fkey(full_name)',
      )
      .eq('community_id', communityId)
      .inFilter('post_type', ['memory'])
      .order('created_at', ascending: false);

  final result = <MemoryFeedItem>[];
  for (final raw in rows as List) {
    final row = Map<String, dynamic>.from(raw as Map);
    final post = Post.fromJson(row);

    final memoryNode = row['memories'];
    Map<String, dynamic>? memoryJson;
    if (memoryNode is List && memoryNode.isNotEmpty) {
      memoryJson = Map<String, dynamic>.from(memoryNode.first as Map);
    } else if (memoryNode is Map) {
      memoryJson = Map<String, dynamic>.from(memoryNode);
    }

    final authorNode = row['author'];
    String authorName = 'Community Member';
    if (authorNode is Map && authorNode['full_name'] != null) {
      authorName = authorNode['full_name'] as String;
    }

    result.add(
      MemoryFeedItem(
        post: post,
        memory: memoryJson == null ? null : Memory.fromJson(memoryJson),
        authorName: authorName,
      ),
    );
  }

  return result;
});

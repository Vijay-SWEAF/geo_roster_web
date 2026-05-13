import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supabase_service.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../posts/models/post.dart';
import '../models/help_request.dart';

class HelpFeedItem {
  final Post post;
  final HelpRequest helpRequest;
  final String authorName;

  const HelpFeedItem({
    required this.post,
    required this.helpRequest,
    required this.authorName,
  });
}

final helpRequestsProvider = FutureProvider<List<HelpFeedItem>>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  final communityId = profile?.communityId;
  if (communityId == null) return const [];

  final rows = await supabase
      .from('posts')
      .select(
        'id,community_id,author_id,post_type,title,body,cover_image_url,status,visibility,comments_disabled,is_pinned,created_at,updated_at,reaction_counts,comment_count,'
        'help_requests(id,post_id,help_type,urgency,contact_name,contact_phone,location,help_status),'
        'author:user_profiles!posts_author_id_fkey(full_name)',
      )
      .eq('community_id', communityId)
      .eq('post_type', 'help_request')
      .order('created_at', ascending: false);

  final result = <HelpFeedItem>[];
  for (final raw in rows as List) {
    final row = Map<String, dynamic>.from(raw as Map);
    final post = Post.fromJson(row);

    final helpNode = row['help_requests'];
    Map<String, dynamic>? helpJson;
    if (helpNode is List && helpNode.isNotEmpty) {
      helpJson = Map<String, dynamic>.from(helpNode.first as Map);
    } else if (helpNode is Map) {
      helpJson = Map<String, dynamic>.from(helpNode);
    }

    if (helpJson == null) continue;

    final authorNode = row['author'];
    String authorName = 'Community Member';
    if (authorNode is Map && authorNode['full_name'] != null) {
      authorName = authorNode['full_name'] as String;
    }

    result.add(
      HelpFeedItem(
        post: post,
        helpRequest: HelpRequest.fromJson(helpJson),
        authorName: authorName,
      ),
    );
  }

  return result;
});

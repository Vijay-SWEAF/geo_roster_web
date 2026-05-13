import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_states.dart';
import '../../posts/models/post.dart';
import '../../posts/screens/post_detail_screen.dart';
import '../../../services/supabase_service.dart';
import '../models/memory.dart';

/// Detail screen for a single Memory post (accessible via /memories/:id).
/// Fetches full post + memory metadata by post ID.
class MemoryDetailScreen extends ConsumerWidget {
  final String postId;

  const MemoryDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_memoryDetailProvider(postId));

    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_memoryDetailProvider(postId)),
        ),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const AppEmptyState(
              icon: Icons.photo_album_outlined,
              title: 'Memory not found',
              subtitle: 'This memory may have been removed.',
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
          initialReactionCounts: Map<String, int>.from(item.post.reactionCounts ?? {}),
          initialCommentCount: item.post.commentCount ?? 0,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Internal provider
// ---------------------------------------------------------------------------

class _MemoryDetail {
  final Post post;
  final Memory? memory;
  final String authorName;

  const _MemoryDetail({required this.post, required this.memory, required this.authorName});
}

final _memoryDetailProvider = FutureProvider.family.autoDispose<_MemoryDetail?, String>(
  (ref, postId) async {
    final rows = await supabase
        .from('posts')
        .select(
          'id,community_id,author_id,post_type,title,body,cover_image_url,status,visibility,comments_disabled,is_pinned,created_at,updated_at,reaction_counts,comment_count,'
          'memories(id,post_id,approx_year,location_name,people_names,category,is_vintage,then_image_url,now_image_url),'
          'author:user_profiles!posts_author_id_fkey(full_name)',
        )
        .eq('id', postId)
        .limit(1);

    if ((rows as List).isEmpty) return null;

    final row = Map<String, dynamic>.from(rows.first as Map);
    final post = Post.fromJson(row);

    final memoryNode = row['memories'];
    Map<String, dynamic>? memoryJson;
    if (memoryNode is List && memoryNode.isNotEmpty) {
      memoryJson = Map<String, dynamic>.from(memoryNode.first as Map);
    } else if (memoryNode is Map) {
      memoryJson = Map<String, dynamic>.from(memoryNode);
    }

    final authorNode = row['author'];
    final authorName = (authorNode is Map ? authorNode['full_name'] : null) as String?
        ?? 'Community Member';

    return _MemoryDetail(
      post: post,
      memory: memoryJson == null ? null : Memory.fromJson(memoryJson),
      authorName: authorName,
    );
  },
);

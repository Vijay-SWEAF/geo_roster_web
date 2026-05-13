import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supabase_service.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/user_profile_provider.dart';

// ── People list (all approved members in community) ───────────────────────────

final peopleProvider = FutureProvider.autoDispose<List<UserProfile>>((ref) async {
  final me = await ref.watch(userProfileProvider.future);
  final communityId = me?.communityId;
  if (communityId == null) return const [];

  final rows = await supabase
      .from('user_profiles')
      .select(
        'id,user_id,community_id,full_name,surname,native_village,'
        'current_location,profile_photo_url,role,bio,is_approved,'
        'language_pref,created_at,updated_at',
      )
      .eq('community_id', communityId)
      .eq('is_approved', true)
      .order('role', ascending: true)   // admin/elder first alphabetically
      .order('full_name', ascending: true);

  return (rows as List)
      .map((r) => UserProfile.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Single member profile ─────────────────────────────────────────────────────

final memberProfileProvider =
    FutureProvider.autoDispose.family<UserProfile?, String>((ref, profileId) async {
  final row = await supabase
      .from('user_profiles')
      .select(
        'id,user_id,community_id,full_name,surname,native_village,'
        'current_location,profile_photo_url,role,bio,is_approved,'
        'language_pref,created_at,updated_at',
      )
      .eq('id', profileId)
      .maybeSingle();

  if (row == null) return null;
  return UserProfile.fromJson(row);
});

// ── Member's approved posts ───────────────────────────────────────────────────

class MemberPostSummary {
  final String id;
  final String title;
  final String? body;
  final String postType;
  final String? coverImageUrl;
  final DateTime createdAt;

  const MemberPostSummary({
    required this.id,
    required this.title,
    this.body,
    required this.postType,
    this.coverImageUrl,
    required this.createdAt,
  });

  factory MemberPostSummary.fromJson(Map<String, dynamic> json) =>
      MemberPostSummary(
        id:           json['id'] as String,
        title:        json['title'] as String,
        body:         json['body'] as String?,
        postType:     json['post_type'] as String? ?? 'memory',
        coverImageUrl: json['cover_image_url'] as String?,
        createdAt:    DateTime.parse(json['created_at'] as String),
      );
}

final memberPostsProvider =
    FutureProvider.autoDispose.family<List<MemberPostSummary>, String>(
        (ref, profileId) async {
  final rows = await supabase
      .from('posts')
      .select('id,title,body,post_type,cover_image_url,created_at')
      .eq('author_id', profileId)
      .eq('status', 'approved')
      .order('created_at', ascending: false)
      .limit(20);

  return (rows as List)
      .map((r) => MemberPostSummary.fromJson(r as Map<String, dynamic>))
      .toList();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../events/models/event.dart';

final homeEventStripProvider = FutureProvider<List<Event>>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  final communityId = profile?.communityId;
  if (communityId == null) return const [];

  final rows = await supabase
      .from('events')
      .select()
      .eq('community_id', communityId)
      .gte('event_date', DateTime.now().toIso8601String())
      .order('event_date', ascending: true)
      .limit(10);

  return (rows as List)
      .map((e) => Event.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

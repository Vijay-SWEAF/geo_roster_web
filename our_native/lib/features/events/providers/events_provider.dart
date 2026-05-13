import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supabase_service.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../models/event.dart';

final communityEventsProvider = FutureProvider<List<Event>>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  final communityId = profile?.communityId;
  if (communityId == null) return const [];

  final rows = await supabase
      .from('events')
      .select()
      .eq('community_id', communityId)
      .order('event_date', ascending: true);

  return (rows as List)
      .map((e) => Event.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

final eventDetailProvider = FutureProvider.family.autoDispose<Event?, String>(
  (ref, eventId) async {
    final rows = await supabase
        .from('events')
        .select()
        .eq('id', eventId)
        .limit(1);

    if ((rows as List).isEmpty) return null;
    return Event.fromJson(Map<String, dynamic>.from(rows.first as Map));
  },
);

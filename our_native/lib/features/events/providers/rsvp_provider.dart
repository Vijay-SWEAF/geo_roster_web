import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supabase_service.dart';
import '../../auth/providers/user_profile_provider.dart';

class RsvpState {
  final String? myStatus; // 'going' | 'interested' | 'not_going' | null
  final int goingCount;
  final int interestedCount;

  const RsvpState({
    this.myStatus,
    this.goingCount = 0,
    this.interestedCount = 0,
  });
}

// ── Read provider ────────────────────────────────────────────────────────────

final rsvpProvider =
    FutureProvider.family.autoDispose<RsvpState, String>((ref, eventId) async {
  final profile = await ref.watch(userProfileProvider.future);
  if (profile == null) return const RsvpState();

  // My RSVP status
  final myRow = await supabase
      .from('event_rsvps')
      .select('status')
      .eq('event_id', eventId)
      .eq('user_id', profile.id)
      .maybeSingle();

  // Count going / interested
  final allRows = await supabase
      .from('event_rsvps')
      .select('status')
      .eq('event_id', eventId);

  int going = 0, interested = 0;
  for (final row in allRows as List) {
    final s = (row as Map)['status'] as String?;
    if (s == 'going') going++;
    if (s == 'interested') interested++;
  }

  return RsvpState(
    myStatus: myRow?['status'] as String?,
    goingCount: going,
    interestedCount: interested,
  );
});

// ── Mutation helper ───────────────────────────────────────────────────────────

/// Call [setRsvp] from a widget to update the user's RSVP.
/// Passing the same [status] the user already has will remove it (toggle off).
Future<void> setRsvp(WidgetRef ref, String eventId, String status) async {
  final profile = ref.read(userProfileProvider).asData?.value;
  if (profile == null) return;

  final current = ref.read(rsvpProvider(eventId)).asData?.value;
  final alreadySet = current?.myStatus == status;

  if (alreadySet) {
    await supabase
        .from('event_rsvps')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', profile.id);
  } else {
    await supabase.from('event_rsvps').upsert({
      'event_id': eventId,
      'user_id': profile.id,
      'status': status,
    });
  }

  ref.invalidate(rsvpProvider(eventId));
}

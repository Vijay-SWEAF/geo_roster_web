import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_states.dart';
import '../../../core/widgets/upcoming_event_banner.dart';
import '../../../core/widgets/event_list_card.dart';
import '../../auth/models/user_profile.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../providers/events_provider.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(communityEventsProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final canCreate = profile?.role.canModerate ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () => context.push('/events/create'),
              tooltip: 'Create Event',
            ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(communityEventsProvider),
        ),
        data: (events) {
          if (events.isEmpty) {
            return AppEmptyState(
              icon: Icons.event_outlined,
              title: 'No upcoming events',
              subtitle:
                  'Watch this space for village gatherings, festivals, and important dates.',
              action: canCreate
                  ? ElevatedButton(
                      onPressed: () => context.push('/events/create'),
                      child: const Text('Create Event'),
                    )
                  : null,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(communityEventsProvider);
              await ref.read(communityEventsProvider.future);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: events.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) return UpcomingEventBanner(event: events.first);
                return EventListCard(
                  event: events[i - 1],
                  onTap: () => context.push('/events/${events[i - 1].id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}


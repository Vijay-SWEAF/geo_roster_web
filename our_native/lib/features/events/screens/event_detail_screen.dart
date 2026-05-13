import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_states.dart';
import '../providers/events_provider.dart';
import '../providers/rsvp_provider.dart';
import '../models/event.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));

    return eventAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(eventDetailProvider(eventId)),
        ),
      ),
      data: (event) {
        if (event == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const AppEmptyState(
              icon: Icons.event_outlined,
              title: 'Event not found',
              subtitle: 'This event may have been removed.',
            ),
          );
        }
        return _EventDetailContent(event: event);
      },
    );
  }
}

class _EventDetailContent extends ConsumerWidget {
  final Event event;

  const _EventDetailContent({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rsvpAsync = ref.watch(rsvpProvider(event.id));
    return Scaffold(
      backgroundColor: AppColors.backgroundIvory,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: event.coverImageUrl != null ? 240 : 0,
            pinned: true,
            backgroundColor: AppColors.backgroundIvory,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: event.coverImageUrl != null
                ? FlexibleSpaceBar(
                    background: Image.network(
                      event.coverImageUrl!,
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event type + status chips
                  Row(
                    children: [
                      if (event.eventType != null)
                        _chip(event.eventType!.displayName, AppColors.primaryGreen),
                      if (event.eventType != null) const SizedBox(width: 8),
                      _chip(event.status, AppColors.primaryGold),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(event.title, style: AppTextStyles.h1),
                  const SizedBox(height: 12),
                  // Date / time
                  _infoRow(
                    Icons.calendar_today_outlined,
                    DateFormat('EEEE, d MMMM yyyy').format(event.eventDate),
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.schedule_outlined,
                    DateFormat.jm().format(event.eventDate),
                  ),
                  if (event.location != null) ...[
                    const SizedBox(height: 8),
                    _infoRow(Icons.place_outlined, event.location!),
                  ],
                  if (event.description != null && event.description!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('About this event', style: AppTextStyles.h3),
                    const SizedBox(height: 8),
                    Text(event.description!, style: AppTextStyles.bodyLarge),
                  ],
                  const SizedBox(height: 28),
                  // ── RSVP ─────────────────────────────────────────────
                  Text('Are you going?', style: AppTextStyles.h3),
                  const SizedBox(height: 12),
                  rsvpAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (rsvp) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _RsvpButton(
                              label: '✅  Going',
                              count: rsvp.goingCount,
                              selected: rsvp.myStatus == 'going',
                              color: AppColors.primaryGreen,
                              onTap: () => setRsvp(ref, event.id, 'going'),
                            ),
                            const SizedBox(width: 8),
                            _RsvpButton(
                              label: '⭐  Interested',
                              count: rsvp.interestedCount,
                              selected: rsvp.myStatus == 'interested',
                              color: AppColors.primaryGold,
                              onTap: () => setRsvp(ref, event.id, 'interested'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _RsvpButton(
                          label: "❌  Can't Attend",
                          count: 0,
                          selected: rsvp.myStatus == 'not_going',
                          color: AppColors.textSecondary,
                          onTap: () => setRsvp(ref, event.id, 'not_going'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _infoRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTextStyles.body),
          ),
        ],
      );
}

// ── RSVP button widget ────────────────────────────────────────────────────────
class _RsvpButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RsvpButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: selected ? color : AppColors.textSecondary,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

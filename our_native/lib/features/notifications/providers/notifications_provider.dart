import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supabase_service.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../models/app_notification.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class NotificationsState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
  }) =>
      NotificationsState(
        notifications: notifications ?? this.notifications,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class NotificationsNotifier extends Notifier<NotificationsState> {
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;

  @override
  NotificationsState build() {
    ref.onDispose(() => _realtimeSub?.cancel());
    // Kick off load after first build
    Future.microtask(_load);
    return const NotificationsState(isLoading: true);
  }

  Future<void> _load() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) {
      state = const NotificationsState();
      return;
    }

    try {
      final rows = await supabase
          .from('notifications')
          .select()
          .eq('recipient_id', profile.id)
          .order('created_at', ascending: false)
          .limit(50);

      final items = (rows as List)
          .map((r) => AppNotification.fromJson(r as Map<String, dynamic>))
          .toList();

      state = NotificationsState(notifications: items);
      _subscribeRealtime(profile.id);
    } catch (e) {
      state = NotificationsState(error: e.toString());
    }
  }

  void _subscribeRealtime(String profileId) {
    _realtimeSub?.cancel();
    _realtimeSub = supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', profileId)
        .order('created_at', ascending: false)
        .limit(50)
        .listen((rows) {
          final items = rows
              .map((r) => AppNotification.fromJson(r))
              .toList();
          state = state.copyWith(notifications: items);
        });
  }

  Future<void> markRead(String notificationId) async {
    // Optimistic update
    final updated = state.notifications.map((n) {
      return n.id == notificationId ? n.copyWith(isRead: true) : n;
    }).toList();
    state = state.copyWith(notifications: updated);

    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllRead() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile?.communityId == null) return;

    // Optimistic update
    final updated = state.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    state = state.copyWith(notifications: updated);

    await supabase.rpc('mark_all_notifications_read', params: {
      'p_community_id': profile!.communityId,
    });
  }

  Future<void> delete(String notificationId) async {
    final updated =
        state.notifications.where((n) => n.id != notificationId).toList();
    state = state.copyWith(notifications: updated);

    await supabase.from('notifications').delete().eq('id', notificationId);
  }

  Future<void> refresh() => _load();
}

// ── Providers ─────────────────────────────────────────────────────────────────

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
  NotificationsNotifier.new,
);

/// Convenience: just the unread count for the badge
final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});

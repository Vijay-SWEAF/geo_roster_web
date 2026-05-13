import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/app_notification.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundIvory,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundIvory,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.divider,
        title: Text('Notifications', style: AppTextStyles.h2),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              child: Text(
                'Mark all read',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, NotificationsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text('Could not load notifications',
                style: AppTextStyles.body),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text('No notifications yet', style: AppTextStyles.bodyLarge),
            const SizedBox(height: 4),
            Text('You\'ll be notified about comments,\nevents, and post updates.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.notifications.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, index) {
          final notif = state.notifications[index];
          return _NotificationTile(
            notification: notif,
            onTap: () => _handleTap(context, ref, notif),
            onDismiss: () =>
                ref.read(notificationsProvider.notifier).delete(notif.id),
          );
        },
      ),
    );
  }

  void _handleTap(
      BuildContext context, WidgetRef ref, AppNotification notif) {
    if (!notif.isRead) {
      ref.read(notificationsProvider.notifier).markRead(notif.id);
    }

    // Navigate to the related entity
    if (notif.entityId == null) return;

    switch (notif.entityType) {
      case 'post':
        context.push('/posts/${notif.entityId}');
        break;
      case 'event':
        context.push('/events/${notif.entityId}');
        break;
      default:
        break;
    }
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDismiss(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: isUnread
              ? AppColors.primaryGreen.withValues(alpha: 0.06)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(notification.createdAt),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final (icon, color) = switch (notification.type) {
      NotificationType.commentOnPost => (Icons.comment_rounded, AppColors.info),
      NotificationType.rsvpOnEvent =>
        (Icons.event_available_rounded, AppColors.success),
      NotificationType.postApproved =>
        (Icons.check_circle_rounded, AppColors.success),
      NotificationType.postRejected =>
        (Icons.cancel_rounded, AppColors.error),
      NotificationType.commentApproved =>
        (Icons.check_circle_outline_rounded, AppColors.success),
      NotificationType.commentRejected =>
        (Icons.highlight_off_rounded, AppColors.error),
      NotificationType.unknown =>
        (Icons.notifications_rounded, AppColors.textHint),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

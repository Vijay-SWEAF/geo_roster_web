import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../features/events/models/event.dart';
import '../utils/app_utils.dart';

class EventListCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  const EventListCard({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        leading: Text(event.eventType?.emoji ?? '🗓️', style: const TextStyle(fontSize: 28)),
        title: Text(event.title, style: AppTextStyles.body),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.primaryGreen),
                const SizedBox(width: 4),
                Text(AppUtils.formatDate(event.eventDate), style: AppTextStyles.caption.copyWith(color: AppColors.primaryGreen)),
              ],
            ),
            if (event.location != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(event.location!, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

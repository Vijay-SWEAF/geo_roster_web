import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_utils.dart';
import '../../features/events/models/event.dart';

class UpcomingEventBanner extends StatelessWidget {
  final Event event;
  const UpcomingEventBanner({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGreen, Color(0xFF1B4332)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next Up', style: AppTextStyles.label.copyWith(color: AppColors.textOnDark)),
          const SizedBox(height: 8),
          Text(event.title, style: AppTextStyles.h2.copyWith(color: AppColors.textOnDark)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.accentGold),
              const SizedBox(width: 6),
              Text(AppUtils.formatDate(event.eventDate), style: AppTextStyles.bodySmall.copyWith(color: AppColors.accentGold)),
            ],
          ),
          if (event.location != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textOnDark),
                const SizedBox(width: 6),
                Text(event.location!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textOnDark)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

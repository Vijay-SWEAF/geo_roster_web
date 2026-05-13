import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class WelcomeBanner extends StatelessWidget {
  final String communityLabel;
  const WelcomeBanner({super.key, required this.communityLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGreen, Color(0xFF1B4332)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning 🙏',
                  style: AppTextStyles.h3.copyWith(color: AppColors.textOnDark),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome to $communityLabel',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textOnDark.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.wb_sunny_outlined,
              color: AppColors.accentGold, size: 36),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? seeAllRoute;
  final VoidCallback? onSeeAll;
  const SectionHeader({
    super.key,
    required this.title,
    this.seeAllRoute,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.h2),
          if (seeAllRoute != null || onSeeAll != null)
            TextButton(
              onPressed: onSeeAll ?? () {
                if (seeAllRoute != null) {
                  Navigator.pushNamed(context, seeAllRoute!);
                }
              },
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text('See all',
                  style: AppTextStyles.label.copyWith(color: AppColors.primaryGreen)),
            ),
        ],
      ),
    );
  }
}

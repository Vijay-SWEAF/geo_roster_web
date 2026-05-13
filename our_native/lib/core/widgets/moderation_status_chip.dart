import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/posts/models/post.dart';

/// Chip showing moderation status of a post.
class ModerationStatusChip extends StatelessWidget {
  final PostStatus status;
  const ModerationStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: _color),
          const SizedBox(width: 4),
          Text(
            _label,
            style: AppTextStyles.labelSmall
                .copyWith(color: _color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String get _label {
    switch (status) {
      case PostStatus.draft:         return 'Draft';
      case PostStatus.pendingReview: return 'Pending Review';
      case PostStatus.approved:      return 'Approved';
      case PostStatus.rejected:      return 'Rejected';
      case PostStatus.hidden:        return 'Hidden';
      case PostStatus.reported:      return 'Reported';
    }
  }

  Color get _color {
    switch (status) {
      case PostStatus.draft:         return AppColors.textHint;
      case PostStatus.pendingReview: return AppColors.warning;
      case PostStatus.approved:      return AppColors.success;
      case PostStatus.rejected:      return AppColors.error;
      case PostStatus.hidden:        return AppColors.textSecondary;
      case PostStatus.reported:      return AppColors.accentMaroon;
    }
  }

  IconData get _icon {
    switch (status) {
      case PostStatus.draft:         return Icons.edit_outlined;
      case PostStatus.pendingReview: return Icons.hourglass_top_rounded;
      case PostStatus.approved:      return Icons.check_circle_outline;
      case PostStatus.rejected:      return Icons.cancel_outlined;
      case PostStatus.hidden:        return Icons.visibility_off_outlined;
      case PostStatus.reported:      return Icons.flag_outlined;
    }
  }
}

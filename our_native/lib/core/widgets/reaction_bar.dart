import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/posts/models/post.dart';

/// Reaction bar shown on every post card.
class ReactionBar extends StatelessWidget {
  final ReactionType? currentReaction;
  final void Function(ReactionType reaction)? onReactionSelected;

  const ReactionBar({
    super.key,
    this.currentReaction,
    this.onReactionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showReactionPicker(context),
      onLongPress: () => _showReactionPicker(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentReaction?.emoji ?? '🙏',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 4),
          Text(
            currentReaction?.label ?? 'Respect',
            style: AppTextStyles.bodySmall.copyWith(
              color: currentReaction != null
                  ? AppColors.primaryGreen
                  : AppColors.textSecondary,
              fontWeight: currentReaction != null
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  void _showReactionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundIvory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share your feeling', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ReactionType.values.map((r) {
                final isSelected = currentReaction == r;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onReactionSelected?.call(r);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGreen.withValues(alpha: 0.12)
                          : AppColors.backgroundBeige,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : AppColors.divider,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.emoji,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Text(r.label, style: AppTextStyles.label),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

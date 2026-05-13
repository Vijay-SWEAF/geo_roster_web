import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class LanguagePickerScreen extends ConsumerWidget {
  const LanguagePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundIvory,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.translate_rounded,
                  size: 40,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 28),
              // Heading — bilingual
              Text(
                'भाषा निवडा',
                style: AppTextStyles.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your language',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Marathi option
              _LangOption(
                flag: '🇮🇳',
                name: 'मराठी',
                subtitle: 'Marathi',
                isSelected: currentLocale.languageCode == 'mr',
                onTap: () async {
                  if (currentLocale.languageCode != 'mr') {
                    await ref.read(localeProvider.notifier).setLocale('mr');
                  }
                },
              ),
              const SizedBox(height: 14),
              // English option
              _LangOption(
                flag: '🇬🇧',
                name: 'English',
                subtitle: 'इंग्रजी',
                isSelected: currentLocale.languageCode == 'en',
                onTap: () async {
                  if (currentLocale.languageCode != 'en') {
                    await ref.read(localeProvider.notifier).setLocale('en');
                  }
                },
              ),
              const Spacer(),
              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (context.mounted) context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    currentLocale.languageCode == 'mr'
                        ? 'पुढे चला'
                        : 'Continue',
                    style: AppTextStyles.button,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                currentLocale.languageCode == 'mr'
                    ? 'तुम्ही नंतर प्रोफाइल सेटिंग्जमध्ये बदलू शकता.'
                    : 'You can change this anytime in profile settings.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String flag;
  final String name;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LangOption({
    required this.flag,
    required this.name,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.10)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.label),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primaryGreen, size: 24)
            else
              const Icon(Icons.radio_button_unchecked,
                  color: AppColors.divider, size: 24),
          ],
        ),
      ),
    );
  }
}

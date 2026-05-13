import 'package:flutter/material.dart';
import 'app_colors.dart';

// TiroMarathi  → headings, onboarding titles, quotes (emotional, literary)
// Mukta        → body, buttons, labels (readable, warm, Devanagari-perfect)

const _tiro = 'TiroMarathi';
const _mukta = 'Mukta';

class AppTextStyles {
  AppTextStyles._();

  // ── Display / Onboarding headings (Tiro Devanagari Marathi) ──────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _tiro,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _tiro,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  // ── Headings (Tiro) ───────────────────────────────────────────────────────
  static const TextStyle h1 = TextStyle(
    fontFamily: _tiro,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _tiro,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: _tiro,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ── Body (Mukta) ──────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _mukta,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.6,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _mukta,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.6,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _mukta,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // ── Labels (Mukta) ────────────────────────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _mukta,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _mukta,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _mukta,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textHint,
    letterSpacing: 0.5,
  );

  // ── Caption (Mukta) ───────────────────────────────────────────────────────
  static const TextStyle caption = TextStyle(
    fontFamily: _mukta,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
    height: 1.4,
  );

  // ── Button (Mukta) ────────────────────────────────────────────────────────
  static const TextStyle button = TextStyle(
    fontFamily: _mukta,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  // ── Quote / Elder Wisdom (Tiro italic) ───────────────────────────────────
  static const TextStyle quote = TextStyle(
    fontFamily: _tiro,
    fontSize: 17,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.7,
  );
}

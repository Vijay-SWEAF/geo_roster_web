import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/app_localizations_en.dart';
import '../../../core/l10n/app_localizations_mr.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

// ── Film grain overlay ────────────────────────────────────────────────────
class _FilmGrainPainter extends CustomPainter {
  const _FilmGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..strokeWidth = 1;
    const grainCount = 12000;
    for (int i = 0; i < grainCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final bright = rng.nextBool();
      final opacity = rng.nextDouble() * 0.18 + 0.04;
      paint.color = (bright ? Colors.white : Colors.black).withValues(alpha: opacity);
      final radius = rng.nextDouble() * 0.9 + 0.4;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_FilmGrainPainter old) => false;
}

class _FilmGrainOverlay extends StatelessWidget {
  const _FilmGrainOverlay();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _FilmGrainPainter(),
      child: const SizedBox.expand(),
    );
  }
}
// ────────────────────────────────────────────────────────────────────────────

// ── Edge scratches overlay ────────────────────────────────────────────────
class _EdgeScratchPainter extends CustomPainter {
  const _EdgeScratchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final w = size.width;
    final h = size.height;

    // Each scratch: a thin jagged polyline near an edge
    void drawScratch({
      required Offset start,
      required Offset direction,    // unit vector along the edge
      required Offset inward,       // unit vector pointing into the screen
      required double length,
      required double depth,
      required double opacity,
    }) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..strokeWidth = rng.nextDouble() * 0.8 + 0.3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(start.dx, start.dy);
      double traveled = 0;
      Offset cur = start;
      while (traveled < length) {
        final step = rng.nextDouble() * 6 + 3;
        final jitter = (rng.nextDouble() - 0.5) * depth * 2;
        final next = Offset(
          cur.dx + direction.dx * step + inward.dx * jitter,
          cur.dy + direction.dy * step + inward.dy * jitter,
        );
        path.lineTo(next.dx, next.dy);
        cur = next;
        traveled += step;
      }
      canvas.drawPath(path, paint);
    }

    // Left edge — 6 scratches
    for (int i = 0; i < 6; i++) {
      final y = rng.nextDouble() * h;
      final len = rng.nextDouble() * 60 + 30;
      final depth = rng.nextDouble() * 8 + 4;
      final opacity = rng.nextDouble() * 0.22 + 0.08;
      drawScratch(
        start: Offset(rng.nextDouble() * 6, y),
        direction: const Offset(0, 1),
        inward: const Offset(1, 0),
        length: len,
        depth: depth,
        opacity: opacity,
      );
    }

    // Right edge — 6 scratches
    for (int i = 0; i < 6; i++) {
      final y = rng.nextDouble() * h;
      final len = rng.nextDouble() * 60 + 30;
      final depth = rng.nextDouble() * 8 + 4;
      final opacity = rng.nextDouble() * 0.22 + 0.08;
      drawScratch(
        start: Offset(w - rng.nextDouble() * 6, y),
        direction: const Offset(0, 1),
        inward: const Offset(-1, 0),
        length: len,
        depth: depth,
        opacity: opacity,
      );
    }

    // Top edge — 5 scratches
    for (int i = 0; i < 5; i++) {
      final x = rng.nextDouble() * w;
      final len = rng.nextDouble() * 50 + 25;
      final depth = rng.nextDouble() * 6 + 3;
      final opacity = rng.nextDouble() * 0.20 + 0.08;
      drawScratch(
        start: Offset(x, rng.nextDouble() * 6),
        direction: const Offset(1, 0),
        inward: const Offset(0, 1),
        length: len,
        depth: depth,
        opacity: opacity,
      );
    }

    // Bottom edge — 5 scratches
    for (int i = 0; i < 5; i++) {
      final x = rng.nextDouble() * w;
      final len = rng.nextDouble() * 50 + 25;
      final depth = rng.nextDouble() * 6 + 3;
      final opacity = rng.nextDouble() * 0.20 + 0.08;
      drawScratch(
        start: Offset(x, h - rng.nextDouble() * 6),
        direction: const Offset(1, 0),
        inward: const Offset(0, -1),
        length: len,
        depth: depth,
        opacity: opacity,
      );
    }

    // Corner vignette darkening
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.35),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vignettePaint);
  }

  @override
  bool shouldRepaint(_EdgeScratchPainter old) => false;
}

class _EdgeScratchOverlay extends StatelessWidget {
  const _EdgeScratchOverlay();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _EdgeScratchPainter(),
      child: const SizedBox.expand(),
    );
  }
}
// ────────────────────────────────────────────────────────────────────────────

class _OnboardingPage {
  final String title;
  final String subtitle;
  final String titleEn;
  final String subtitleEn;
  final String body;
  final IconData icon;
  final Color bgColor;
  final String? imagePath;
  final BlendMode imageBlend;
  final double imageOpacity;
  final double imageBottom;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.titleEn,
    required this.subtitleEn,
    required this.body,
    required this.icon,
    required this.bgColor,
    this.imagePath,
    this.imageBlend = BlendMode.srcOver,
    this.imageOpacity = 0.22,
    this.imageBottom = 80,
  });
}

// Always bilingual: Marathi primary, English secondary — independent of locale toggle.
final _mr = AppL10nMr();
final _en = AppL10nEn();

List<_OnboardingPage> _buildPages(AppL10n _) => [
  _OnboardingPage(
    title: _mr.onboarding1Title,
    subtitle: _mr.onboarding1Subtitle,
    titleEn: _en.onboarding1Title,
    subtitleEn: _en.onboarding1Subtitle,
    body: '',
    icon: Icons.photo_album_rounded,
    bgColor: AppColors.primaryGreen,
    imagePath: 'playstore/1st_screen_transparent.png',
    imageBlend: BlendMode.srcOver,
    imageOpacity: 0.9,
    imageBottom: 160,
  ),
  _OnboardingPage(
    title: _mr.onboarding2Title,
    subtitle: _mr.onboarding2Subtitle,
    titleEn: _en.onboarding2Title,
    subtitleEn: _en.onboarding2Subtitle,
    body: '',
    icon: Icons.favorite_rounded,
    bgColor: AppColors.primaryBrown,
    imagePath: 'playstore/2nd_screen_transparent.png',
    imageBlend: BlendMode.srcOver,
    imageOpacity: 0.9,
    imageBottom: 180,
  ),
  _OnboardingPage(
    title: _mr.onboarding3Title,
    subtitle: _mr.onboarding3Subtitle,
    titleEn: _en.onboarding3Title,
    subtitleEn: _en.onboarding3Subtitle,
    body: '',
    icon: Icons.auto_stories_rounded,
    bgColor: const Color(0xFF3B2F1E),
    imagePath: 'playstore/screen3_transparent.png',
    imageBlend: BlendMode.srcOver,
    imageOpacity: 0.9,
  ),
  _OnboardingPage(
    title: _mr.onboarding4Title,
    subtitle: _mr.onboarding4Subtitle,
    titleEn: _en.onboarding4Title,
    subtitleEn: _en.onboarding4Subtitle,
    body: '',
    icon: Icons.handshake_rounded,
    bgColor: const Color(0xFF5A3E2B),
    imagePath: 'playstore/3rd_screen_transparent.png',
    imageBlend: BlendMode.srcOver,
    imageOpacity: 0.9,
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  late List<_OnboardingPage> _localizedPages;

  void _onNext() {
    if (_currentPage < _localizedPages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    if (mounted) context.go('/language-picker');
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _localizedPages = _buildPages(AppL10n.of(context));
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _localizedPages.length,
            itemBuilder: (_, i) => _OnboardingPageWidget(page: _localizedPages[i]),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final isLast = _currentPage == _localizedPages.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dots indicator — left side
          Row(
            children: List.generate(
              _localizedPages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _currentPage ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.textOnDark.withValues(
                    alpha: i == _currentPage ? 1.0 : 0.4,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          // Action buttons — right side
          Row(
            children: [
              if (!isLast)
                GestureDetector(
                  onTap: _finishOnboarding,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: AppColors.textOnDark.withValues(alpha: 0.7),
                      size: 22,
                    ),
                  ),
                ),
              if (!isLast) const SizedBox(width: 12),
              GestureDetector(
                onTap: _onNext,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.textOnDark,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    color: AppColors.primaryGreen,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageWidget extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageWidget({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: page.bgColor,
      child: Stack(
        children: [
          // Background illustration anchored to bottom
          if (page.imagePath != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: page.imageBottom,
              child: Opacity(
                opacity: page.imageOpacity,
                child: Image.asset(
                  page.imagePath!,
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          // Film grain vintage overlay
          const Positioned.fill(child: _FilmGrainOverlay()),
          // Edge scratches vintage overlay
          const Positioned.fill(child: _EdgeScratchOverlay()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Marathi block (primary) ──────────────────
                            Text(
                              page.title,
                              style: AppTextStyles.displayMedium
                                  .copyWith(color: AppColors.textOnDark),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              page.subtitle,
                              style: AppTextStyles.bodyLarge.copyWith(
                                  color: AppColors.textOnDark
                                      .withValues(alpha: 0.85)),
                            ),
                            const SizedBox(height: 20),
                            // ── Divider ───────────────────────────────────
                            Container(
                              height: 1,
                              width: 48,
                              color: AppColors.textOnDark.withValues(alpha: 0.25),
                            ),
                            const SizedBox(height: 16),
                            // ── English block (secondary) ─────────────────
                            Text(
                              page.titleEn,
                              style: AppTextStyles.h3.copyWith(
                                color: AppColors.textOnDark.withValues(alpha: 0.6),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              page.subtitleEn,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textOnDark.withValues(alpha: 0.45),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            if (page.body.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                page.body,
                                style: AppTextStyles.body.copyWith(
                                    color: AppColors.textOnDark
                                        .withValues(alpha: 0.7)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(page.icon, size: 44, color: Colors.white),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
        ],
      ),
    );
  }
}

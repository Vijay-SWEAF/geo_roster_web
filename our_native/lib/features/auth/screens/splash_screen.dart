import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/supabase_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final isLoggedIn = SupabaseService.instance.isAuthenticated;

    if (isLoggedIn) {
      context.go('/home');
    } else {
      // Always show full onboarding flow on every launch.
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Reserve 38% of screen height for the illustration — fits all screen sizes
    final imageHeight = screenHeight * 0.38;

    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: Column(
        children: [
          // ── Center section: logo, title, tagline, loader ──────────
          Expanded(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: Image.asset(
                          'playstore/app_icon_green.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Our Native',
                        style: AppTextStyles.displayLarge.copyWith(
                          color: AppColors.textOnDark,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Preserve roots. Rebuild bonds.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textOnDark.withValues(alpha: 0.85),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.textOnDark.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Bottom: village landscape illustration ────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding + 16),
              child: SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Image.asset(
                  'playstore/main_screen.png',
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

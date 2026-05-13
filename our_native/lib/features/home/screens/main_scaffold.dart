import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/user_profile_provider.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  static const _tabPaths = ['/home', '/memories', '/help', '/events', '/profile'];
  static const _tabIcons = [
    Icons.home_outlined, Icons.photo_album_outlined,
    Icons.volunteer_activism_outlined, Icons.event_outlined, Icons.person_outline,
  ];
  static const _tabActiveIcons = [
    Icons.home_rounded, Icons.photo_album_rounded,
    Icons.volunteer_activism, Icons.event_rounded, Icons.person_rounded,
  ];

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  // FAB drag position (distance from right/bottom edges)
  double _fabRight = 16;
  double _fabBottom = 90;

  List<_NavTab> _buildTabs(AppL10n l10n) => [
    _NavTab(label: l10n.tabHome,    icon: MainScaffold._tabIcons[0], activeIcon: MainScaffold._tabActiveIcons[0], path: MainScaffold._tabPaths[0]),
    _NavTab(label: l10n.memories,   icon: MainScaffold._tabIcons[1], activeIcon: MainScaffold._tabActiveIcons[1], path: MainScaffold._tabPaths[1]),
    _NavTab(label: l10n.help,       icon: MainScaffold._tabIcons[2], activeIcon: MainScaffold._tabActiveIcons[2], path: MainScaffold._tabPaths[2]),
    _NavTab(label: l10n.events,     icon: MainScaffold._tabIcons[3], activeIcon: MainScaffold._tabActiveIcons[3], path: MainScaffold._tabPaths[3]),
    _NavTab(label: l10n.profile,    icon: MainScaffold._tabIcons[4], activeIcon: MainScaffold._tabActiveIcons[4], path: MainScaffold._tabPaths[4]),
  ];

  int _currentIndex(String location) {
    if (location.startsWith('/memories')) return 1;
    if (location.startsWith('/help'))     return 2;
    if (location.startsWith('/events'))   return 3;
    if (location.startsWith('/profile'))  return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _currentIndex(location);
    final tabs = _buildTabs(AppL10n.of(context));
    final profile = ref.watch(userProfileProvider).asData?.value;
    final isApproved = profile?.isApproved ?? false;
    final showFab = currentIndex <= 1 && isApproved;
    final destination = currentIndex == 1 ? '/memories/create' : '/create-post';

    return Stack(
      children: [
        Scaffold(
          body: widget.child,
          bottomNavigationBar: _buildBottomNav(context, currentIndex, tabs),
        ),
        if (showFab)
          Positioned(
            right: _fabRight,
            bottom: _fabBottom,
            child: GestureDetector(
              onPanUpdate: (details) {
                final size = MediaQuery.of(context).size;
                setState(() {
                  _fabRight = (_fabRight - details.delta.dx)
                      .clamp(8.0, size.width - 72.0);
                  _fabBottom = (_fabBottom - details.delta.dy)
                      .clamp(88.0, size.height - 140.0);
                });
              },
              child: FloatingActionButton(
                onPressed: () => context.push(destination),
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 6,
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex, List<_NavTab> tabs) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundIvory,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final isActive = i == currentIndex;
              return _NavItem(
                tab: tab,
                isActive: isActive,
                onTap: () => context.go(tab.path),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}

class _NavItem extends StatelessWidget {
  final _NavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryGreen.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isActive ? tab.activeIcon : tab.icon,
                color: isActive ? AppColors.primaryGreen : AppColors.textHint,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isActive ? AppColors.primaryGreen : AppColors.textHint,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

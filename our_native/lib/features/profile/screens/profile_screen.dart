import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_localizations.dart';
import 'edit_profile_screen.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_profile_provider.dart';
import 'package:go_router/go_router.dart';

// Provider for real post/memory/help counts
final _profileStatsProvider =
    FutureProvider<(int posts, int memories, int helped)>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  if (profile == null) return (0, 0, 0);

  final rows = await supabase
      .from('posts')
      .select('post_type')
      .eq('author_id', profile.id)
      .eq('status', 'approved');

  int posts = 0, memories = 0, helped = 0;
  for (final raw in rows as List) {
    final type = (raw as Map)['post_type'] as String? ?? '';
    posts++;
    if (type == 'memory') memories++;
    if (type == 'help_request') helped++;
  }
  return (posts, memories, helped);
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final displayName = profile?.fullName ?? 'Community Member';
    final role = profile?.role.name ?? 'member';
    final communityLabel = profile?.nativeVillage ?? 'Unassigned community';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppL10n.of(context).myProfile),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
            tooltip: AppL10n.of(context).edit,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildProfileHeader(
            context,
            displayName,
            user?.email ?? 'No email',
            communityLabel,
            role,
            profile?.profilePhotoUrl,
          ),
          const SizedBox(height: 8),
          _buildStatsRow(ref),
          const Divider(height: 28),
          _buildMenuSection(context, ref),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    String name,
    String email,
    String communityLabel,
    String role,
    String? profilePhotoUrl,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      color: AppColors.surfaceCard,
      child: Row(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
            backgroundImage: profilePhotoUrl != null
                ? CachedNetworkImageProvider(profilePhotoUrl)
                : null,
            child: profilePhotoUrl == null
                ? const Icon(Icons.person_rounded,
                    size: 46, color: AppColors.primaryGreen)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.h2),
                const SizedBox(height: 3),
                Text(email,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 3),
                Text(
                  communityLabel,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                    child: Text(
                      role[0].toUpperCase() + role.substring(1),
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
            child: Text(AppL10n.of(context).edit),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(WidgetRef ref) {
    return Builder(builder: (context) {
      final l10n = AppL10n.of(context);
      final statsAsync = ref.watch(_profileStatsProvider);
      final (posts, memories, helped) =
          statsAsync.asData?.value ?? (0, 0, 0);
      final stats = [
        (l10n.posts, '$posts'),
        (l10n.memories, '$memories'),
        (l10n.helped, '$helped'),
      ];
      return Container(
        color: AppColors.surfaceCard,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: stats.map((s) {
            return Expanded(
              child: Column(
                children: [
                  Text(s.$2,
                      style: AppTextStyles.h2
                          .copyWith(color: AppColors.primaryGreen)),
                  const SizedBox(height: 3),
                  Text(s.$1, style: AppTextStyles.caption),
                ],
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final isAdmin = profile?.role.name == 'admin' || profile?.role.name == 'moderator';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(AppL10n.of(context).account, style: AppTextStyles.label),
        ),
        const SizedBox(height: 8),
        _MenuItem(
          icon: Icons.photo_album_outlined,
          label: AppL10n.of(context).myMemories,
          onTap: () => context.push('/memories'),
        ),
        _MenuItem(
          icon: Icons.volunteer_activism_outlined,
          label: AppL10n.of(context).myHelpPosts,
          onTap: () => context.push('/help'),
        ),
        _MenuItem(
          icon: Icons.event_outlined,
          label: AppL10n.of(context).savedEvents,
          onTap: () => context.push('/events'),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(AppL10n.of(context).settings, style: AppTextStyles.label),
        ),
        const SizedBox(height: 8),
        _MenuItem(
          icon: Icons.people_outline_rounded,
          label: 'People in my village',
          onTap: () => context.push('/people'),
        ),
        _MenuItem(
          icon: Icons.language_outlined,
          label: AppL10n.of(context).language,
          subtitle: ref.watch(localeProvider).languageCode == 'mr'
              ? 'मराठी → English'
              : 'English → मराठी',
          onTap: () => ref.read(localeProvider.notifier).toggle(),
        ),
        _MenuItem(
          icon: Icons.notifications_outlined,
          label: AppL10n.of(context).notifications,
          onTap: () => context.push('/notifications'),
        ),
        _MenuItem(
          icon: Icons.lock_outline,
          label: AppL10n.of(context).privacy,
          onTap: () {},
        ),
        if (isAdmin) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Admin', style: AppTextStyles.label),
          ),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Admin Panel',
            onTap: () => context.push('/admin'),
          ),
          _MenuItem(
            icon: Icons.pending_actions_outlined,
            label: 'Pending Posts',
            onTap: () => context.push('/admin/pending-posts'),
          ),
          _MenuItem(
            icon: Icons.person_add_alt_1_outlined,
            label: 'Pending Member Approvals',
            onTap: () => context.push('/admin/pending-approvals'),
          ),
        ],
        const Divider(),
        _MenuItem(
          icon: Icons.logout_rounded,
          label: AppL10n.of(context).signOut,
          iconColor: AppColors.error,
          labelColor: AppColors.error,
          onTap: () => _confirmSignOut(context, ref),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.read(authProvider.notifier);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppL10n.of(dialogContext).signOutTitle, style: AppTextStyles.h3),
        content: Text(AppL10n.of(dialogContext).signOutConfirm,
            style: AppTextStyles.body),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppL10n.of(dialogContext).cancel)),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await Future<void>.delayed(Duration.zero);
              await authNotifier.signOut();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: Text(AppL10n.of(dialogContext).signOut),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.primaryGreen),
      title: Text(label,
          style: AppTextStyles.body
              .copyWith(color: labelColor ?? AppColors.textPrimary)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTextStyles.caption)
          : null,
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textHint, size: 20),
      onTap: onTap,
    );
  }
}

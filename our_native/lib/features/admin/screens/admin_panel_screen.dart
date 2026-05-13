import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/user_profile_provider.dart';
import 'pending_approvals_screen.dart';

// ---------------------------------------------------------------------------
// Badge count providers (live from DB)
// ---------------------------------------------------------------------------

final _pendingPostCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final communityId = ref.watch(currentCommunityIdProvider);
  if (communityId == null) return 0;
  final result = await supabase.rpc(
    'pending_post_count',
    params: {'p_community_id': communityId},
  );
  return (result as int?) ?? 0;
});

final _pendingCommentCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final communityId = ref.watch(currentCommunityIdProvider);
  if (communityId == null) return 0;
  final result = await supabase.rpc(
    'pending_comment_count',
    params: {'p_community_id': communityId},
  );
  return (result as int?) ?? 0;
});

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingMembersCount =
        ref.watch(pendingMembersProvider).asData?.value.length;
    final pendingPostsCount =
        ref.watch(_pendingPostCountProvider).asData?.value;
    final pendingCommentsCount =
        ref.watch(_pendingCommentCountProvider).asData?.value;

    String? badge(int? count) =>
        (count != null && count > 0) ? '$count' : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: AppColors.primaryBrown,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings_outlined,
                    color: AppColors.error),
                const SizedBox(width: 12),
                Text('Restricted — Admin & Moderators Only',
                    style: AppTextStyles.label.copyWith(color: AppColors.error)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _AdminSection(
            title: 'Moderation',
            items: [
              _AdminItem(
                  icon: Icons.pending_outlined,
                  label: 'Pending Posts',
                  badge: badge(pendingPostsCount),
                  onTap: () => context.push('/admin/pending-posts')),
              _AdminItem(
                  icon: Icons.comment_outlined,
                  label: 'Pending Comments',
                  badge: badge(pendingCommentsCount),
                  onTap: () => context.push('/admin/pending-comments')),
              _AdminItem(
                  icon: Icons.flag_outlined,
                  label: 'Reported Content',
                  badge: null,
                  onTap: () => _comingSoon(context, 'Reported Content')),
            ],
          ),
          const SizedBox(height: 16),
          _AdminSection(
            title: 'Community',
            items: [
              _AdminItem(
                  icon: Icons.pending_actions_outlined,
                  label: 'Pending Members',
                  badge: badge(pendingMembersCount),
                  onTap: () => context.push('/admin/pending-approvals')),
              _AdminItem(
                  icon: Icons.people_outline,
                  label: 'Manage Members',
                  badge: null,
                  onTap: () => context.push('/people')),
              _AdminItem(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Assign Elder Role',
                  badge: null,
                  onTap: () => _showAssignRoleSheet(context, ref)),
              _AdminItem(
                  icon: Icons.announcement_outlined,
                  label: 'Post Announcement',
                  badge: null,
                  onTap: () => context.push('/create-post')),
            ],
          ),
          const SizedBox(height: 16),
          _AdminSection(
            title: 'Analytics',
            items: [
              _AdminItem(
                  icon: Icons.bar_chart_outlined,
                  label: 'Post Activity',
                  badge: null,
                  onTap: () => _comingSoon(context, 'Post Activity')),
              _AdminItem(
                  icon: Icons.trending_up_outlined,
                  label: 'Member Growth',
                  badge: null,
                  onTap: () => _comingSoon(context, 'Member Growth')),
            ],
          ),
        ],
      ),
    );
  }

  /// Bottom sheet to pick a member and assign elder role.
  Future<void> _showAssignRoleSheet(BuildContext context, WidgetRef ref) async {
    final communityId =
        ref.read(currentCommunityIdProvider);
    if (communityId == null) return;

    final data = await supabase
        .from('user_profiles')
        .select('id, full_name, role')
        .eq('community_id', communityId)
        .eq('is_approved', true)
        .order('full_name');

    final members = List<Map<String, dynamic>>.from(data as List);
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssignRoleSheet(members: members),
    );
  }
}

class _AdminSection extends StatelessWidget {
  final String title;
  final List<_AdminItem> items;
  const _AdminSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.label),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _AdminItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _AdminItem({
    required this.icon,
    required this.label,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryBrown),
      title: Text(label, style: AppTextStyles.body),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge!,
                style: AppTextStyles.caption.copyWith(color: Colors.white),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textHint, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Assign Elder Role sheet
// ---------------------------------------------------------------------------

class _AssignRoleSheet extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  const _AssignRoleSheet({required this.members});

  @override
  State<_AssignRoleSheet> createState() => _AssignRoleSheetState();
}

class _AssignRoleSheetState extends State<_AssignRoleSheet> {
  bool _saving = false;

  Future<void> _setRole(String profileId, String newRole) async {
    setState(() => _saving = true);
    try {
      await supabase
          .from('user_profiles')
          .update({'role': newRole})
          .eq('id', profileId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role updated to $newRole')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Assign Elder Role', style: AppTextStyles.h3),
          ),
          const Divider(),
          Expanded(
            child: _saving
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: widget.members.length,
                    itemBuilder: (_, i) {
                      final m = widget.members[i];
                      final role = m['role'] as String? ?? 'member';
                      final isElder = role == 'elder';
                      return ListTile(
                        title: Text(m['full_name'] as String? ?? 'Member',
                            style: AppTextStyles.body),
                        subtitle: Text(role,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary)),
                        trailing: isElder
                            ? TextButton(
                                onPressed: () =>
                                    _setRole(m['id'] as String, 'member'),
                                child: const Text('Remove Elder'),
                              )
                            : ElevatedButton(
                                onPressed: role == 'admin'
                                    ? null
                                    : () => _setRole(
                                        m['id'] as String, 'elder'),
                                child: const Text('Make Elder'),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_utils.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../people/providers/people_provider.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final pendingMembersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final communityId = ref.watch(currentCommunityIdProvider);
  if (communityId == null) return [];

  final data = await supabase
      .from('user_profiles')
      .select('id, full_name, surname, bio, phone, created_at, village_id, wadi_id, villages(name), reference_wadis(name)')
      .eq('community_id', communityId)
      .eq('is_approved', false)
      .order('created_at');

  return List<Map<String, dynamic>>.from(data as List);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PendingApprovalsScreen extends ConsumerStatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  ConsumerState<PendingApprovalsScreen> createState() =>
      _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState
    extends ConsumerState<PendingApprovalsScreen> {
  /// Tracks profile IDs that are currently being acted on.
  final _processing = <String>{};

  Future<void> _approve(String profileId) async {
    setState(() => _processing.add(profileId));
    try {
      await supabase
          .from('user_profiles')
          .update({'is_approved': true})
          .eq('id', profileId);
      if (!mounted) return;
      AppUtils.showSnack(context, 'Member approved.');
      ref.invalidate(pendingMembersProvider);
      ref.invalidate(peopleProvider);
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnack(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processing.remove(profileId));
    }
  }

  Future<void> _reject(String profileId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Member'),
        content: Text(
          'Remove $name from the pending list? This deletes their profile '
          'and they will need to re-register.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _processing.add(profileId));
    try {
      await supabase.from('user_profiles').delete().eq('id', profileId);
      if (!mounted) return;
      AppUtils.showSnack(context, 'Profile removed.');
      ref.invalidate(pendingMembersProvider);
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnack(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processing.remove(profileId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
        backgroundColor: AppColors.primaryBrown,
        foregroundColor: Colors.white,
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load: $e',
                style: AppTextStyles.body, textAlign: TextAlign.center),
          ),
        ),
        data: (members) {
          if (members.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.how_to_reg_outlined,
                      size: 56, color: AppColors.primaryGreen.withValues(alpha: 0.6)),
                  const SizedBox(height: 16),
                  Text('No pending approvals', style: AppTextStyles.h3),
                  const SizedBox(height: 4),
                  Text('All members are approved.',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingMembersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: members.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final m = members[i];
                return _PendingMemberCard(
                  profile: m,
                  isProcessing: _processing.contains(m['id'] as String),
                  onApprove: () => _approve(m['id'] as String),
                  onReject: () => _reject(
                    m['id'] as String,
                    _displayName(m),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _displayName(Map<String, dynamic> m) {
    final full = (m['full_name'] as String?) ?? '';
    final surname = (m['surname'] as String?) ?? '';
    return surname.isNotEmpty ? '$full $surname' : full;
  }
}

// ---------------------------------------------------------------------------
// Card widget
// ---------------------------------------------------------------------------

class _PendingMemberCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingMemberCard({
    required this.profile,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = (profile['full_name'] as String?) ?? '';
    final surname = (profile['surname'] as String?) ?? '';
    final name = surname.isNotEmpty ? '$fullName $surname' : fullName;
    final bio = (profile['bio'] as String?) ?? '';
    final phone = (profile['phone'] as String?) ?? '';
    final villageName =
        (profile['villages'] as Map?)?['name'] as String? ?? '';
    final wadiName =
        (profile['reference_wadis'] as Map?)?['name'] as String? ?? '';
    final createdAt = profile['created_at'] as String? ?? '';
    final joinedDate = createdAt.isNotEmpty
        ? DateTime.tryParse(createdAt)?.toLocal()
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + date chip
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryBrown.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.primaryBrown),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w600)),
                      if (joinedDate != null)
                        Text(
                          'Registered ${_formatDate(joinedDate)}',
                          style: AppTextStyles.caption,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Location row
            if (villageName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 15, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    wadiName.isNotEmpty
                        ? '$wadiName, $villageName'
                        : villageName,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],
            // Phone
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 15, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(phone, style: AppTextStyles.bodySmall),
                ],
              ),
            ],
            // Bio
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(bio,
                  style: AppTextStyles.bodySmall
                      .copyWith(fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 14),
            // Action buttons
            if (isProcessing)
              const Center(
                child: SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.person_remove_outlined, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

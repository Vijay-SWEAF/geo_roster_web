import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/models/user_profile.dart';
import '../providers/people_provider.dart';
import 'member_profile_screen.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundIvory,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundIvory,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.divider,
        title: Text('People', style: AppTextStyles.h2),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: peopleAsync.when(
              data: (people) => _buildList(people),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 40),
                    const SizedBox(height: 12),
                    Text('Could not load members',
                        style: AppTextStyles.body),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(peopleProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: 'Filter by name or location…',
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
          filled: true,
          fillColor: AppColors.backgroundBeige,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint),
          suffixIcon: _filter.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textHint),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _filter = '');
                  },
                )
              : null,
        ),
        onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
      ),
    );
  }

  Widget _buildList(List<UserProfile> people) {
    final filtered = _filter.isEmpty
        ? people
        : people.where((p) {
            final name =
                '${p.fullName} ${p.surname ?? ''}'.toLowerCase();
            final loc = (p.currentLocation ?? '').toLowerCase();
            final village = (p.nativeVillage ?? '').toLowerCase();
            return name.contains(_filter) ||
                loc.contains(_filter) ||
                village.contains(_filter);
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              _filter.isEmpty ? 'No members yet' : 'No match for "$_filter"',
              style: AppTextStyles.bodyLarge,
            ),
          ],
        ),
      );
    }

    // Group by role order: admin → moderator → elder → member
    final roleOrder = ['admin', 'moderator', 'elder', 'member'];
    final grouped = <String, List<UserProfile>>{};
    for (final role in roleOrder) {
      final group =
          filtered.where((p) => p.role.value == role).toList();
      if (group.isNotEmpty) grouped[role] = group;
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(peopleProvider),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final entry in grouped.entries) ...[
            _SectionHeader(role: entry.key, count: entry.value.length),
            ...entry.value.map((p) => _MemberTile(profile: p)),
          ],
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String role;
  final int count;
  const _SectionHeader({required this.role, required this.count});

  static const _labels = {
    'admin':     'Admins',
    'moderator': 'Moderators',
    'elder':     'Elders',
    'member':    'Members',
  };

  static const _colors = {
    'admin':     AppColors.roleAdmin,
    'moderator': AppColors.roleModerator,
    'elder':     AppColors.roleElder,
    'member':    AppColors.roleMember,
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[role] ?? role;
    final color = _colors[role] ?? AppColors.roleMember;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.h3.copyWith(color: color)),
          const SizedBox(width: 6),
          Text('($count)',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
        ],
      ),
    );
  }
}

// ── Member tile ───────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final UserProfile profile;
  const _MemberTile({required this.profile});

  static const _roleColors = {
    'admin':     AppColors.roleAdmin,
    'moderator': AppColors.roleModerator,
    'elder':     AppColors.roleElder,
    'member':    AppColors.roleMember,
  };

  @override
  Widget build(BuildContext context) {
    final displayName =
        [profile.fullName, profile.surname].where((s) => s?.isNotEmpty == true).join(' ');
    final sub = [profile.nativeVillage, profile.currentLocation]
        .where((s) => s?.isNotEmpty == true)
        .join(' · ');
    final roleColor =
        _roleColors[profile.role.value] ?? AppColors.roleMember;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MemberProfileScreen(profileId: profile.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _Avatar(profile: profile, radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: AppTextStyles.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (sub.isNotEmpty)
                    Text(sub,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textHint, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  if (profile.bio != null && profile.bio!.isNotEmpty)
                    Text(profile.bio!,
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _capitalize(profile.role.value),
                style: AppTextStyles.labelSmall.copyWith(color: roleColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Avatar widget (shared) ────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final UserProfile profile;
  final double radius;
  const _Avatar({required this.profile, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final initial = profile.fullName.isNotEmpty
        ? profile.fullName[0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.backgroundBeige,
      backgroundImage: profile.profilePhotoUrl != null
          ? CachedNetworkImageProvider(profile.profilePhotoUrl!)
          : null,
      child: profile.profilePhotoUrl == null
          ? Text(initial,
              style: AppTextStyles.h3
                  .copyWith(color: AppColors.textSecondary))
          : null,
    );
  }
}

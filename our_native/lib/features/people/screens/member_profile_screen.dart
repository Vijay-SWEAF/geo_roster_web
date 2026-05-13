import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/models/user_profile.dart';
import '../providers/people_provider.dart';

class MemberProfileScreen extends ConsumerWidget {
  final String profileId;
  const MemberProfileScreen({super.key, required this.profileId});

  static const _roleColors = {
    'admin':     AppColors.roleAdmin,
    'moderator': AppColors.roleModerator,
    'elder':     AppColors.roleElder,
    'member':    AppColors.roleMember,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(memberProfileProvider(profileId));

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: AppColors.backgroundIvory),
            backgroundColor: AppColors.backgroundIvory,
            body: Center(
              child: Text('Member not found', style: AppTextStyles.body),
            ),
          );
        }
        return _ProfileView(profile: profile);
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.backgroundIvory,
        appBar: AppBar(backgroundColor: AppColors.backgroundIvory),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        backgroundColor: AppColors.backgroundIvory,
        appBar: AppBar(backgroundColor: AppColors.backgroundIvory),
        body: Center(
          child: Text('Could not load profile', style: AppTextStyles.body),
        ),
      ),
    );
  }
}

// ── Full profile view ─────────────────────────────────────────────────────────

class _ProfileView extends ConsumerWidget {
  final UserProfile profile;
  const _ProfileView({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName =
        [profile.fullName, profile.surname].where((s) => s?.isNotEmpty == true).join(' ');
    final roleColor = MemberProfileScreen._roleColors[profile.role.value] ??
        AppColors.roleMember;
    final postsAsync = ref.watch(memberPostsProvider(profile.id));

    return Scaffold(
      backgroundColor: AppColors.backgroundIvory,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, displayName, roleColor),
          SliverToBoxAdapter(
            child: _buildInfoSection(context, displayName, roleColor),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Posts', style: AppTextStyles.h2),
            ),
          ),
          postsAsync.when(
            data: (posts) => posts.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text('No posts yet',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textHint)),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _PostSummaryTile(post: posts[i]),
                      childCount: posts.length,
                    ),
                  ),
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('Could not load posts',
                      style: AppTextStyles.bodySmall),
                ),
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(
      BuildContext context, String displayName, Color roleColor) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.backgroundIvory,
      foregroundColor: AppColors.textPrimary,
      flexibleSpace: FlexibleSpaceBar(
        background: profile.profilePhotoUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: profile.profilePhotoUrl!,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                color: roleColor.withValues(alpha: 0.1),
                child: Center(
                  child: Text(
                    profile.fullName.isNotEmpty
                        ? profile.fullName[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.displayLarge.copyWith(
                        color: roleColor.withValues(alpha: 0.5)),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInfoSection(
      BuildContext context, String displayName, Color roleColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(displayName,
                    style: AppTextStyles.h1,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: roleColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _capitalize(profile.role.value),
                  style: AppTextStyles.label.copyWith(color: roleColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.home_outlined,
            text: profile.nativeVillage,
            label: 'Native village',
          ),
          _InfoRow(
            icon: Icons.location_on_outlined,
            text: profile.currentLocation,
            label: 'Location',
          ),
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(profile.bio!,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 8),
          Text(
            'Member since ${_joinedDate(profile.createdAt)}',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textHint, fontSize: 12),
          ),
          const Divider(height: 24, color: AppColors.divider),
        ],
      ),
    );
  }

  String _joinedDate(DateTime dt) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.year}';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String? text;
  final String label;

  const _InfoRow({required this.icon, required this.text, required this.label});

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textHint),
          const SizedBox(width: 6),
          Text(text!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Post summary tile ─────────────────────────────────────────────────────────

class _PostSummaryTile extends StatelessWidget {
  final MemberPostSummary post;
  const _PostSummaryTile({required this.post});

  static const _typeIcons = {
    'memory':       Icons.photo_album_outlined,
    'story':        Icons.menu_book_outlined,
    'elder_wisdom': Icons.self_improvement_outlined,
    'help_request': Icons.volunteer_activism_outlined,
    'achievement':  Icons.emoji_events_outlined,
    'announcement': Icons.campaign_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcons[post.postType] ?? Icons.article_outlined;
    return InkWell(
      onTap: () => context.push('/posts/${post.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.backgroundBeige,
                borderRadius: BorderRadius.circular(8),
              ),
              child: post.coverImageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: post.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Icon(icon, color: AppColors.textHint, size: 20),
                      ),
                    )
                  : Icon(icon, color: AppColors.textHint, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title,
                      style: AppTextStyles.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (post.body != null && post.body!.isNotEmpty)
                    Text(post.body!,
                        style: AppTextStyles.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    timeago.format(post.createdAt),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../people/screens/member_profile_screen.dart';
import '../models/search_result.dart';
import '../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundIvory,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundIvory,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: const BackButton(),
        title: _SearchBar(
          controller: _controller,
          onChanged: (q) =>
              ref.read(searchProvider.notifier).onQueryChanged(q),
          onClear: () {
            _controller.clear();
            ref.read(searchProvider.notifier).clear();
          },
        ),
      ),
      body: Column(
        children: [
          if (state.status == SearchStatus.done && !state.results.isEmpty)
            _buildTabBar(state.results),
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildTabBar(SearchResults results) {
    return Container(
      color: AppColors.backgroundIvory,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primaryGreen,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primaryGreen,
        labelStyle: AppTextStyles.label,
        tabs: [
          Tab(text: 'Posts (${results.posts.length})'),
          Tab(text: 'Events (${results.events.length})'),
          Tab(text: 'People (${results.users.length})'),
        ],
      ),
    );
  }

  Widget _buildBody(SearchState state) {
    switch (state.status) {
      case SearchStatus.idle:
        return _buildIdle();
      case SearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case SearchStatus.error:
        return Center(
          child: Text('Search failed. Try again.',
              style: AppTextStyles.body.copyWith(color: AppColors.error)),
        );
      case SearchStatus.done:
        if (state.results.isEmpty) {
          return _buildNoResults(state.query);
        }
        return TabBarView(
          controller: _tabController,
          children: [
            _PostResultsList(posts: state.results.posts),
            _EventResultsList(events: state.results.events),
            _UserResultsList(users: state.results.users),
          ],
        );
    }
  }

  Widget _buildIdle() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('Search your village', style: AppTextStyles.bodyLarge),
          const SizedBox(height: 4),
          Text(
            'Find posts, events, and people\nby typing above.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(String query) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('No results for "$query"', style: AppTextStyles.bodyLarge),
          const SizedBox(height: 4),
          Text('Try a different keyword.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
      child: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: 'Search posts, events, people…',
          hintStyle:
              AppTextStyles.body.copyWith(color: AppColors.textHint),
          filled: true,
          fillColor: AppColors.backgroundBeige,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.textHint),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textHint),
                    onPressed: onClear,
                  )
                : const SizedBox.shrink(),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ── Post results ──────────────────────────────────────────────────────────────

class _PostResultsList extends StatelessWidget {
  final List<PostSearchResult> posts;
  const _PostResultsList({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(
          child: Text('No posts found',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: posts.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, i) => _PostTile(post: posts[i]),
    );
  }
}

class _PostTile extends StatelessWidget {
  final PostSearchResult post;
  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/posts/${post.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.coverImageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: post.coverImageUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _placeholder(),
                ),
              ),
              const SizedBox(width: 12),
            ] else ...[
              _placeholder(),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title,
                      style: AppTextStyles.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (post.body != null && post.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(post.body!,
                        style: AppTextStyles.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${post.authorName} · ${timeago.format(post.createdAt)}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.backgroundBeige,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.article_outlined,
          color: AppColors.textHint, size: 24),
    );
  }
}

// ── Event results ─────────────────────────────────────────────────────────────

class _EventResultsList extends StatelessWidget {
  final List<EventSearchResult> events;
  const _EventResultsList({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
          child: Text('No events found',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: events.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, i) => _EventTile(event: events[i]),
    );
  }
}

class _EventTile extends StatelessWidget {
  final EventSearchResult event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM y').format(event.eventDate.toLocal());
    return InkWell(
      onTap: () => context.push('/events/${event.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.event_rounded,
                  color: AppColors.primaryGreen, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: AppTextStyles.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(dateStr,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textHint, fontSize: 12)),
                      if (event.location != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppColors.textHint),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(event.location!,
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textHint, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                  if (event.description != null &&
                      event.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(event.description!,
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── User results ──────────────────────────────────────────────────────────────

class _UserResultsList extends StatelessWidget {
  final List<UserSearchResult> users;
  const _UserResultsList({required this.users});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
          child: Text('No people found',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: users.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, i) => _UserTile(user: users[i]),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserSearchResult user;
  const _UserTile({required this.user});

  static const _roleColors = {
    'admin':     AppColors.roleAdmin,
    'moderator': AppColors.roleModerator,
    'elder':     AppColors.roleElder,
  };

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColors[user.role] ?? AppColors.roleMember;
    final displayName = [user.fullName, user.surname]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    final sub = [user.nativeVillage, user.currentLocation]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MemberProfileScreen(profileId: user.profileId),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.backgroundBeige,
            backgroundImage: user.profilePhotoUrl != null
                ? CachedNetworkImageProvider(user.profilePhotoUrl!)
                : null,
            child: user.profilePhotoUrl == null
                ? Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
                  )
                : null,
          ),
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
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user.role[0].toUpperCase() + user.role.substring(1),
              style: AppTextStyles.labelSmall.copyWith(color: roleColor),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

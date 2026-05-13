import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/profile_setup_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/onboarding/screens/language_picker_screen.dart';
import '../../features/home/screens/main_scaffold.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/memories/screens/memories_screen.dart';
import '../../features/memories/screens/memory_detail_screen.dart';
import '../../features/memories/screens/create_memory_screen.dart';
import '../../features/help/screens/help_screen.dart';
import '../../features/help/screens/create_help_screen.dart';
import '../../features/events/screens/events_screen.dart';
import '../../features/events/screens/event_detail_screen.dart';
import '../../features/events/screens/create_event_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/elders/screens/elders_screen.dart';
import '../../features/stories/screens/stories_screen.dart';
import '../../features/posts/screens/create_post_screen.dart';
import '../../features/admin/screens/admin_panel_screen.dart';
import '../../features/admin/screens/pending_approvals_screen.dart';
import '../../features/admin/screens/pending_posts_screen.dart';
import '../../features/admin/screens/pending_comments_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/posts/screens/post_by_id_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/people/screens/people_screen.dart';
import '../../services/supabase_service.dart';

class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

String? resolveAppRedirect({
  required String location,
  required bool isLoggedIn,
  required bool hasCommunity,
  required bool isApproved,
}) {
  const publicRoutes = {'/splash', '/onboarding', '/language-picker', '/login'};
  const postingRoutes = {'/create-post', '/memories/create', '/help/create'};

  if (!isLoggedIn) {
    if (!publicRoutes.contains(location)) return '/login';
    return null;
  }

  if (!hasCommunity && location != '/profile-setup') {
    return '/profile-setup';
  }

  if (hasCommunity && (location == '/profile-setup' || location == '/login')) {
    return '/home';
  }

  if (!isApproved && postingRoutes.contains(location)) {
    return '/home';
  }

  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRefreshListenable(
    SupabaseService.instance.authStateChanges,
  );
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authRefresh,
    redirect: (BuildContext context, GoRouterState state) async {
      final isLoggedIn = SupabaseService.instance.isAuthenticated;
      final location = state.matchedLocation;

      // Do not block startup on profile fetch when user is logged out.
      if (!isLoggedIn) {
        return resolveAppRedirect(
          location: location,
          isLoggedIn: false,
          hasCommunity: false,
          isApproved: false,
        );
      }

      bool hasCommunity = false;
      bool isApproved = false;
      try {
        final profile = await SupabaseService.instance
            .fetchCurrentUserProfileSummary()
            .timeout(const Duration(seconds: 4));
        hasCommunity = profile?['community_id'] != null;
        isApproved = (profile?['is_approved'] as bool?) ?? false;
      } catch (_) {
        // Fail-safe: keep app responsive and route user to profile setup if needed.
        hasCommunity = false;
        isApproved = false;
      }

      return resolveAppRedirect(
        location: location,
        isLoggedIn: isLoggedIn,
        hasCommunity: hasCommunity,
        isApproved: isApproved,
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/language-picker',
        builder: (_, _) => const LanguagePickerScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (_, _) => const ProfileSetupScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const HomeScreen(),
          ),
          GoRoute(
            path: '/memories',
            builder: (_, _) => const MemoriesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    MemoryDetailScreen(postId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'create',
                builder: (_, _) => const CreateMemoryScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/help',
            builder: (_, _) => const HelpScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (_, _) => const CreateHelpScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/events',
            builder: (_, _) => const EventsScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (_, _) => const CreateEventScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    EventDetailScreen(eventId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/elders',
        builder: (_, _) => const EldersScreen(),
      ),
      GoRoute(
        path: '/stories',
        builder: (_, _) => const StoriesScreen(),
      ),
      GoRoute(
        path: '/create-post',
        builder: (_, state) {
          final type = state.uri.queryParameters['type'] ?? 'memory';
          return CreatePostScreen(postType: type);
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (_, _) => const AdminPanelScreen(),
      ),
      GoRoute(
        path: '/admin/pending-approvals',
        builder: (_, _) => const PendingApprovalsScreen(),
      ),
      GoRoute(
        path: '/admin/pending-posts',
        builder: (_, _) => const PendingPostsScreen(),
      ),
      GoRoute(
        path: '/admin/pending-comments',
        builder: (_, _) => const PendingCommentsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/posts/:id',
        builder: (_, state) =>
            PostByIdScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/search',
        builder: (_, _) => const SearchScreen(),
      ),
      GoRoute(
        path: '/people',
        builder: (_, _) => const PeopleScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});

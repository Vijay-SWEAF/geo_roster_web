import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supabase_service.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../models/search_result.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum SearchStatus { idle, loading, done, error }

class SearchState {
  final String query;
  final SearchStatus status;
  final SearchResults results;
  final String? error;

  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.results = SearchResults.empty,
    this.error,
  });

  SearchState copyWith({
    String? query,
    SearchStatus? status,
    SearchResults? results,
    String? error,
  }) =>
      SearchState(
        query:   query   ?? this.query,
        status:  status  ?? this.status,
        results: results ?? this.results,
        error:   error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SearchNotifier extends Notifier<SearchState> {
  Timer? _debounce;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      state = const SearchState();
      return;
    }

    state = state.copyWith(query: trimmed, status: SearchStatus.loading);

    _debounce = Timer(const Duration(milliseconds: 350), () => _search(trimmed));
  }

  void clear() {
    _debounce?.cancel();
    state = const SearchState();
  }

  Future<void> _search(String query) async {
    final profile = await ref.read(userProfileProvider.future);
    final communityId = profile?.communityId;
    if (communityId == null) {
      state = state.copyWith(status: SearchStatus.done, results: SearchResults.empty);
      return;
    }

    try {
      final pattern = '%$query%';

      // Run all 3 queries in parallel
      final results = await Future.wait([
        _searchPosts(communityId, pattern),
        _searchEvents(communityId, pattern),
        _searchUsers(communityId, pattern),
      ]);

      // Guard: query may have changed while we were waiting
      if (state.query != query) return;

      state = state.copyWith(
        status: SearchStatus.done,
        results: SearchResults(
          posts:  results[0] as List<PostSearchResult>,
          events: results[1] as List<EventSearchResult>,
          users:  results[2] as List<UserSearchResult>,
        ),
      );
    } catch (e) {
      if (state.query != query) return;
      state = state.copyWith(status: SearchStatus.error, error: e.toString());
    }
  }

  Future<List<PostSearchResult>> _searchPosts(
      String communityId, String pattern) async {
    final rows = await supabase
        .from('posts')
        .select(
          'id,title,body,post_type,cover_image_url,created_at,'
          'author:user_profiles!posts_author_id_fkey(full_name)',
        )
        .eq('community_id', communityId)
        .eq('status', 'approved')
        .or('title.ilike.$pattern,body.ilike.$pattern')
        .order('created_at', ascending: false)
        .limit(10);

    return (rows as List)
        .map((r) => PostSearchResult.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<EventSearchResult>> _searchEvents(
      String communityId, String pattern) async {
    final rows = await supabase
        .from('events')
        .select(
          'id,title,description,location,event_type,event_date,cover_image_url',
        )
        .eq('community_id', communityId)
        .or('title.ilike.$pattern,description.ilike.$pattern,location.ilike.$pattern')
        .order('event_date', ascending: true)
        .limit(10);

    return (rows as List)
        .map((r) => EventSearchResult.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserSearchResult>> _searchUsers(
      String communityId, String pattern) async {
    final rows = await supabase
        .from('user_profiles')
        .select(
          'id,full_name,surname,native_village,current_location,profile_photo_url,role',
        )
        .eq('community_id', communityId)
        .eq('is_approved', true)
        .or('full_name.ilike.$pattern,surname.ilike.$pattern,current_location.ilike.$pattern')
        .order('full_name', ascending: true)
        .limit(10);

    return (rows as List)
        .map((r) => UserSearchResult.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

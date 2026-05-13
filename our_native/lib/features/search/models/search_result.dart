import 'package:equatable/equatable.dart';

// ── Result types ──────────────────────────────────────────────────────────────

enum SearchResultType { post, event, user }

class PostSearchResult extends Equatable {
  final String id;
  final String title;
  final String? body;
  final String postType;
  final String? coverImageUrl;
  final String authorName;
  final DateTime createdAt;

  const PostSearchResult({
    required this.id,
    required this.title,
    this.body,
    required this.postType,
    this.coverImageUrl,
    required this.authorName,
    required this.createdAt,
  });

  factory PostSearchResult.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return PostSearchResult(
      id:             json['id'] as String,
      title:          json['title'] as String,
      body:           json['body'] as String?,
      postType:       json['post_type'] as String? ?? 'memory',
      coverImageUrl:  json['cover_image_url'] as String?,
      authorName:     author?['full_name'] as String? ?? 'Unknown',
      createdAt:      DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id];
}

class EventSearchResult extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? location;
  final String? eventType;
  final DateTime eventDate;
  final String? coverImageUrl;

  const EventSearchResult({
    required this.id,
    required this.title,
    this.description,
    this.location,
    this.eventType,
    required this.eventDate,
    this.coverImageUrl,
  });

  factory EventSearchResult.fromJson(Map<String, dynamic> json) {
    return EventSearchResult(
      id:           json['id'] as String,
      title:        json['title'] as String,
      description:  json['description'] as String?,
      location:     json['location'] as String?,
      eventType:    json['event_type'] as String?,
      eventDate:    DateTime.parse(json['event_date'] as String),
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [id];
}

class UserSearchResult extends Equatable {
  final String profileId;
  final String fullName;
  final String? surname;
  final String? nativeVillage;
  final String? currentLocation;
  final String? profilePhotoUrl;
  final String role;

  const UserSearchResult({
    required this.profileId,
    required this.fullName,
    this.surname,
    this.nativeVillage,
    this.currentLocation,
    this.profilePhotoUrl,
    this.role = 'member',
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      profileId:      json['id'] as String,
      fullName:       json['full_name'] as String,
      surname:        json['surname'] as String?,
      nativeVillage:  json['native_village'] as String?,
      currentLocation: json['current_location'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      role:           json['role'] as String? ?? 'member',
    );
  }

  @override
  List<Object?> get props => [profileId];
}

// ── Aggregate search results ──────────────────────────────────────────────────

class SearchResults {
  final List<PostSearchResult> posts;
  final List<EventSearchResult> events;
  final List<UserSearchResult> users;

  const SearchResults({
    this.posts = const [],
    this.events = const [],
    this.users = const [],
  });

  bool get isEmpty => posts.isEmpty && events.isEmpty && users.isEmpty;
  int get totalCount => posts.length + events.length + users.length;

  static const empty = SearchResults();
}

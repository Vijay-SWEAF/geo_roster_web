/// Story model for OurNative
library;

enum StoryVisibility { public, communityOnly }

class Story {
  final String id;
  final String authorId;
  final String communityId;
  final String title;
  final String? body;
  final String? audioUrl;
  final String? coverImageUrl;
  final String? languageCode;
  final String status;
  final StoryVisibility visibility;
  final int? durationSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Story({
    required this.id,
    required this.authorId,
    required this.communityId,
    required this.title,
    this.body,
    this.audioUrl,
    this.coverImageUrl,
    this.languageCode = 'en',
    this.status = 'pending_review',
    this.visibility = StoryVisibility.communityOnly,
    this.durationSeconds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      communityId: json['community_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      audioUrl: json['audio_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      languageCode: json['language_code'] as String? ?? 'en',
      status: json['status'] as String? ?? 'pending_review',
      visibility: json['visibility'] == 'public'
          ? StoryVisibility.public
          : StoryVisibility.communityOnly,
      durationSeconds: json['duration_seconds'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'community_id': communityId,
      'title': title,
      'body': body,
      'audio_url': audioUrl,
      'cover_image_url': coverImageUrl,
      'language_code': languageCode,
      'status': status,
      'visibility': visibility == StoryVisibility.public ? 'public' : 'community_only',
      'duration_seconds': durationSeconds,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

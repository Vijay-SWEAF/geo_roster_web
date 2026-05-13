import 'package:equatable/equatable.dart';

enum PostType {
  memory, story, elderWisdom, helpRequest, event, achievement, announcement;

  String get value {
    switch (this) {
      case PostType.memory:       return 'memory';
      case PostType.story:        return 'story';
      case PostType.elderWisdom:  return 'elder_wisdom';
      case PostType.helpRequest:  return 'help_request';
      case PostType.event:        return 'event';
      case PostType.achievement:  return 'achievement';
      case PostType.announcement: return 'announcement';
    }
  }

  String get displayName {
    switch (this) {
      case PostType.memory:       return 'Memory';
      case PostType.story:        return 'Story';
      case PostType.elderWisdom:  return 'Elder Wisdom';
      case PostType.helpRequest:  return 'Help Request';
      case PostType.event:        return 'Event';
      case PostType.achievement:  return 'Achievement';
      case PostType.announcement: return 'Announcement';
    }
  }

  static PostType fromString(String s) {
    switch (s) {
      case 'story':        return PostType.story;
      case 'elder_wisdom': return PostType.elderWisdom;
      case 'help_request': return PostType.helpRequest;
      case 'event':        return PostType.event;
      case 'achievement':  return PostType.achievement;
      case 'announcement': return PostType.announcement;
      default:             return PostType.memory;
    }
  }
}

enum PostStatus {
  draft, pendingReview, approved, rejected, hidden, reported;

  String get value {
    switch (this) {
      case PostStatus.draft:         return 'draft';
      case PostStatus.pendingReview: return 'pending_review';
      case PostStatus.approved:      return 'approved';
      case PostStatus.rejected:      return 'rejected';
      case PostStatus.hidden:        return 'hidden';
      case PostStatus.reported:      return 'reported';
    }
  }

  static PostStatus fromString(String s) {
    switch (s) {
      case 'draft':          return PostStatus.draft;
      case 'pending_review': return PostStatus.pendingReview;
      case 'rejected':       return PostStatus.rejected;
      case 'hidden':         return PostStatus.hidden;
      case 'reported':       return PostStatus.reported;
      default:               return PostStatus.approved;
    }
  }
}

enum ReactionType {
  respect, beautifulMemory, inspired, prayers, proud, thankYou;

  String get value {
    switch (this) {
      case ReactionType.respect:         return 'respect';
      case ReactionType.beautifulMemory: return 'beautiful_memory';
      case ReactionType.inspired:        return 'inspired';
      case ReactionType.prayers:         return 'prayers';
      case ReactionType.proud:           return 'proud';
      case ReactionType.thankYou:        return 'thank_you';
    }
  }

  String get label {
    switch (this) {
      case ReactionType.respect:         return 'Respect';
      case ReactionType.beautifulMemory: return 'Beautiful Memory';
      case ReactionType.inspired:        return 'Inspired';
      case ReactionType.prayers:         return 'Prayers';
      case ReactionType.proud:           return 'Proud';
      case ReactionType.thankYou:        return 'Thank You';
    }
  }

  String get emoji {
    switch (this) {
      case ReactionType.respect:         return '🙏';
      case ReactionType.beautifulMemory: return '📸';
      case ReactionType.inspired:        return '✨';
      case ReactionType.prayers:         return '🕯️';
      case ReactionType.proud:           return '🌟';
      case ReactionType.thankYou:        return '💛';
    }
  }

  static ReactionType fromString(String s) {
    switch (s) {
      case 'beautiful_memory': return ReactionType.beautifulMemory;
      case 'inspired':         return ReactionType.inspired;
      case 'prayers':          return ReactionType.prayers;
      case 'proud':            return ReactionType.proud;
      case 'thank_you':        return ReactionType.thankYou;
      default:                 return ReactionType.respect;
    }
  }
}

class Post extends Equatable {
  final String id;
  final String communityId;
  final String authorId;
  final PostType postType;
  final String title;
  final String? body;
  final String? coverImageUrl;
  final PostStatus status;
  final String visibility;
  final bool commentsDisabled;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data (not from DB column)
  final Map<String, int>? reactionCounts;
  final int? commentCount;
  final ReactionType? myReaction;

  const Post({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.postType,
    required this.title,
    this.body,
    this.coverImageUrl,
    this.status = PostStatus.pendingReview,
    this.visibility = 'community',
    this.commentsDisabled = false,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.reactionCounts,
    this.commentCount,
    this.myReaction,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        communityId: json['community_id'] as String,
        authorId: json['author_id'] as String,
        postType: PostType.fromString(json['post_type'] as String),
        title: json['title'] as String,
        body: json['body'] as String?,
        coverImageUrl: json['cover_image_url'] as String?,
        status: PostStatus.fromString(json['status'] as String? ?? 'approved'),
        visibility: json['visibility'] as String? ?? 'community',
        commentsDisabled: json['comments_disabled'] as bool? ?? false,
        isPinned: json['is_pinned'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        reactionCounts: json['reaction_counts'] != null
            ? Map<String, int>.from(
                (json['reaction_counts'] as Map<String, dynamic>)
                    .map((k, v) => MapEntry(k, (v as num).toInt())))
            : null,
        commentCount: json['comment_count'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'community_id': communityId,
        'author_id': authorId,
        'post_type': postType.value,
        'title': title,
        'body': body,
        'cover_image_url': coverImageUrl,
        'status': status.value,
        'visibility': visibility,
        'comments_disabled': commentsDisabled,
      };

  @override
  List<Object?> get props => [id];
}

class Reaction extends Equatable {
  final String id;
  final String postId;
  final String userId;
  final ReactionType reactionType;
  final DateTime createdAt;

  const Reaction({
    required this.id,
    required this.postId,
    required this.userId,
    required this.reactionType,
    required this.createdAt,
  });

  factory Reaction.fromJson(Map<String, dynamic> json) => Reaction(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        userId: json['user_id'] as String,
        reactionType: ReactionType.fromString(json['reaction_type'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  @override
  List<Object?> get props => [id];
}

class Comment extends Equatable {
  final String id;
  final String postId;
  final String authorId;
  final String body;
  final String status;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.body,
    this.status = 'approved',
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        authorId: json['author_id'] as String,
        body: json['body'] as String,
        status: json['status'] as String? ?? 'approved',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  @override
  List<Object?> get props => [id];
}

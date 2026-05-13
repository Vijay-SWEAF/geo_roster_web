import 'package:equatable/equatable.dart';

enum NotificationType {
  commentOnPost,
  rsvpOnEvent,
  postApproved,
  postRejected,
  commentApproved,
  commentRejected,
  unknown,
}

extension NotificationTypeX on NotificationType {
  static NotificationType fromString(String s) {
    switch (s) {
      case 'comment_on_post':    return NotificationType.commentOnPost;
      case 'rsvp_on_event':      return NotificationType.rsvpOnEvent;
      case 'post_approved':      return NotificationType.postApproved;
      case 'post_rejected':      return NotificationType.postRejected;
      case 'comment_approved':   return NotificationType.commentApproved;
      case 'comment_rejected':   return NotificationType.commentRejected;
      default:                   return NotificationType.unknown;
    }
  }
}

class AppNotification extends Equatable {
  final String id;
  final String recipientId;
  final String communityId;
  final NotificationType type;
  final String title;
  final String body;
  final String? actorName;
  final String? entityId;
  final String? entityType;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.communityId,
    required this.type,
    required this.title,
    required this.body,
    this.actorName,
    this.entityId,
    this.entityType,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id:           json['id'] as String,
      recipientId:  json['recipient_id'] as String,
      communityId:  json['community_id'] as String,
      type:         NotificationTypeX.fromString(json['type'] as String? ?? ''),
      title:        json['title'] as String,
      body:         json['body'] as String,
      actorName:    json['actor_name'] as String?,
      entityId:     json['entity_id'] as String?,
      entityType:   json['entity_type'] as String?,
      isRead:       json['is_read'] as bool? ?? false,
      createdAt:    DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id:          id,
    recipientId: recipientId,
    communityId: communityId,
    type:        type,
    title:       title,
    body:        body,
    actorName:   actorName,
    entityId:    entityId,
    entityType:  entityType,
    isRead:      isRead ?? this.isRead,
    createdAt:   createdAt,
  );

  @override
  List<Object?> get props => [id, isRead];
}

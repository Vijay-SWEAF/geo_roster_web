import 'package:equatable/equatable.dart';

enum EventType {
  villageGathering, festival, sports, bloodDonation, cleanlinessDrive,
  treePlantation, education, seniorCitizenMeet, cultural, youthMeetup;

  String get value {
    switch (this) {
      case EventType.villageGathering:  return 'village_gathering';
      case EventType.festival:          return 'festival';
      case EventType.sports:            return 'sports';
      case EventType.bloodDonation:     return 'blood_donation';
      case EventType.cleanlinessDrive:  return 'cleanliness_drive';
      case EventType.treePlantation:    return 'tree_plantation';
      case EventType.education:         return 'education';
      case EventType.seniorCitizenMeet: return 'senior_citizen_meet';
      case EventType.cultural:          return 'cultural';
      case EventType.youthMeetup:       return 'youth_meetup';
    }
  }

  String get displayName {
    switch (this) {
      case EventType.villageGathering:  return 'Village Gathering';
      case EventType.festival:          return 'Festival';
      case EventType.sports:            return 'Sports Event';
      case EventType.bloodDonation:     return 'Blood Donation';
      case EventType.cleanlinessDrive:  return 'Cleanliness Drive';
      case EventType.treePlantation:    return 'Tree Plantation';
      case EventType.education:         return 'Education Program';
      case EventType.seniorCitizenMeet: return 'Senior Citizen Meet';
      case EventType.cultural:          return 'Cultural Event';
      case EventType.youthMeetup:       return 'Youth Meetup';
    }
  }

  String get emoji {
    switch (this) {
      case EventType.villageGathering:  return '🏘️';
      case EventType.festival:          return '🎊';
      case EventType.sports:            return '🏆';
      case EventType.bloodDonation:     return '🩸';
      case EventType.cleanlinessDrive:  return '🧹';
      case EventType.treePlantation:    return '🌳';
      case EventType.education:         return '📚';
      case EventType.seniorCitizenMeet: return '👴';
      case EventType.cultural:          return '🎭';
      case EventType.youthMeetup:       return '🌱';
    }
  }

  static EventType fromString(String s) {
    for (final t in EventType.values) {
      if (t.value == s) return t;
    }
    return EventType.villageGathering;
  }
}

enum RsvpStatus { going, interested, notGoing }

extension RsvpStatusX on RsvpStatus {
  String get value {
    switch (this) {
      case RsvpStatus.going:      return 'going';
      case RsvpStatus.interested: return 'interested';
      case RsvpStatus.notGoing:   return 'not_going';
    }
  }
}

class Event extends Equatable {
  final String id;
  final String communityId;
  final String? postId;
  final String title;
  final String? description;
  final EventType? eventType;
  final DateTime eventDate;
  final String? location;
  final String? organizerId;
  final String? coverImageUrl;
  final String status;
  final DateTime createdAt;

  // Joined counts
  final int? goingCount;
  final int? interestedCount;

  const Event({
    required this.id,
    required this.communityId,
    this.postId,
    required this.title,
    this.description,
    this.eventType,
    required this.eventDate,
    this.location,
    this.organizerId,
    this.coverImageUrl,
    this.status = 'upcoming',
    required this.createdAt,
    this.goingCount,
    this.interestedCount,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'] as String,
        communityId: json['community_id'] as String,
        postId: json['post_id'] as String?,
        title: json['title'] as String,
        description: json['description'] as String?,
        eventType: json['event_type'] != null
            ? EventType.fromString(json['event_type'] as String)
            : null,
        eventDate: DateTime.parse(json['event_date'] as String),
        location: json['location'] as String?,
        organizerId: json['organizer_id'] as String?,
        coverImageUrl: json['cover_image_url'] as String?,
        status: json['status'] as String? ?? 'upcoming',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'community_id': communityId,
        'title': title,
        'description': description,
        'event_type': eventType?.value,
        'event_date': eventDate.toIso8601String(),
        'location': location,
        'organizer_id': organizerId,
        'cover_image_url': coverImageUrl,
        'status': status,
      };

  bool get isUpcoming => eventDate.isAfter(DateTime.now());

  @override
  List<Object?> get props => [id];
}

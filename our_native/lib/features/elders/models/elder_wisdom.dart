import 'package:equatable/equatable.dart';

enum WisdomTopic {
  lifeAdvice, conflictResolution, farmingWisdom, familyValues,
  honesty, hardWork, communityUnity, oldTraditions, villageHistory, other;

  String get value {
    switch (this) {
      case WisdomTopic.lifeAdvice:         return 'life_advice';
      case WisdomTopic.conflictResolution: return 'conflict_resolution';
      case WisdomTopic.farmingWisdom:      return 'farming_wisdom';
      case WisdomTopic.familyValues:       return 'family_values';
      case WisdomTopic.honesty:            return 'honesty';
      case WisdomTopic.hardWork:           return 'hard_work';
      case WisdomTopic.communityUnity:     return 'community_unity';
      case WisdomTopic.oldTraditions:      return 'old_traditions';
      case WisdomTopic.villageHistory:     return 'village_history';
      case WisdomTopic.other:              return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case WisdomTopic.lifeAdvice:         return 'Life Advice';
      case WisdomTopic.conflictResolution: return 'Conflict Resolution';
      case WisdomTopic.farmingWisdom:      return 'Farming Wisdom';
      case WisdomTopic.familyValues:       return 'Family Values';
      case WisdomTopic.honesty:            return 'Honesty';
      case WisdomTopic.hardWork:           return 'Hard Work';
      case WisdomTopic.communityUnity:     return 'Community Unity';
      case WisdomTopic.oldTraditions:      return 'Old Traditions';
      case WisdomTopic.villageHistory:     return 'Village History';
      case WisdomTopic.other:              return 'Other';
    }
  }

  static WisdomTopic fromString(String s) {
    for (final t in WisdomTopic.values) {
      if (t.value == s) return t;
    }
    return WisdomTopic.other;
  }
}

class ElderWisdom extends Equatable {
  final String id;
  final String postId;
  final String? elderName;
  final int? elderAge;
  final WisdomTopic? topic;
  final String? audioUrl;
  final String? videoUrl;
  final String? transcript;

  const ElderWisdom({
    required this.id,
    required this.postId,
    this.elderName,
    this.elderAge,
    this.topic,
    this.audioUrl,
    this.videoUrl,
    this.transcript,
  });

  factory ElderWisdom.fromJson(Map<String, dynamic> json) => ElderWisdom(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        elderName: json['elder_name'] as String?,
        elderAge: json['elder_age'] as int?,
        topic: json['topic'] != null
            ? WisdomTopic.fromString(json['topic'] as String)
            : null,
        audioUrl: json['audio_url'] as String?,
        videoUrl: json['video_url'] as String?,
        transcript: json['transcript'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'post_id': postId,
        'elder_name': elderName,
        'elder_age': elderAge,
        'topic': topic?.value,
        'audio_url': audioUrl,
        'video_url': videoUrl,
        'transcript': transcript,
      };

  @override
  List<Object?> get props => [id];
}

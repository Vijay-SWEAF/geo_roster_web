import 'package:equatable/equatable.dart';

enum MemoryCategory {
  schoolDays, farming, festivals, weddings, villageRoads, oldHouses,
  temples, sports, localShops, oldTransport, familyMemories, historical;

  String get value {
    switch (this) {
      case MemoryCategory.schoolDays:     return 'school_days';
      case MemoryCategory.farming:        return 'farming';
      case MemoryCategory.festivals:      return 'festivals';
      case MemoryCategory.weddings:       return 'weddings';
      case MemoryCategory.villageRoads:   return 'village_roads';
      case MemoryCategory.oldHouses:      return 'old_houses';
      case MemoryCategory.temples:        return 'temples';
      case MemoryCategory.sports:         return 'sports';
      case MemoryCategory.localShops:     return 'local_shops';
      case MemoryCategory.oldTransport:   return 'old_transport';
      case MemoryCategory.familyMemories: return 'family_memories';
      case MemoryCategory.historical:     return 'historical';
    }
  }

  String get displayName {
    switch (this) {
      case MemoryCategory.schoolDays:     return 'School Days';
      case MemoryCategory.farming:        return 'Farming';
      case MemoryCategory.festivals:      return 'Festivals';
      case MemoryCategory.weddings:       return 'Weddings';
      case MemoryCategory.villageRoads:   return 'Village Roads';
      case MemoryCategory.oldHouses:      return 'Old Houses';
      case MemoryCategory.temples:        return 'Temples & Sacred Places';
      case MemoryCategory.sports:         return 'Sports';
      case MemoryCategory.localShops:     return 'Local Shops';
      case MemoryCategory.oldTransport:   return 'Old Transport';
      case MemoryCategory.familyMemories: return 'Family Memories';
      case MemoryCategory.historical:     return 'Historical Moments';
    }
  }

  String get emoji {
    switch (this) {
      case MemoryCategory.schoolDays:     return '🏫';
      case MemoryCategory.farming:        return '🌾';
      case MemoryCategory.festivals:      return '🎉';
      case MemoryCategory.weddings:       return '💒';
      case MemoryCategory.villageRoads:   return '🛤️';
      case MemoryCategory.oldHouses:      return '🏠';
      case MemoryCategory.temples:        return '🛕';
      case MemoryCategory.sports:         return '🏏';
      case MemoryCategory.localShops:     return '🏪';
      case MemoryCategory.oldTransport:   return '🚂';
      case MemoryCategory.familyMemories: return '👨‍👩‍👧‍👦';
      case MemoryCategory.historical:     return '📜';
    }
  }

  static MemoryCategory fromString(String s) {
    for (final c in MemoryCategory.values) {
      if (c.value == s) return c;
    }
    return MemoryCategory.familyMemories;
  }
}

class Memory extends Equatable {
  final String id;
  final String postId;
  final String? approxYear;
  final String? locationName;
  final List<String> peopleNames;
  final MemoryCategory? category;
  final bool isVintage;
  final String? thenImageUrl;
  final String? nowImageUrl;

  const Memory({
    required this.id,
    required this.postId,
    this.approxYear,
    this.locationName,
    this.peopleNames = const [],
    this.category,
    this.isVintage = true,
    this.thenImageUrl,
    this.nowImageUrl,
  });

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        approxYear: json['approx_year'] as String?,
        locationName: json['location_name'] as String?,
        peopleNames: (json['people_names'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        category: json['category'] != null
            ? MemoryCategory.fromString(json['category'] as String)
            : null,
        isVintage: json['is_vintage'] as bool? ?? true,
        thenImageUrl: json['then_image_url'] as String?,
        nowImageUrl: json['now_image_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'post_id': postId,
        'approx_year': approxYear,
        'location_name': locationName,
        'people_names': peopleNames,
        'category': category?.value,
        'is_vintage': isVintage,
        'then_image_url': thenImageUrl,
        'now_image_url': nowImageUrl,
      };

  @override
  List<Object?> get props => [id];
}

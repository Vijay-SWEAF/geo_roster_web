import 'package:equatable/equatable.dart';

enum UserRole { member, elder, moderator, admin }

extension UserRoleX on UserRole {
  String get value {
    switch (this) {
      case UserRole.member:    return 'member';
      case UserRole.elder:     return 'elder';
      case UserRole.moderator: return 'moderator';
      case UserRole.admin:     return 'admin';
    }
  }

  static UserRole fromString(String s) {
    switch (s) {
      case 'elder':     return UserRole.elder;
      case 'moderator': return UserRole.moderator;
      case 'admin':     return UserRole.admin;
      default:          return UserRole.member;
    }
  }

  bool get canModerate =>
      this == UserRole.moderator || this == UserRole.admin;
}

class UserProfile extends Equatable {
  final String id;
  final String userId;
  final String? communityId;
  final String fullName;
  final String? surname;
  final String? nativeVillage;
  final String? currentLocation;
  final String? profilePhotoUrl;
  final UserRole role;
  final String? bio;
  final bool isApproved;
  final String languagePref;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.userId,
    this.communityId,
    required this.fullName,
    this.surname,
    this.nativeVillage,
    this.currentLocation,
    this.profilePhotoUrl,
    this.role = UserRole.member,
    this.bio,
    this.isApproved = false,
    this.languagePref = 'en',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        communityId: json['community_id'] as String?,
        fullName: json['full_name'] as String,
        surname: json['surname'] as String?,
        nativeVillage: json['native_village'] as String?,
        currentLocation: json['current_location'] as String?,
        profilePhotoUrl: json['profile_photo_url'] as String?,
        role: UserRoleX.fromString(json['role'] as String? ?? 'member'),
        bio: json['bio'] as String?,
        isApproved: json['is_approved'] as bool? ?? false,
        languagePref: json['language_pref'] as String? ?? 'en',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'community_id': communityId,
        'full_name': fullName,
        'surname': surname,
        'native_village': nativeVillage,
        'current_location': currentLocation,
        'profile_photo_url': profilePhotoUrl,
        'role': role.value,
        'bio': bio,
        'is_approved': isApproved,
        'language_pref': languagePref,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  UserProfile copyWith({
    String? communityId,
    String? fullName,
    String? surname,
    String? nativeVillage,
    String? currentLocation,
    String? profilePhotoUrl,
    UserRole? role,
    String? bio,
    bool? isApproved,
    String? languagePref,
  }) =>
      UserProfile(
        id: id,
        userId: userId,
        communityId: communityId ?? this.communityId,
        fullName: fullName ?? this.fullName,
        surname: surname ?? this.surname,
        nativeVillage: nativeVillage ?? this.nativeVillage,
        currentLocation: currentLocation ?? this.currentLocation,
        profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
        role: role ?? this.role,
        bio: bio ?? this.bio,
        isApproved: isApproved ?? this.isApproved,
        languagePref: languagePref ?? this.languagePref,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  @override
  List<Object?> get props => [id, userId];
}

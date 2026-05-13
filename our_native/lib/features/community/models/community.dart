import 'package:equatable/equatable.dart';

class Community extends Equatable {
  final String id;
  final String name;
  final String? location;
  final String? description;
  final String? logoUrl;
  final bool isPrivate;
  final String? createdBy;
  final DateTime createdAt;

  const Community({
    required this.id,
    required this.name,
    this.location,
    this.description,
    this.logoUrl,
    this.isPrivate = true,
    this.createdBy,
    required this.createdAt,
  });

  factory Community.fromJson(Map<String, dynamic> json) => Community(
        id: json['id'] as String,
        name: json['name'] as String,
        location: json['location'] as String?,
        description: json['description'] as String?,
        logoUrl: json['logo_url'] as String?,
        isPrivate: json['is_private'] as bool? ?? true,
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'description': description,
        'logo_url': logoUrl,
        'is_private': isPrivate,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id];
}

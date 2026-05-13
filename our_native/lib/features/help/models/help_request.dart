import 'package:equatable/equatable.dart';

enum HelpType {
  blood, hospital, education, jobReferral, emergency,
  funeralSupport, lostDocument, volunteer, financial, general;

  String get value {
    switch (this) {
      case HelpType.blood:          return 'blood';
      case HelpType.hospital:       return 'hospital';
      case HelpType.education:      return 'education';
      case HelpType.jobReferral:    return 'job_referral';
      case HelpType.emergency:      return 'emergency';
      case HelpType.funeralSupport: return 'funeral_support';
      case HelpType.lostDocument:   return 'lost_document';
      case HelpType.volunteer:      return 'volunteer';
      case HelpType.financial:      return 'financial';
      case HelpType.general:        return 'general';
    }
  }

  String get displayName {
    switch (this) {
      case HelpType.blood:          return 'Blood Needed';
      case HelpType.hospital:       return 'Hospital Help';
      case HelpType.education:      return 'Education Help';
      case HelpType.jobReferral:    return 'Job Referral';
      case HelpType.emergency:      return 'Emergency';
      case HelpType.funeralSupport: return 'Funeral Support';
      case HelpType.lostDocument:   return 'Lost Document';
      case HelpType.volunteer:      return 'Volunteer Needed';
      case HelpType.financial:      return 'Financial Help';
      case HelpType.general:        return 'General Support';
    }
  }

  String get emoji {
    switch (this) {
      case HelpType.blood:          return '🩸';
      case HelpType.hospital:       return '🏥';
      case HelpType.education:      return '📚';
      case HelpType.jobReferral:    return '💼';
      case HelpType.emergency:      return '🚨';
      case HelpType.funeralSupport: return '🕯️';
      case HelpType.lostDocument:   return '📄';
      case HelpType.volunteer:      return '🤝';
      case HelpType.financial:      return '💰';
      case HelpType.general:        return '🙏';
    }
  }

  static HelpType fromString(String s) {
    for (final t in HelpType.values) {
      if (t.value == s) return t;
    }
    return HelpType.general;
  }
}

enum HelpUrgency { low, medium, high, critical }

extension HelpUrgencyX on HelpUrgency {
  String get value {
    switch (this) {
      case HelpUrgency.low:      return 'low';
      case HelpUrgency.medium:   return 'medium';
      case HelpUrgency.high:     return 'high';
      case HelpUrgency.critical: return 'critical';
    }
  }

  static HelpUrgency fromString(String s) {
    switch (s) {
      case 'high':     return HelpUrgency.high;
      case 'critical': return HelpUrgency.critical;
      case 'low':      return HelpUrgency.low;
      default:         return HelpUrgency.medium;
    }
  }
}

enum HelpStatus { open, inProgress, helpReceived, closed }

extension HelpStatusX on HelpStatus {
  String get value {
    switch (this) {
      case HelpStatus.open:         return 'open';
      case HelpStatus.inProgress:   return 'in_progress';
      case HelpStatus.helpReceived: return 'help_received';
      case HelpStatus.closed:       return 'closed';
    }
  }

  static HelpStatus fromString(String s) {
    switch (s) {
      case 'in_progress':   return HelpStatus.inProgress;
      case 'help_received': return HelpStatus.helpReceived;
      case 'closed':        return HelpStatus.closed;
      default:              return HelpStatus.open;
    }
  }
}

class HelpRequest extends Equatable {
  final String id;
  final String postId;
  final HelpType helpType;
  final HelpUrgency urgency;
  final String? contactName;
  final String? contactPhone;
  final String? location;
  final HelpStatus helpStatus;

  const HelpRequest({
    required this.id,
    required this.postId,
    this.helpType = HelpType.general,
    this.urgency = HelpUrgency.medium,
    this.contactName,
    this.contactPhone,
    this.location,
    this.helpStatus = HelpStatus.open,
  });

  factory HelpRequest.fromJson(Map<String, dynamic> json) => HelpRequest(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        helpType: HelpType.fromString(json['help_type'] as String? ?? 'general'),
        urgency:
            HelpUrgencyX.fromString(json['urgency'] as String? ?? 'medium'),
        contactName: json['contact_name'] as String?,
        contactPhone: json['contact_phone'] as String?,
        location: json['location'] as String?,
        helpStatus:
            HelpStatusX.fromString(json['help_status'] as String? ?? 'open'),
      );

  Map<String, dynamic> toJson() => {
        'post_id': postId,
        'help_type': helpType.value,
        'urgency': urgency.value,
        'contact_name': contactName,
        'contact_phone': contactPhone,
        'location': location,
        'help_status': helpStatus.value,
      };

  @override
  List<Object?> get props => [id];
}

class AppConstants {
  AppConstants._();

  // ── App info ─────────────────────────────────────────────
  static const String appName      = 'Our Native';
  static const String appTagline   = 'Preserve roots. Rebuild bonds.';
  static const String appVersion   = '1.0.0';

  // ── Supabase ─────────────────────────────────────────────
  // Replace with your actual Supabase URL and anon key from the dashboard.
  static const String supabaseUrl      = 'https://fdqucbixyeukgbhxmswy.supabase.co';
  static const String supabaseAnonKey  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkcXVjYml4eWV1a2diaHhtc3d5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1MTgwMDYsImV4cCI6MjA5NDA5NDAwNn0.MsJFuGbvdIrdLxslYZAs0wSMweMzBDl86dK2yY4c7Lw';

  // ── OpenAI ───────────────────────────────────────────────
  static const String openAiApiKey = 'YOUR_OPENAI_API_KEY';

  // ── Storage buckets ──────────────────────────────────────
  static const String bucketProfilePhotos = 'profile-photos';
  static const String bucketPostImages    = 'post-images';
  static const String bucketMemoryArchive = 'memory-archive';
  static const String bucketStoryAudio    = 'story-audio';
  static const String bucketElderVideos   = 'elder-videos';
  static const String bucketEventMedia    = 'event-media';

  // ── Pagination ───────────────────────────────────────────
  static const int feedPageSize     = 20;
  static const int memoryPageSize   = 30;

  // ── Moderation keywords (basic auto-flag list) ───────────
  // NOTE: This is a minimal seed list; full list managed server-side.
  static const List<String> autoFlagKeywords = [
    'BJP', 'Congress', 'AAP', 'NCP', 'Shiv Sena',
    'vote', 'election', '#election',
  ];

  // ── Reaction labels ──────────────────────────────────────
  static const Map<String, String> reactionLabels = {
    'respect':          'Respect',
    'beautiful_memory': 'Beautiful Memory',
    'inspired':         'Inspired',
    'prayers':          'Prayers',
    'proud':            'Proud',
    'thank_you':        'Thank You',
  };

  static const Map<String, String> reactionEmoji = {
    'respect':          '🙏',
    'beautiful_memory': '📸',
    'inspired':         '✨',
    'prayers':          '🕯️',
    'proud':            '🌟',
    'thank_you':        '💛',
  };

  // ── User roles ───────────────────────────────────────────
  static const String roleMember    = 'member';
  static const String roleElder     = 'elder';
  static const String roleModerator = 'moderator';
  static const String roleAdmin     = 'admin';

  // ── Post types ───────────────────────────────────────────
  static const String postTypeMemory       = 'memory';
  static const String postTypeStory        = 'story';
  static const String postTypeElderWisdom  = 'elder_wisdom';
  static const String postTypeHelpRequest  = 'help_request';
  static const String postTypeEvent        = 'event';
  static const String postTypeAchievement  = 'achievement';
  static const String postTypeAnnouncement = 'announcement';

  // ── Post status ──────────────────────────────────────────
  static const String statusDraft         = 'draft';
  static const String statusPendingReview = 'pending_review';
  static const String statusApproved      = 'approved';
  static const String statusRejected      = 'rejected';
  static const String statusHidden        = 'hidden';
  static const String statusReported      = 'reported';

  // ── Languages ────────────────────────────────────────────
  static const String langEnglish = 'en';
  static const String langMarathi = 'mr';

  // ── Comment placeholder ──────────────────────────────────
  static const String commentHint = 'Add a respectful thought…';
}

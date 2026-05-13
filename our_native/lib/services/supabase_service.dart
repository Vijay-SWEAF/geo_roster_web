import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

/// Global Supabase client accessor
final supabase = SupabaseService.instance.client;

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  late final SupabaseClient client;

  Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );
    client = Supabase.instance.client;
  }

  /// Current authenticated user
  User? get currentUser => client.auth.currentUser;

  /// Auth state stream
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  bool get isAuthenticated => currentUser != null;

  Future<Map<String, dynamic>?> fetchCurrentUserProfileSummary() async {
    final user = currentUser;
    if (user == null) return null;

    return client
        .from('user_profiles')
        .select('id, user_id, community_id, full_name, native_village, is_approved')
        .eq('user_id', user.id)
        .maybeSingle();
  }
}

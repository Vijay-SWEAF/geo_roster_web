import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supabase_service.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) return null;

  final data = await supabase
      .from('user_profiles')
      .select()
      .eq('user_id', user.id)
      .maybeSingle();

  if (data == null) return null;
  return UserProfile.fromJson(data);
});

final currentCommunityIdProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider).asData?.value?.communityId;
});

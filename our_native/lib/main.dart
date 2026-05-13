import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/supabase_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.instance.initialize();

  runApp(
    const ProviderScope(
      child: OurNativeApp(),
    ),
  );
}

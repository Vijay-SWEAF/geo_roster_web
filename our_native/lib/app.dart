import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/l10n/app_localizations.dart';
import 'core/providers/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

class OurNativeApp extends ConsumerStatefulWidget {
  const OurNativeApp({super.key});

  @override
  ConsumerState<OurNativeApp> createState() => _OurNativeAppState();
}

class _OurNativeAppState extends ConsumerState<OurNativeApp> {
  @override
  void initState() {
    super.initState();
    // Load persisted locale (runs once on startup)
    Future.microtask(() => ref.read(localeProvider.notifier).loadSaved());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Our Native',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: locale,
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

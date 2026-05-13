import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('mr'); // Marathi-first default

  /// Toggle between Marathi and English.
  Future<void> toggle() async {
    final next = state.languageCode == 'mr'
        ? const Locale('en')
        : const Locale('mr');
    await setLocale(next.languageCode);
  }

  /// Set locale explicitly by language code ('mr' or 'en').
  Future<void> setLocale(String langCode) async {
    state = Locale(langCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, langCode);
  }

  /// Load persisted locale on startup.
  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLocaleKey);
    if (saved != null) {
      state = Locale(saved);
    }
  }

  bool get isMarathi => state.languageCode == 'mr';
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

class LocaleNotifier extends StateNotifier<Locale?> {
  // Arabic-first: the app defaults to Arabic (+ RTL) on first launch. A saved
  // user choice (e.g. English, picked in Profile → Language) overrides it.
  LocaleNotifier() : super(const Locale('ar'));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey);
    if (code != null) state = Locale(code);
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_kLocaleKey);
    } else {
      await prefs.setString(_kLocaleKey, locale.languageCode);
    }
  }

  void toggle() {
    setLocale((state?.languageCode == 'ar')
        ? const Locale('en')
        : const Locale('ar'));
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) => LocaleNotifier());

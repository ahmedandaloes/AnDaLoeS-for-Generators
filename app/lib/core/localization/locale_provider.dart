import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the app locale. `null` means "follow the device language".
/// The user can switch between Arabic and English from the profile screen.
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null);

  void setLocale(Locale? locale) => state = locale;

  void toggle() {
    state = (state?.languageCode == 'ar')
        ? const Locale('en')
        : const Locale('ar');
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) => LocaleNotifier());

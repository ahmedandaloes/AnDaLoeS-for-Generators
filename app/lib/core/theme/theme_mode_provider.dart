import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls the app-wide ThemeMode. Defaults to system setting.
final themeModeProvider =
    StateProvider<ThemeMode>((ref) => ThemeMode.system);

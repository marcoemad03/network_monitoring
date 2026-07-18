import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'app_theme.dart';

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(AppThemeMode.system);

  Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(AppConstants.themeKey);
    state = switch (value) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.system,
    };
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.themeKey, mode.name);
  }

  ThemeData resolveTheme(Brightness systemBrightness) {
    return AppTheme.getThemeForMode(state, systemBrightness);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>(
  (ref) => ThemeNotifier(),
);

final resolvedThemeProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeProvider);
  final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  return AppTheme.getThemeForMode(mode, brightness);
});

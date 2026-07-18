import 'package:flutter/material.dart';
import 'dark_theme.dart';
import 'light_theme.dart';

enum AppThemeMode { light, dark, system }

class AppTheme {
  static ThemeData light = LightTheme.theme;
  static ThemeData dark = DarkTheme.theme;

  static ThemeData getThemeForMode(AppThemeMode mode, Brightness systemBrightness) {
    return switch (mode) {
      AppThemeMode.light => light,
      AppThemeMode.dark => dark,
      AppThemeMode.system => systemBrightness == Brightness.dark ? dark : light,
    };
  }

  static Brightness getBrightnessForMode(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.light => Brightness.light,
      AppThemeMode.dark => Brightness.dark,
      AppThemeMode.system => Brightness.light,
    };
  }
}

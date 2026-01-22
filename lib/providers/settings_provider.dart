import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum pentru modurile de temă
enum ThemeModeOption {
  system,
  light,
  dark,
}

/// Model pentru setările aplicației
class AppSettings {
  final ThemeModeOption themeMode;
  final String? languageCode; // null = automat (sistem)

  const AppSettings({
    this.themeMode = ThemeModeOption.system,
    this.languageCode,
  });

  AppSettings copyWith({
    ThemeModeOption? themeMode,
    String? languageCode,
    bool clearLanguage = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      languageCode: clearLanguage ? null : (languageCode ?? this.languageCode),
    );
  }

  /// Convertește în ThemeMode pentru Flutter
  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
        return ThemeMode.dark;
      case ThemeModeOption.system:
        return ThemeMode.system;
    }
  }
}

/// Notifier pentru gestionarea setărilor
class SettingsNotifier extends Notifier<AppSettings> {
  static const _themeKey = 'theme_mode';
  static const _languageKey = 'language_code';

  @override
  AppSettings build() {
    // Încarcă setările la inițializare
    _loadSettings();
    return const AppSettings();
  }

  /// Încarcă setările salvate
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final themeModeIndex = prefs.getInt(_themeKey) ?? 0;
    final languageCode = prefs.getString(_languageKey);

    state = AppSettings(
      themeMode: ThemeModeOption.values[themeModeIndex],
      languageCode: languageCode,
    );
  }

  /// Setează modul de temă
  Future<void> setThemeMode(ThemeModeOption mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    state = state.copyWith(themeMode: mode);
  }

  /// Setează limba
  Future<void> setLanguage(String? languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (languageCode == null) {
      await prefs.remove(_languageKey);
      state = state.copyWith(clearLanguage: true);
    } else {
      await prefs.setString(_languageKey, languageCode);
      state = state.copyWith(languageCode: languageCode);
    }
  }
}

/// Provider pentru setări
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
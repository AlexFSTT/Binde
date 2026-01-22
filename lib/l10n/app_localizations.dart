import 'package:flutter/material.dart';
import 'app_ro.dart';
import 'app_en.dart';

/// Serviciu pentru gestionarea traducerilor
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  /// Obține instanța curentă din context
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  /// Delegate pentru MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Limbile suportate
  static const List<Locale> supportedLocales = [
    Locale('ro'), // Română
    Locale('en'), // English
  ];

  /// Map-ul de traduceri pentru limba curentă
  Map<String, String> get _localizedStrings {
    switch (locale.languageCode) {
      case 'ro':
        return ro;
      case 'en':
        return en;
      default:
        return en; // Fallback la engleză
    }
  }

  /// Obține traducerea pentru o cheie
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  /// Numele limbii curente
  String get languageName {
    switch (locale.languageCode) {
      case 'ro':
        return 'Română';
      case 'en':
        return 'English';
      default:
        return 'English';
    }
  }
}

/// Delegate pentru încărcarea localizărilor
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ro', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Extensie pentru acces mai ușor la traduceri
extension LocalizationExtension on BuildContext {
  /// Acces rapid la traduceri: context.tr('key')
  String tr(String key) => AppLocalizations.of(this).translate(key);
  
  /// Limba curentă
  String get currentLanguage => AppLocalizations.of(this).languageName;
  
  /// Codul limbii
  String get languageCode => AppLocalizations.of(this).locale.languageCode;
}
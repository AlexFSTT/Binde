import 'package:flutter/material.dart';

/// Tema aplicației Binde — Fresh Vibrant palette
/// Sky Blue · Mint Green · Lime · Orange · Gold
class AppTheme {
  // 🎨 FRESH VIBRANT PALETTE
  static const Color skyBlue = Color(0xFF9AC1F0);
  static const Color mintGreen = Color(0xFF72FA93);
  static const Color limeGreen = Color(0xFFA0E548);
  static const Color burntOrange = Color(0xFFE45F2B);
  static const Color goldenYellow = Color(0xFFF6C445);

  // Derived shades
  static const Color skyBlueDark = Color(0xFF5A8FCC);
  static const Color skyBlueDeep = Color(0xFF3A6DAA);
  static const Color mintDark = Color(0xFF3CC465);

  // =========================================================
  // LIGHT THEME — Palette-tinted surfaces
  // Sky blue washes through every layer
  // =========================================================
  static const Color lightBg = Color(0xFFDAE7F5);          // Sky blue wash background
  static const Color lightSurface = Color(0xFFE9F0F9);     // Soft blue-frosted cards
  static const Color lightSurfaceHigh = Color(0xFFC9D8EA); // Inputs, chips — deeper blue
  static const Color lightSurfaceBright = Color(0xFFF2F6FC); // Dialogs, elevated
  static const Color lightText = Color(0xFF0E1A28);         // Deep navy ink
  static const Color lightTextSecondary = Color(0xFF3E5670); // Steel blue

  // =========================================================
  // DARK THEME
  // =========================================================
  static const Color darkBg = Color(0xFF0F1419);
  static const Color darkSurface = Color(0xFF1C2530);
  static const Color darkSurfaceElevated = Color(0xFF243040);
  static const Color darkText = Color(0xFFE8EDF2);
  static const Color darkTextSecondary = Color(0xFF8899AA);

  // =========================================================
  // LIGHT THEME
  // =========================================================
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: skyBlueDeep,
    scaffoldBackgroundColor: lightBg,

    colorScheme: const ColorScheme.light(
      primary: skyBlueDeep,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFCCDEF5),
      onPrimaryContainer: Color(0xFF1A3A5C),

      secondary: mintDark,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFC4F2D0),
      onSecondaryContainer: Color(0xFF0D3A1A),

      tertiary: burntOrange,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFFDDD0),
      onTertiaryContainer: Color(0xFF5C2200),

      error: Color(0xFFD32F2F),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),

      surface: lightSurface,
      onSurface: lightText,
      onSurfaceVariant: lightTextSecondary,
      surfaceContainerLowest: lightSurfaceBright,
      surfaceContainerLow: Color(0xFFE3ECF7),
      surfaceContainer: Color(0xFFDCE7F3),
      surfaceContainerHigh: Color(0xFFD2DFEE),
      surfaceContainerHighest: lightSurfaceHigh,
      outline: Color(0xFF8EA4BC),
      outlineVariant: Color(0xFFB5C6D8),
      shadow: Color(0xFF0E1A28),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: lightBg,
      foregroundColor: lightText,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: lightSurface,
      selectedItemColor: skyBlueDeep,
      unselectedItemColor: lightTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightSurface,
      indicatorColor: skyBlue.withValues(alpha: 0.2),
      elevation: 0,
    ),

    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFAABED4).withValues(alpha: 0.4)),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: lightSurfaceHigh,
      selectedColor: skyBlue.withValues(alpha: 0.18),
      labelStyle: const TextStyle(fontSize: 13),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: skyBlueDeep, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: skyBlueDeep,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: skyBlueDeep,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: skyBlueDeep,
        side: BorderSide(color: skyBlue.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: skyBlueDeep,
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: burntOrange,
      foregroundColor: Colors.white,
      elevation: 2,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: lightSurfaceBright,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: lightSurfaceBright,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 3,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: lightText,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFFBBCADB),
      thickness: 1,
    ),

    badgeTheme: const BadgeThemeData(
      backgroundColor: burntOrange,
      textColor: Colors.white,
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return skyBlueDeep;
        return const Color(0xFFB0BCC8);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return skyBlue.withValues(alpha: 0.35);
        return const Color(0xFFD4DCE6);
      }),
    ),
  );

  // =========================================================
  // DARK THEME
  // =========================================================
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: skyBlue,
    scaffoldBackgroundColor: darkBg,

    colorScheme: const ColorScheme.dark(
      primary: skyBlue,
      onPrimary: Color(0xFF0A1E30),
      primaryContainer: Color(0xFF1E3A55),
      onPrimaryContainer: Color(0xFFD4E6FA),

      secondary: mintGreen,
      onSecondary: Color(0xFF003D1A),
      secondaryContainer: Color(0xFF1A4030),
      onSecondaryContainer: Color(0xFFD0F8DB),

      tertiary: burntOrange,
      onTertiary: Color(0xFF3C1200),
      tertiaryContainer: Color(0xFF5C2A10),
      onTertiaryContainer: Color(0xFFFFE0D0),

      error: Color(0xFFFF6B6B),
      onError: Color(0xFF3C0000),
      errorContainer: Color(0xFF5C1A1A),

      surface: darkSurface,
      onSurface: darkText,
      onSurfaceVariant: darkTextSecondary,
      surfaceContainerLowest: Color(0xFF0A0F14),
      surfaceContainerLow: Color(0xFF151E28),
      surfaceContainer: Color(0xFF1C2530),
      surfaceContainerHigh: Color(0xFF222E3C),
      surfaceContainerHighest: darkSurfaceElevated,
      outline: Color(0xFF3A4A5A),
      outlineVariant: Color(0xFF2A3A4A),
      shadow: Color(0xFF000000),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      foregroundColor: darkText,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: skyBlue,
      unselectedItemColor: darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkSurface,
      indicatorColor: skyBlue.withValues(alpha: 0.15),
      elevation: 0,
    ),

    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF2A3A4A).withValues(alpha: 0.5)),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: darkSurfaceElevated,
      selectedColor: skyBlue.withValues(alpha: 0.15),
      labelStyle: const TextStyle(fontSize: 13),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: skyBlue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: skyBlue,
        foregroundColor: const Color(0xFF0A1E30),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: skyBlue,
        foregroundColor: const Color(0xFF0A1E30),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: skyBlue,
        side: BorderSide(color: skyBlue.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: skyBlue,
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: burntOrange,
      foregroundColor: Colors.white,
      elevation: 2,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: darkSurfaceElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: darkSurfaceElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 3,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkSurfaceElevated,
      contentTextStyle: const TextStyle(color: darkText),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFF2A3A4A),
      thickness: 1,
    ),

    badgeTheme: const BadgeThemeData(
      backgroundColor: burntOrange,
      textColor: Colors.white,
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return skyBlue;
        return const Color(0xFF4A5A6A);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return skyBlue.withValues(alpha: 0.3);
        return const Color(0xFF2A3A4A);
      }),
    ),
  );

  // =========================================================
  // PALETTE ACCESS
  // =========================================================
  static const Color success = mintGreen;
  static const Color successDark = mintDark;
  static const Color warning = goldenYellow;
  static const Color accent = burntOrange;
  static const Color highlight = limeGreen;
}
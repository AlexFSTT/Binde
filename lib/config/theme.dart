import 'package:flutter/material.dart';

/// Tema aplicației Binde - Chocolate Truffle palette (Figma)
/// Paleta elegantă: Dark Brown, Caramel, Cream
class AppTheme {
  // 🍫 CHOCOLATE TRUFFLE PALETTE - Figma
  // Culori principale inspirate din paleta Chocolate Truffle
  static const Color darkBrown = Color(0xFF3E2723);        // Dark chocolate brown
  static const Color mediumBrown = Color(0xFF6D4C41);      // Medium chocolate
  static const Color caramel = Color(0xFFA1887F);          // Warm caramel
  static const Color lightCaramel = Color(0xFFBCAAA4);     // Light caramel
  static const Color cream = Color(0xFFF5E6D3);            // Soft cream
  static const Color warmWhite = Color(0xFFFFFBF0);        // Warm white
  
  // Accent culori complementare
  static const Color accentGold = Color(0xFFD4A574);       // Warm gold accent
  static const Color deepBrown = Color(0xFF2C1810);        // Very dark brown
  
  // Culori pentru Light Theme
  static const Color lightBackground = warmWhite;
  static const Color lightSurface = cream;
  static const Color lightText = darkBrown;
  static const Color lightTextSecondary = mediumBrown;
  
  // Culori pentru Dark Theme
  static const Color darkBackground = Color(0xFF1A1410);   // Very dark chocolate
  static const Color darkSurface = Color(0xFF2C1F1A);      // Dark surface
  static const Color darkText = cream;
  static const Color darkTextSecondary = lightCaramel;
  
  // Light Theme - Chocolate Truffle
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: mediumBrown,
    scaffoldBackgroundColor: lightBackground,
    
    colorScheme: const ColorScheme.light(
      primary: mediumBrown,              // Medium brown pentru acțiuni principale
      secondary: caramel,                // Caramel pentru secondary actions
      tertiary: accentGold,              // Gold pentru accente
      surface: lightSurface,             // Cream pentru surfaces
      onPrimary: warmWhite,              // Text pe primary
      onSecondary: darkBrown,            // Text pe secondary
      onSurface: lightText,              // Dark brown pe surfaces
      primaryContainer: lightCaramel,    // Light caramel pentru containers
      secondaryContainer: cream,         // Cream pentru secondary containers
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: cream,
      foregroundColor: darkBrown,
      elevation: 0,
      centerTitle: true,
    ),
    
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cream,
      selectedItemColor: mediumBrown,
      unselectedItemColor: lightTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    
    cardTheme: CardThemeData(
      color: cream,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: warmWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: lightCaramel),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: lightCaramel),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: mediumBrown, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: mediumBrown,
        foregroundColor: warmWhite,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: mediumBrown,
      ),
    ),
  );
  
  // Dark Theme - Chocolate Truffle
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: caramel,
    scaffoldBackgroundColor: darkBackground,
    
    colorScheme: const ColorScheme.dark(
      primary: caramel,                  // Caramel pentru acțiuni principale (mai vizibil în dark)
      secondary: accentGold,             // Gold pentru secondary
      tertiary: lightCaramel,            // Light caramel pentru accente
      surface: darkSurface,              // Dark brown pentru surfaces
      onPrimary: deepBrown,              // Very dark text pe primary
      onSecondary: deepBrown,            // Very dark text pe secondary
      onSurface: darkText,               // Cream pe surfaces
      primaryContainer: mediumBrown,     // Medium brown pentru containers
      secondaryContainer: Color(0xFF3E2A23), // Slightly lighter dark
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: cream,
      elevation: 0,
      centerTitle: true,
    ),
    
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: accentGold,      // Gold pentru selected (mai vizibil)
      unselectedItemColor: darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF3E2A23),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4A3429)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4A3429)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: caramel, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: caramel,
        foregroundColor: deepBrown,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentGold,
      ),
    ),
  );
}
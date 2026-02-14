# Keep Supabase constants
-keep class io.supabase.** { *; }
-keep class com.binde.binde.** { *; }

# Keep app constants
-keepclassmembers class * {
    public static final java.lang.String supabaseUrl;
    public static final java.lang.String supabaseAnonKey;
}

# Keep all constants classes
-keep class **.AppConstants { *; }
-keep class **.constants.** { *; }

# Supabase specific
-dontwarn io.supabase.**
-keep class * extends io.supabase.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

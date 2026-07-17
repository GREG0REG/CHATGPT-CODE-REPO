# ============================================
# Flutter Event Countdown - ProGuard Rules
# ============================================

# Play Core / Deferred Components (NOT used by this app)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.material.**
-dontwarn com.google.firebase.**

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn io.flutter.embedding.**

# Local notifications
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# WorkManager
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# SQLite / sqflite
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Keep JSON serialization for event export
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep generic signatures
-keepattributes Signature, InnerClasses, EnclosingMethod, Exceptions, *Annotation*

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep setters/getters for reflection
-keepclassmembers class * {
    void set*(***);
    *** get*();
    ***
    is*();
}

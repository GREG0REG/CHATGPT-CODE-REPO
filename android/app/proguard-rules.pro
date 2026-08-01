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

# Keep app package
-keep class com.example.event_countdown.** { *; }

# Keep widget providers (accessed via reflection by Android system)
-keep class * extends android.appwidget.AppWidgetProvider { *; }

# Keep MethodChannel handlers
-keep class * extends io.flutter.embedding.android.FlutterActivity { *; }

# home_widget
-keep class es.antonborri.home_widget.** { *; }

# Local notifications
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# WorkManager
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-dontwarn androidx.work.**

# SQLite / sqflite
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# Prevent R8 from stripping necessary metadata
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

# Gson/JSON serialization (if used)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

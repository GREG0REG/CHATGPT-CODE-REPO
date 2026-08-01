# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.example.event_countdown.** { *; }

# Keep widget providers (accessed via reflection by Android system)
-keep class * extends android.appwidget.AppWidgetProvider { *; }

# Keep MethodChannel handlers
-keep class * extends io.flutter.embedding.android.FlutterActivity { *; }

# home_widget
-keep class es.antonborri.home_widget.** { *; }

# WorkManager
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }

# Prevent R8 from stripping necessary metadata
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# SQLite (used by sqflite)
-keep class net.sqlcipher.** { *; }

# Gson/JSON serialization (if used)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}
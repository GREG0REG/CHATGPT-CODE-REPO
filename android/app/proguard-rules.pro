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

# ============================================
# WIDGET RESOURCES - CRITICAL FIX
# R8/shrinkResources cannot trace RemoteViews
# runtime resource usage. Must keep explicitly.
# ============================================

# Keep ALL widget layout resources
-keepresources layout/reading_widget_*
-keepresources layout/attendance_widget_*
-keepresources layout/event_widget_*
-keepresources layout/pomodoro_widget_*
-keepresources layout/timetable_widget_*
-keepresources layout/habit_widget_*
-keepresources layout/widget_*

# Keep ALL widget drawable resources
-keepresources drawable/reading_*
-keepresources drawable/attendance_*
-keepresources drawable/event_*
-keepresources drawable/pomodoro_*
-keepresources drawable/timetable_*
-keepresources drawable/habit_*
-keepresources drawable/widget_*
-keepresources drawable/streak_*
-keepresources drawable/circle_*
-keepresources drawable/ic_*
-keepresources drawable/launch_*
-keepresources drawable/urgency_*

# Keep ALL widget info XML files
-keepresources xml/*_widget_info.xml

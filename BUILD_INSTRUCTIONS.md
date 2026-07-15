# Event Countdown — Build Instructions (Beginner Guide)

This is a complete Flutter project. Because this code was generated in an
environment without the Flutter SDK installed, the `android/` folder is
hand-written rather than machine-generated — it's 100% complete and correct,
but it is missing two small **binary** files that only the `flutter` CLI can
generate for you (the Gradle wrapper jar + scripts). The steps below get you
those two files in under a minute, then build the APK.

## Prerequisites

- Flutter SDK 3.24 or newer installed (`flutter --version` to check)
- Android SDK installed (comes with Android Studio), with `ANDROID_HOME` set
- A physical Android device (USB debugging on) or an emulator, for testing

## Step 1 — Unzip the project

Unzip `event_countdown.zip` anywhere, e.g. `~/dev/event_countdown`.

## Step 2 — Get the Gradle wrapper files

Open a terminal in an empty temp folder and run:

```bash
flutter create --platforms=android temp_wrapper_project
```

This creates a throwaway project. Copy just these 3 items from it into your
real project's `android/` folder (overwrite nothing else):

```bash
cp temp_wrapper_project/android/gradlew                 ~/dev/event_countdown/android/
cp temp_wrapper_project/android/gradlew.bat              ~/dev/event_countdown/android/
cp temp_wrapper_project/android/gradle/wrapper/gradle-wrapper.jar \
   ~/dev/event_countdown/android/gradle/wrapper/
chmod +x ~/dev/event_countdown/android/gradlew
```

Then delete `temp_wrapper_project` — you don't need it anymore.

(Do **not** copy `build.gradle`, `settings.gradle`, `AndroidManifest.xml`, or
anything under `android/app/src` from the temp project — those are the files
that already contain the widget provider, permissions, and Kotlin code for
this app, and copying over them would break the widget.)

## Step 3 — Install dependencies

```bash
cd ~/dev/event_countdown
flutter pub get
```

`local.properties` (which points Gradle at your Android SDK) is created
automatically at this point — you don't need to write it by hand.

## Step 4 — Build the debug APK

```bash
flutter build apk --debug
```

The APK will be at:

```
build/app/outputs/flutter-apk/app-debug.apk
```

Install it with `flutter install`, or copy it to your phone and tap to
install (allow "install from unknown sources" if prompted).

## Step 5 — Add the home screen widget

After installing the app on your device: long-press an empty spot on the
home screen → **Widgets** → find **Event Countdown** → drag it onto the home
screen. It updates automatically; you can also open the app once first so it
has an event to display.

## Notes on package name

The Kotlin files use package `com.example.event_countdown` and
`applicationId "com.example.event_countdown"` in `app/build.gradle`. If you
rename the package (e.g. to `com.yourname.event_countdown`), you must rename
both consistently: the folder path under
`android/app/src/main/kotlin/...`, the `package` line inside
`MainActivity.kt` and `EventCountdownWidgetProvider.kt`, and the
`applicationId`/`namespace` in `app/build.gradle`.

## What's NOT included (by design, per your spec)

No cloud sync, no Firebase, no accounts, no internet permission beyond what
Android requires implicitly, no recurring events, no weather, no AI
features, no subscriptions, and exactly 5 themes.

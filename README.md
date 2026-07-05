# Namaz Vakti (Prayer Times) App

A simple, ad-free, clean, and completely **offline-first** native mobile prayer times application built for Android (Kotlin + Jetpack Compose) and iOS (Swift + SwiftUI).

---

## Purpose & Key Features

1. **Offline-First Architecture**: During the initial onboarding setup, the app fetches the entire Gregorian calendar for the user's location via the Aladhan API (`/v1/calendar/{year}`) in a single request and caches it locally. It works 100% offline for the rest of the year. If the cache is missing or corrupt, it automatically falls back to native mathematical calculations (`Adhan-Swift` on iOS and `adhan-java` on Android).
2. **Premium Onboarding Wizard**:
   * **Step 1**: Detect location automatically via GPS or lookup city names manually using the Open-Meteo Geocoding API.
   * **Step 2**: Auto-detects the most suitable calculation method and Madhab (Asr school) based on the location's country (e.g., Diyanet and Hanafi for Turkey, Umm Al-Qura and Standard for Saudi Arabia, etc.). Users can customize these settings.
3. **Local Notification Engine**: Plan and fire exact local prayer alarms and reminders (e.g., 30 minutes before and exactly at prayer time) completely on-device without any external server dependencies.
4. **App Widgets**: Native widget extensions for both Android and iOS home screens to track the next prayer time and see a countdown timer at a glance.

---

## Technology Stack & Architecture

### Android Platform
* **Language & UI**: Kotlin & Jetpack Compose (Material 3)
* **Local Storage**: Cached annual calendar stored as a JSON file under the app's `cacheDir` (`namaz_cache_[locationId]_[year].json`).
* **Calculation Engine**: `com.batoulapps.adhan:adhan:1.2.1` (used as an offline fallback).
* **Background Tasks**: Android `WorkManager` (runs `NotificationSyncWorker` every 24 hours to schedule the next batch of local notifications).
* **Widget**: Grahical Widget utilizing `AppWidgetProvider` and traditional RemoteViews.

### iOS Platform
* **Language & UI**: Swift & SwiftUI (iOS 16+)
* **Project Management**: Configured and generated using **XcodeGen** (`project.yml`). The Xcode project configuration is code-defined; do not edit `.xcodeproj` manually.
* **Local Storage**: Saved as a JSON string under the shared App Group suite (`group.com.oktay.namaz`) so both the app and the WidgetKit Extension can read the same cache.
* **Calculation Engine**: Batoulapps `Adhan-Swift` (SPM package used as an offline fallback).
* **Widget**: Modern WidgetKit Timeline Extension.

---

## Developer Commands

### Android target (inside `/android`)
* **Assemble Debug APK**: `./gradlew assembleDebug`
* **Install on Connected Device/Emulator**: `./gradlew installDebug`
* **Launch Main Activity**: `adb shell am start -n com.oktay.namaz/com.oktay.namaz.MainActivity`
* **Check Native Crashes**: `adb logcat -b crash -d`

### iOS target (inside `/ios`)
* **Regenerate Xcode Project (Required after adding files)**: `xcodegen`
* **Clean Build for Simulator**: `xcodebuild -project NamazVakti.xcodeproj -scheme NamazVakti -sdk iphonesimulator clean build`
* **Install on Booted Simulator**: `xcrun simctl install booted [path_to_app]`
* **Launch App on Simulator**: `xcrun simctl launch booted com.oktay.NamazVakti`

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

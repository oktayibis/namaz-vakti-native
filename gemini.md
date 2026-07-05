# Context Instructions for Gemini

This document provides system-level context, architecture details, and coding rules for the **Namaz Vakti** native Android/iOS application to help Gemini code correctly in future sessions.

---

## 1. Codebase Structure & Key Files

### Android Platform (Kotlin / Jetpack Compose)
* **`/android/app/src/main/java/com/oktay/namaz/`**
  * `MainActivity.kt`: Entry point. Sets up the NavHost and orchestrates location/notification permission requests.
  * `model/LocationData.kt`: Location representation containing coordinates, timezone, city name, and country.
  * `service/PrayerCalculator.kt`: Implements local calculations (using Adhan library) and yearly calendar API JSON caching.
  * `service/AlarmScheduler.kt` & `service/AlarmReceiver.kt`: Plan and fire exact local broadcast intents for prayer notifications.
  * `ui/AppViewModel.kt`: Core business logic, location detection, onboarding completion, and widget updates.
  * `ui/OnboardingScreen.kt`: Premium 2-step setup wizard (Location lookup + settings picker).
  * `ui/HomeScreen.kt` & `ui/SettingsScreen.kt`: Core application dashboard and configuration screen.
  * `widget/PrayerAppWidget.kt`: Custom AppWidgetProvider that updates remote views.

### iOS Platform (Swift / SwiftUI)
* **`/ios/NamazVakti/NamazVakti/`**
  * `UI/HomeView.swift`: Displays progress countdown and today's prayer times. Displays `OnboardingView` if no active location exists.
  * `UI/OnboardingView.swift`: Premium 2-step Setup Wizard with location geocoding and pickers.
  * `Services/AppViewModel.swift`: Observes active location, calculates time remains, completes onboarding, and updates timelines.
  * `Services/PrayerCalculator.swift`: Yearly API calendar caching and offline fallback mathematics using `Adhan-Swift`.
  * `Services/LocationManager.swift` & `Services/NotificationManager.swift`: Native wrappers for GPS coordinates, reverse-geocoding, and UNUserNotificationCenter scheduling.
* **`/ios/NamazVaktiWidget/`**
  * `NamazVaktiWidget.swift`: Modern WidgetKit extension. Reads the yearly calendar cache from App Group defaults (`group.com.oktay.namaz`).

---

## 2. Core Coding Rules & API Specifications

### Aladhan API & Cache Mapping
* **Endpoint**: `https://api.aladhan.com/v1/calendar/{year}?latitude={lat}&longitude={lng}&method={methodId}&school={schoolId}`
* **Response structure**: Maps months `"1"` to `"12"` to daily lists of timings.
* **Format**:
  * Android: Saved as a JSON file `namaz_cache_[locationId]_[year].json` in the app's `cacheDir`.
  * iOS: Saved as a JSON string in the shared `group.com.oktay.namaz` suite under the key `namaz_cache_[locationId]_[year]`.
* **Important**: Always use the cached annual calendar values for displaying times and scheduling notifications. Fallback to `Batoulapps Adhan` calculation parameters *only* if the cache is missing or API request fails.

### Parameter Auto-Detection by Country
* **Turkey**: Method = 13 (Diyanet), Madhab = 1 (Hanafi)
* **Saudi Arabia / Gulf**: Method = 4 (Umm Al-Qura), Madhab = 0 (Standard/Shafi)
* **Pakistan / India**: Method = 1 (Karachi), Madhab = 1 (Hanafi)
* **North America**: Method = 2 (ISNA), Madhab = 0 (Standard)
* **Default / Other**: Method = 3 (Muslim World League), Madhab = 0 (Standard)

### Android Specific Rules
* **Dynamic Broadcast Receivers**: Specified `Context.RECEIVER_NOT_EXPORTED` on API 33+ (Tiramisu) when registering custom broadcast receivers dynamically:
  ```kotlin
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
  } else {
      context.registerReceiver(receiver, filter)
  }
  ```
* **Search Debouncing**: Always add a `delay(300)` debounce when reacting to query text changes inside Compose `LaunchedEffect` to avoid freezing focus or triggering excessive network requests.
* **Loading Spinner Heights**: Ensure loading indicators (`CircularProgressIndicator`) inside Column lists have `.weight(1f)` or equivalent stable height modifiers so they don't cause sudden layout jumps when shown.

### iOS Specific Rules
* **Project Generation (`xcodegen`)**: Never edit `.xcodeproj` files manually. All file additions and project setting changes must be done in `project.yml`, followed by running `xcodegen` in `/ios`.
* **Thread Safety**: Ensure all changes modifying `@Published` properties in `AppViewModel.swift` are dispatched on `DispatchQueue.main.async`.
* **Widget Sharing**: All shared settings, active locations list, and JSON calendar caches must be written to `UserDefaults(suiteName: "group.com.oktay.namaz")`.

---

## 3. Useful Commands

* **Android build**: `./gradlew assembleDebug`
* **iOS project regenerate**: `xcodegen`
* **iOS clean build**: `xcodebuild -project NamazVakti.xcodeproj -scheme NamazVakti -sdk iphonesimulator clean build`

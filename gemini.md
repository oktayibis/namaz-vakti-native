# Context Instructions for Gemini

This document provides system-level context, architecture details, and coding rules for the **Namaz Vakti** native Android/iOS application to help Gemini code correctly in future sessions.

---

## 1. Project Overview

**Namaz Vakti** — an offline-first prayer times app built twice, natively: `/android` (Kotlin + Jetpack Compose, Material 3, minSdk 26) and `/ios` (Swift + SwiftUI, iOS 16+). The two apps share no code but deliberately mirror each other's structure and logic (`PrayerCalculator`, `AppViewModel`, `LocationManager`, `NotificationManager`, onboarding/home/settings screens, home-screen widget). **When changing core logic on one platform, apply the equivalent change to the other** unless the task is explicitly platform-specific.

A parallel `claude.md` exists for another assistant; keep architectural facts consistent across both when updating docs.

### Codebase Structure & Key Files

#### Android Platform (Kotlin / Jetpack Compose)
* **`/android/app/src/main/java/com/oktay/namaz/`**
  * `MainActivity.kt`: Entry point. Sets up the NavHost, orchestrates location/notification permission requests, and enqueues the 24-hour `NotificationSyncWorker`.
  * `model/LocationData.kt`: Location representation containing coordinates, timezone, city name, and country.
  * `service/PrayerCalculator.kt`: Annual calendar API JSON caching, in-memory cache, and local fallback calculations (Adhan library).
  * `service/AlarmScheduler.kt` & `receiver/AlarmReceiver.kt`: Plan and fire exact local alarms for prayer notifications; `receiver/BootReceiver.kt` reschedules after reboot.
  * `ui/AppViewModel.kt`: Core business logic, location detection, onboarding completion, and widget updates.
  * `ui/OnboardingScreen.kt`: Premium 2-step setup wizard (Location lookup + settings picker).
  * `ui/HomeScreen.kt` & `ui/SettingsScreen.kt`: Core application dashboard and configuration screen.
  * `widget/PrayerAppWidget.kt`: Classic `AppWidgetProvider` updating RemoteViews.

#### iOS Platform (Swift / SwiftUI)
* **`/ios/NamazVakti/NamazVakti/`**
  * `UI/HomeView.swift`: Displays progress countdown and today's prayer times. Displays `OnboardingView` if no active location exists.
  * `UI/OnboardingView.swift`: Premium 2-step Setup Wizard with location geocoding and pickers.
  * `Services/AppViewModel.swift`: Observes active location, calculates time remaining, completes onboarding, and updates timelines.
  * `Services/PrayerCalculator.swift`: Yearly API calendar caching and offline fallback mathematics using `Adhan-Swift`.
  * `Services/LocationManager.swift` & `Services/NotificationManager.swift`: Native wrappers for GPS coordinates, reverse-geocoding, and UNUserNotificationCenter scheduling.
* **`/ios/NamazVaktiWidget/`**
  * `NamazVaktiWidget.swift`: WidgetKit timeline extension. Reads the yearly calendar cache from App Group defaults (`group.com.oktay.namaz`).
  * The widget target compiles `LocationData.swift` and `PrayerCalculator.swift` directly from the app target (listed in its `sources` in `project.yml`) — no shared framework, so keep those files free of app-only dependencies.

---

## 2. Core Coding Rules & API Specifications

### Aladhan API & Cache Mapping
* **Endpoint**: `https://api.aladhan.com/v1/calendar/{year}?latitude={lat}&longitude={lng}&method={methodId}&school={schoolId}`
* **Response structure**: Maps month strings `"1"` to `"12"` to daily lists of timings; day rows are matched by `dd-MM-yyyy` Gregorian date, and times are parsed in the location's own timezone.
* **Format**:
  * Android: Saved as a JSON file `namaz_cache_[locationId]_[year].json` in the app's `cacheDir`. Settings live in SharedPreferences `namaz_prefs` (keys include `calculation_method`, `asr_madhab`).
  * iOS: Saved as a JSON string in the shared `group.com.oktay.namaz` suite under the key `namaz_cache_[locationId]_[year]`.
* **Lookup order** in `PrayerCalculator.calculatePrayerTimes`: annual JSON cache → on miss, kick off a background re-fetch **and** fall back to on-device astronomical calculation via the Batoulapps Adhan library (`com.batoulapps.adhan:adhan` on Android, `Adhan-Swift` SPM package on iOS). Always prefer cached annual calendar values for display and notification scheduling.
* **Cache refresh signal**: when a background fetch lands, both platforms emit `com.oktay.namaz.ACTION_CACHE_UPDATED` (Android: broadcast received by `AppViewModel`; iOS: `NotificationCenter` post). Android's `PrayerCalculator` also keeps a synchronized in-memory copy of the parsed annual JSON (the file is 1–2 MB and the widget/countdown would otherwise re-parse it every second) — invalidate it whenever the cache file is rewritten.
* **City text search**: Open-Meteo Geocoding API (`geocoding-api.open-meteo.com/v1/search`); GPS reverse-geocoding is native (`CLGeocoder` on iOS).

### Calculation Methods (Aladhan API IDs)
* `13` → Türkiye (Diyanet) — no Adhan-library equivalent; local fallback approximates it with Muslim World League
* `3` → Muslim World League (default fallback)
* `2` → ISNA (North America)
* `4` → Umm Al-Qura (Makkah)
* `5` → Egyptian General Authority of Survey
* `1` → University of Islamic Sciences, Karachi

### Madhab (Asr School IDs)
* `1` → Hanafi (double-shadow Asr)
* `0` → Shafi / Maliki / Hanbali (standard)

### Parameter Auto-Detection by Country
* **Turkey**: Method = 13 (Diyanet), Madhab = 1 (Hanafi)
* **Saudi Arabia / Gulf**: Method = 4 (Umm Al-Qura), Madhab = 0 (Standard/Shafi)
* **Pakistan / India**: Method = 1 (Karachi), Madhab = 1 (Hanafi)
* **North America**: Method = 2 (ISNA), Madhab = 0 (Standard)
* **Default / Other**: Method = 3 (Muslim World League), Madhab = 0 (Standard)

### Android Specific Rules
* **Dynamic Broadcast Receivers**: Specify `Context.RECEIVER_NOT_EXPORTED` on API 33+ (Tiramisu) when registering custom broadcast receivers dynamically:
  ```kotlin
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
  } else {
      context.registerReceiver(receiver, filter)
  }
  ```
* **Search Debouncing**: Always add a `delay(300)` debounce when reacting to query text changes inside Compose `LaunchedEffect` to avoid freezing focus or triggering excessive network requests.
* **Loading Spinner Heights**: When swapping a list for a loading spinner (`CircularProgressIndicator`), keep the container size stable (`.weight(1f)` or equivalent) so the text field doesn't lose focus and dismiss the keyboard.
* **State**: Collect flows in composables with `.collectAsState()`; initialize flow values in `AppViewModel`.
* **Dependency pins**: `app/build.gradle.kts` pins the Compose BOM and `fragment-ktx` versions for crash reasons documented in comments there — don't downgrade them.

### iOS Specific Rules
* **Project Generation (`xcodegen`)**: Never edit `.xcodeproj` files manually. All file additions and project setting changes must be done in `project.yml`, followed by running `xcodegen` in `/ios`.
* **Thread Safety**: Ensure all changes modifying `@Published` properties in `AppViewModel.swift` are dispatched on `DispatchQueue.main.async`.
* **Widget Sharing**: All shared settings, active locations list, and JSON calendar caches must be written to `UserDefaults(suiteName: "group.com.oktay.namaz")`.

---

## 3. Useful Commands

### Android (run inside `/android`)
* Build debug APK: `./gradlew assembleDebug`
* Install on device/emulator: `./gradlew installDebug`
* Launch: `adb shell am start -n com.oktay.namaz/com.oktay.namaz.MainActivity`
* Check crashes: `adb logcat -b crash -d`
* Screenshot for layout inspection: `adb shell screencap -p /sdcard/screencap.png && adb pull /sdcard/screencap.png`

### iOS (run inside `/ios`)
* Regenerate Xcode project (required after adding/removing files or changing settings): `xcodegen`
* Build for simulator: `xcodebuild -project NamazVakti.xcodeproj -scheme NamazVakti -sdk iphonesimulator clean build`
* Install on booted simulator: `xcrun simctl install booted [path_to_app]`
* Launch: `xcrun simctl launch booted com.oktay.NamazVakti`

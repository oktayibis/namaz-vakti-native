# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Namaz Vakti** — an offline-first prayer times app built twice, natively: `/android` (Kotlin + Jetpack Compose, Material 3, minSdk 26) and `/ios` (Swift + SwiftUI, iOS 16+). The two apps share no code but deliberately mirror each other's structure and logic (`PrayerCalculator`, `AppViewModel`, `LocationManager`, `NotificationManager`, onboarding/home/settings screens, home-screen widget). **When changing core logic on one platform, apply the equivalent change to the other** unless the task is explicitly platform-specific.

A parallel `gemini.md` exists for another assistant; keep architectural facts consistent across both when updating docs.

## Commands

### Android (run inside `/android`)
- Build debug APK: `./gradlew assembleDebug`
- Install on device/emulator: `./gradlew installDebug`
- Launch: `adb shell am start -n com.oktay.namaz/com.oktay.namaz.MainActivity`
- Check crashes: `adb logcat -b crash -d`
- Screenshot for layout inspection: `adb shell screencap -p /sdcard/screencap.png && adb pull /sdcard/screencap.png`

### iOS (run inside `/ios`)
- **Regenerate Xcode project (required after adding/removing files or changing settings)**: `xcodegen`
- Build for simulator: `xcodebuild -project NamazVakti.xcodeproj -scheme NamazVakti -sdk iphonesimulator clean build`
- Install on booted simulator: `xcrun simctl install booted [path_to_app]`
- Launch: `xcrun simctl launch booted com.oktay.NamazVakti`

## Architecture

### Data flow (identical on both platforms)

```
Onboarding: GPS (native geolocation + reverse geocode) OR city text search
            (Open-Meteo Geocoding API: geocoding-api.open-meteo.com/v1/search)
    → country-based auto-detection of calculation method + madhab (user can override)
    → Aladhan API annual calendar fetch:
      https://api.aladhan.com/v1/calendar/{year}?latitude=&longitude=&method=&school=
    → cached locally as raw JSON, keyed namaz_cache_{locationId}_{year}
    → all display, notifications, and widgets read from the cache — fully offline
```

**Cache lookup order** in `PrayerCalculator.calculatePrayerTimes`: annual JSON cache → on miss, kick off a background re-fetch **and** fall back to on-device astronomical calculation via the Batoulapps Adhan library (`com.batoulapps.adhan:adhan` on Android, `Adhan-Swift` SPM package on iOS). The Aladhan response maps month strings `"1"`–`"12"` to day lists; day rows are matched by `dd-MM-yyyy` Gregorian date, and times are parsed in the location's own timezone.

**Cache refresh signal**: when a background fetch lands, both platforms emit `com.oktay.namaz.ACTION_CACHE_UPDATED` (Android: broadcast received by `AppViewModel`; iOS: `NotificationCenter` post). Android's `PrayerCalculator` also keeps a synchronized in-memory copy of the parsed annual JSON (the file is 1–2 MB and the widget/countdown would otherwise re-parse it every second) — invalidate it whenever the cache file is rewritten.

### Storage

- **Android**: annual calendars as JSON files in `cacheDir` (`namaz_cache_{locationId}_{year}.json`); settings in SharedPreferences `namaz_prefs` (keys include `calculation_method`, `asr_madhab`).
- **iOS**: everything (calendar JSON strings, active locations, settings) in the shared App Group suite `UserDefaults(suiteName: "group.com.oktay.namaz")` so the main app and the WidgetKit extension read the same data.

### Notifications & widgets

- **Android**: `AlarmScheduler` plans exact alarms (`setExactAndAllowWhileIdle`/`setAlarmClock`) fired by `AlarmReceiver`; `BootReceiver` reschedules after reboot; `NotificationSyncWorker` (WorkManager, 24 h periodic, enqueued from `MainActivity`) keeps the next batch scheduled. Widget is a classic `AppWidgetProvider` with RemoteViews (`widget/PrayerAppWidget.kt`).
- **iOS**: `NotificationManager` schedules `UNUserNotificationCenter` local notifications; widget is a WidgetKit timeline extension (`/ios/NamazVaktiWidget`). The widget target compiles `LocationData.swift` and `PrayerCalculator.swift` directly from the app target (listed in its `sources` in `project.yml`) — no shared framework, so keep those files free of app-only dependencies.

## Implementation Constants

### Calculation methods (Aladhan API IDs)
- `13` → Türkiye (Diyanet) — no Adhan-library equivalent; local fallback approximates it with Muslim World League
- `3` → Muslim World League (default fallback)
- `2` → ISNA (North America)
- `4` → Umm Al-Qura (Makkah)
- `5` → Egyptian General Authority of Survey
- `1` → University of Islamic Sciences, Karachi

### Madhab / Asr school IDs
- `1` → Hanafi (double-shadow Asr)
- `0` → Shafi / Maliki / Hanbali (standard)

### Country auto-detection defaults
- Turkey → method 13, madhab 1 · Saudi Arabia/Gulf → 4, 0 · Pakistan/India → 1, 1 · North America → 2, 0 · everywhere else → 3, 0

## Platform Guidelines

### Android
- **Broadcast receivers**: on API 33+ register dynamic receivers with `Context.RECEIVER_NOT_EXPORTED`.
- **Compose search UX**: debounce query changes with `delay(300)` inside `LaunchedEffect(searchQuery)` before calling `locationManager.searchCity(...)`; when swapping a list for a loading spinner, keep the container size stable (`.weight(1f)`) so the text field doesn't lose focus and dismiss the keyboard.
- **State**: collect flows in composables with `.collectAsState()`; initialize flow values in `AppViewModel`.
- `app/build.gradle.kts` pins the Compose BOM and `fragment-ktx` versions for crash reasons documented in comments there — don't downgrade them.

### iOS
- **Never edit `.xcodeproj` manually** — it's generated. Change `/ios/project.yml`, then run `xcodegen`.
- Mutate `@Published` properties in `AppViewModel` on the main thread (`DispatchQueue.main.async`).
- All widget-visible data must go through the `group.com.oktay.namaz` App Group suite.
- Reverse geocoding uses native `CLGeocoder`; city text search uses `LocationManager.shared.searchCity(query:)` (Open-Meteo).

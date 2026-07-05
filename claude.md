# System Context Instructions for Claude

This document serves as the developer handbook and architectural context for the **Namaz Vakti** app. Read this file before initiating modifications.

---

## 1. High-Level Architectural Concepts

The app follows a unified native architecture for both iOS (Swift/SwiftUI) and Android (Kotlin/Jetpack Compose):

```
                                  [ Onboarding Screen ]
                                           │
                     ┌─────────────────────┴─────────────────────┐
             [ GPS Geolocation ]                         [ City Text Search ]
                     │                                           │
                     └─────────────────────┬─────────────────────┘
                                           ▼
                            [ Country Parameter Matcher ]
                     (Auto-select Method: Diyanet/UmmAlQura/ISNA...)
                                           │
                                           ▼
                                [ Aladhan API Request ]
                             (Download annual Gregorian calendar)
                                           │
                                           ▼
                             [ Local JSON Cache Store ]
                    (Android: cacheDir  |  iOS: Shared App Group)
                                           │
                                           ▼
                         [ Local Notifications & Widget ]
                   (Fully Offline-first, syncs in background)
```

---

## 2. Platform Specific Guidelines & Patterns

### Android Target (Jetpack Compose / Kotlin)
- **State Collection**: Collect flows using `.collectAsState()` inside composables. Ensure flow values are initialized properly in `AppViewModel`.
- **Broadcast Receivers**: Always specify `RECEIVER_NOT_EXPORTED` on API 33+ (Tiramisu) to conform to Android 14 security rules.
- **Compose Layout Stability**:
  - Keep search text field focus stable. Implement debouncing (`delay(300)`) inside `LaunchedEffect(searchQuery)` before firing `locationManager.searchCity(searchQuery)`.
  - Maintain consistent layout sizing: when displaying loading spinners instead of lists, use `.weight(1f)` on the container to prevent focus loss and keyboard dismissal due to layout bounds shifting.

### iOS Target (SwiftUI / Swift)
- **Project Structure**: Managed via **XcodeGen**. Do not modify `.xcodeproj` files manually. Apply changes to `/ios/project.yml` and run `xcodegen` in `/ios` to regenerate the project.
- **App Group Sharing**: Both the main app and Widget extension must access the same cache. Use:
  `UserDefaults(suiteName: "group.com.oktay.namaz")`
- **Location Geocoding**: Reverse-geocoding is handled via native `CLGeocoder`. The onboarding search queries use `LocationManager.shared.searchCity(query: query)` calling the Open-Meteo Geocoding API.

---

## 3. Important Implementation Constants

### Calculation Methods (Aladhan API IDs)
- `13` -> Türkiye (Diyanet)
- `3` -> Muslim World League (Default fallback)
- `2` -> ISNA (North America)
- `4` -> Umm Al-Qura (Makkah)
- `5` -> Egyptian General Authority of Survey
- `1` -> University of Islamic Sciences, Karachi

### Madhab (Asr School IDs)
- `1` -> Hanafi (Double shadow calculation)
- `0` -> Shafi / Maliki / Hanbali (Standard calculation)

---

## 4. Key Developer Tooling Commands

- **Android compilation**: `./gradlew assembleDebug`
- **Android installation**: `./gradlew installDebug`
- **Android crash checking**: `adb logcat -b crash -d`
- **Android layout inspection**: `adb shell screencap -p /sdcard/screencap.png && adb pull /sdcard/screencap.png`
- **iOS project generation**: `xcodegen`
- **iOS target compilation**: `xcodebuild -project NamazVakti.xcodeproj -scheme NamazVakti -sdk iphonesimulator`
- **iOS simulator installation**: `xcrun simctl install booted [path_to_app]`
- **iOS simulator launch**: `xcrun simctl launch booted com.oktay.NamazVakti`

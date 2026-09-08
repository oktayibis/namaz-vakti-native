# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Namaz Vakti** — an offline-first prayer times app built twice, natively: `/android` (Kotlin + Jetpack Compose, Material 3, minSdk 26) and `/ios` (Swift + SwiftUI, iOS 16+). The two apps share no code but deliberately mirror each other's structure and logic (`PrayerCalculator`, `AppViewModel`, `LocationManager`, `NotificationManager`, onboarding/home/settings screens, home-screen widget). **When changing core logic on one platform, apply the equivalent change to the other** unless the task is explicitly platform-specific.

A parallel `GEMINI.md` exists for another assistant; keep architectural facts consistent across both when updating docs.

## Commands

### Android (run inside `/android`)
- Build debug APK: `./gradlew assembleDebug`
- Run unit tests: `./gradlew testDebugUnitTest`
- Install on device/emulator: `./gradlew installDebug`
- Launch: `adb shell am start -n com.oktay.namaz/com.oktay.namaz.MainActivity`
- Check crashes: `adb logcat -b crash -d`
- Screenshot: `adb shell screencap -p /sdcard/screencap.png && adb pull /sdcard/screencap.png`

### iOS (run inside `/ios`)
- **Regenerate Xcode project (required after adding/removing files or changing settings)**: `xcodegen`
- Build for simulator: `xcodebuild -project NamazVakti.xcodeproj -scheme NamazVakti -sdk iphonesimulator build`
- Install on booted simulator: `xcrun simctl install booted [path_to_app]`
- Launch: `xcrun simctl launch booted com.okib.NamazVakti`

## Architecture & Engineering Standards

### Memoization & Battery Optimization
- **Astronomical Calculations Cache**: `PrayerCalculator.calculatePrayerTimes` MUST memoize calculated day tables in a thread-safe in-memory cache (limit ~12 entries, keyed by location ID, date components, method, and madhab). `getProgressInfo` runs every 1 second for countdown ticks and requires yesterday/today/tomorrow; without memoization, this performs 3 full solar calculations per second on the main thread.
- **Notification Scheduling Off Main Thread**: Calculating days of prayer times and issuing notification requests must ALWAYS run in background dispatch queues / coroutines (`DispatchQueue.global(qos: .utility)` on iOS, `Dispatchers.IO` / WorkManager on Android).

### Location & City Search
- **City text search**: Open-Meteo Geocoding API (`geocoding-api.open-meteo.com/v1/search`); GPS reverse-geocoding is native (`CLGeocoder` on iOS, `Geocoder` on Android).
- **Search Debouncing & Task Cancellation**: Always debounce search input by 300ms. On each new keystroke, cancel the pending debounce AND any active in-flight network task (`URLSessionTask.cancel()` on iOS, job cancellation on Android).
- **Language Fallback**: Open-Meteo localizes results for a fixed set of languages (`tr`, `en`, `de`, `fr`, etc.), but does NOT support Arabic. Fall back to `en` if Arabic is active to prevent API errors.
- **Error Disambiguation**: Differentiate clearly between:
  1. *Permission Denied* → Present alert / dialog prompting user to open system Settings.
  2. *Location Unavailable / Geocode Failure* → Prompt user to retry or search city manually.
  3. *Offline (No Internet)* → Explain network is unavailable.
  4. *Zero Results* → Explain no cities match the search query.

### Notifications & Alarms
- **Timezone Anchoring**: Notification/alarm triggers must be matched in the tracked city's timezone (`LocationData.timezoneIdentifier`), NOT the device's local timezone.
- **Time Sensitivity**: On iOS, notification content must set `interruptionLevel = .timeSensitive` (iOS 15+) so prayer alerts break through Focus / Do Not Disturb modes.
- **Foreground Alerting**: Implement `UNUserNotificationCenterDelegate` with `willPresent` to show alerts and play sound even when app is active in foreground.

### Accessibility (A11y) & Dynamic Type
- **Countdown Timer TalkBack / VoiceOver**: The countdown circle must be treated as a SINGLE accessibility element (`accessibilityElement(children: .ignore)`). NEVER feed 1-second ticking raw digits to accessibility readers. Provide a coarse, spoken summary updated periodically (e.g., *"1 saat 23 dakika kaldı, yüzde 45 tamamlandı"*).
- **Reduce Motion**: Animations on progress rings must be disabled when `reduceMotion` (iOS) or transition animation scale (Android) is set to reduce motion.
- **Dynamic Type**: Text sizes within fixed circular containers must use dynamic metrics (`@ScaledMetric`) with multi-line wrap and minimum scale factor rather than overflowing. Maintain WCAG >= 4.5:1 contrast against sky gradient backgrounds.

### App Store & Firebase Compliance
- **Bundle Identifiers & App Group (iOS)**:
  - Prefix: `com.okib`
  - Main App: `com.okib.NamazVakti`
  - Widget: `com.okib.NamazVakti.NamazVaktiWidget`
  - App Group: `group.com.okib.namaz`
- **Zero Tracking & No IDFA**: Do NOT link `AdSupport` or `AppTrackingTransparency`. In App Store Connect Privacy questions: Zero user tracking, zero data linked to identity.
- **Privacy Manifest**: Maintain `PrivacyInfo.xcprivacy` declaring `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`.
- **API Key Restrictions**: `GoogleService-Info.plist` is a client identifier; restrict its API key in Google Cloud Console to `com.okib.NamazVakti` under iOS Application Restrictions.

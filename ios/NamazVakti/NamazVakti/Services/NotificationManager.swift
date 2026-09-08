import Foundation
import UserNotifications

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    // Shared App Group UserDefaults for sharing configuration with the Widget
    let defaults = UserDefaults(suiteName: "group.com.okib.namaz") ?? UserDefaults.standard
    
    @Published var isPermissionGranted = false
    
    // Keys for local storage
    private let enabledPrayersKey = "enabledPrayers"
    private let reminderOffsetsKey = "reminderOffsets"
    
    private override init() {
        super.init()
        // Without a delegate iOS suppresses alerts while the app is foregrounded —
        // for a prayer-time app that silently drops the alert the user is waiting for.
        UNUserNotificationCenter.current().delegate = self
        checkPermission()
    }

    /// No-op touch point so the app can force `shared` to instantiate (and register the
    /// delegate above) during launch, before any notification can arrive.
    func activate() {}

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isPermissionGranted = granted
                completion(granted)
            }
        }
    }
    
    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isPermissionGranted = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            }
        }
    }
    
    // Get enabled prayers (default: all 5 main prayers)
    func getEnabledPrayers() -> Set<PrayerType> {
        if let data = defaults.stringArray(forKey: enabledPrayersKey) {
            return Set(data.compactMap { PrayerType(rawValue: $0) })
        }
        // Default: Fajr, Dhuhr, Asr, Maghrib, Isha (excluding Sunrise)
        return [.fajr, .dhuhr, .asr, .maghrib, .isha]
    }
    
    // Save enabled prayers
    func setEnabledPrayers(_ prayers: Set<PrayerType>) {
        let array = prayers.map { $0.rawValue }
        defaults.set(array, forKey: enabledPrayersKey)
    }
    
    // Get reminder offsets in minutes (default: [30, 0] -> 30 mins before & exactly at time)
    func getReminderOffsets() -> [Int] {
        if let data = defaults.array(forKey: reminderOffsetsKey) as? [Int] {
            return data.sorted(by: >)
        }
        return [30, 0]
    }
    
    // Save reminder offsets
    func setReminderOffsets(_ offsets: [Int]) {
        let trimmed = Array(offsets.sorted(by: >).prefix(3)) // Max 3 reminders
        defaults.set(trimmed, forKey: reminderOffsetsKey)
    }
    
    // Schedules notifications for the next N days
    func scheduleAllNotifications(for location: LocationData) {
        // Cancel existing pending notifications first to prevent duplicates
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let enabledPrayers = getEnabledPrayers()
        let offsets = getReminderOffsets()
        
        guard !enabledPrayers.isEmpty && !offsets.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()
        let languageCode = LanguageManager.resolvedLanguageCode()

        // Fire at the tracked city's wall-clock time. Without an explicit timezone the
        // trigger is matched in whatever zone the device is in when it fires, so a
        // traveling user would get alerts at the wrong moment.
        let triggerTimeZone = TimeZone(identifier: location.timezoneIdentifier)

        // iOS silently drops pending requests beyond 64 per app, so derive the window
        // from the actual configuration (e.g. 6 prayers x 3 alerts would overflow a
        // fixed 4-day window) and keep a small headroom.
        let perDay = enabledPrayers.count * offsets.count
        let daysToSchedule = max(1, min(7, 60 / perDay))
        
        for dayOffset in 0..<daysToSchedule {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            
            // Calculate prayer times for that date
            guard let prayerTimes = PrayerCalculator.shared.calculatePrayerTimes(for: location, date: date) else { continue }
            
            for prayerType in enabledPrayers {
                guard let prayerDate = prayerTimes[prayerType] else { continue }
                
                for minutesBefore in offsets {
                    guard let triggerDate = calendar.date(byAdding: .minute, value: -minutesBefore, to: prayerDate) else { continue }
                    
                    // Only schedule future notifications
                    if triggerDate > now {
                        let identifier = "\(location.id.uuidString)_\(calendar.component(.year, from: date))-\(calendar.component(.month, from: date))-\(calendar.component(.day, from: date))_\(prayerType.rawValue)_\(minutesBefore)"
                        
                        let content = UNMutableNotificationContent()
                        content.sound = .default
                        // A prayer alert is the definition of time sensitive: without
                        // this, Focus and Do Not Disturb silence it.
                        if #available(iOS 15.0, *) {
                            content.interruptionLevel = .timeSensitive
                        }

                        let prayerName = prayerType.localizedName(for: languageCode)
                        if minutesBefore == 0 {
                            content.title = tr("notif_title_now", prayerName)
                            content.body = tr("notif_body_now", prayerName)
                        } else {
                            content.title = tr("notif_title_soon", prayerName)
                            content.body = tr("notif_body_soon", prayerName, minutesBefore)
                        }
                        
                        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
                        components.timeZone = triggerTimeZone
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                        
                        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                        
                        center.add(request) { error in
                            #if DEBUG
                            if let error = error {
                                print("Error scheduling notification: \(error.localizedDescription)")
                            }
                            #endif
                        }
                    }
                }
            }
        }
        
        #if DEBUG
        print("Notifications scheduled for the next \(daysToSchedule) days.")
        #endif
    }
}

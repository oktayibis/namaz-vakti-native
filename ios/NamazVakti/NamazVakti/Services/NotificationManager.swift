import Foundation
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    // Shared App Group UserDefaults for sharing configuration with the Widget
    let defaults = UserDefaults(suiteName: "group.com.oktay.namaz") ?? UserDefaults.standard
    
    @Published var isPermissionGranted = false
    
    // Keys for local storage
    private let enabledPrayersKey = "enabledPrayers"
    private let reminderOffsetsKey = "reminderOffsets"
    
    private init() {
        checkPermission()
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
                        
                        let prayerName = prayerType.turkishName
                        if minutesBefore == 0 {
                            content.title = "\(prayerName) Vakti"
                            content.body = "\(prayerName) vakti girdi. Namazınızı kılabilirsiniz."
                        } else if minutesBefore == 30 {
                            content.title = "\(prayerName) Vaktine Az Kaldı"
                            content.body = "\(prayerName) vaktinin girmesine 30 dakika kaldı."
                        } else {
                            content.title = "\(prayerName) Hatırlatıcısı"
                            content.body = "\(prayerName) vaktine \(minutesBefore) dakika kaldı."
                        }
                        
                        // Create trigger date components relative to the target location timezone
                        // Wait, UNCalendarNotificationTrigger matches components in the device local timezone.
                        // Since triggerDate is a Swift Date (UTC), converting it to components in Calendar.current
                        // gives the correct local time of the user's device.
                        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                        
                        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                        
                        center.add(request) { error in
                            if let error = error {
                                print("Error scheduling notification: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
        
        print("Notifications scheduled for \(location.name) for the next \(daysToSchedule) days.")
    }
}

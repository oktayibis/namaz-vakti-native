import Foundation
import Adhan

struct PrayerTimeItem: Identifiable, Hashable {
    let id = UUID()
    let type: PrayerType
    let date: Date
    let formattedTime: String
}

enum PrayerType: String, CaseIterable, Codable {
    case fajr = "Fajr"
    case sunrise = "Güneş"
    case dhuhr = "Öğle"
    case asr = "İkindi"
    case maghrib = "Akşam"
    case isha = "Yatsı"
    
    var turkishName: String {
        switch self {
        case .fajr: return "İmsak"
        case .sunrise: return "Güneş"
        case .dhuhr: return "Öğle"
        case .asr: return "İkindi"
        case .maghrib: return "Akşam"
        case .isha: return "Yatsı"
        }
    }
    
    var iconName: String {
        switch self {
        case .fajr: return "sunrise.fill"
        case .sunrise: return "sun.max.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.min.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }
}

struct PrayerProgressInfo {
    let currentPrayer: PrayerType
    let nextPrayer: PrayerType
    let timeRemaining: TimeInterval // seconds
    let progress: Double // 0.0 to 1.0
    let currentPrayerDate: Date
    let nextPrayerDate: Date
}

// Aladhan API DTOs (Annual Response)
struct AladhanApiResponse: Codable {
    let code: Int
    let status: String
    let data: [String: [AladhanDayData]]? // Key is month string "1" to "12"
}

struct AladhanDayData: Codable {
    let timings: [String: String]
    let date: AladhanDateInfo
}

struct AladhanDateInfo: Codable {
    let readable: String
    let timestamp: String
    let gregorian: AladhanGregorianInfo
    let hijri: AladhanHijriInfo
}

struct AladhanGregorianInfo: Codable {
    let date: String // "04-07-2026"
    let month: AladhanMonthInfo
    let year: String
}

struct AladhanMonthInfo: Codable {
    let number: Int
    let en: String
}

struct AladhanHijriInfo: Codable {
    let date: String // "20-01-1448"
    let day: String
    let month: AladhanHijriMonthInfo
    let year: String
}

struct AladhanHijriMonthInfo: Codable {
    let number: Int
    let en: String
    let ar: String
}

class PrayerCalculator {
    static let shared = PrayerCalculator()
    
    private let defaults = UserDefaults(suiteName: "group.com.oktay.namaz") ?? UserDefaults.standard
    private let queue = DispatchQueue(label: "com.oktay.namaz.calculator", qos: .background)

    // In-memory copy of the parsed annual calendar; the raw JSON is 1-2 MB and
    // callers (widget timeline, notification scheduling, countdown) would otherwise
    // re-decode it from UserDefaults on every single call.
    private let cacheLock = NSLock()
    private var memoryCache: [String: AladhanApiResponse] = [:]

    private init() {}

    private func loadAnnualCache(forKey cacheKey: String) -> AladhanApiResponse? {
        cacheLock.lock()
        if let cached = memoryCache[cacheKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        guard let jsonString = defaults.string(forKey: cacheKey),
              let jsonData = jsonString.data(using: .utf8),
              let response = try? JSONDecoder().decode(AladhanApiResponse.self, from: jsonData),
              response.code == 200, response.data != nil else {
            return nil
        }

        cacheLock.lock()
        memoryCache[cacheKey] = response
        cacheLock.unlock()
        return response
    }

    private func invalidateMemoryCache(forKey key: String? = nil) {
        cacheLock.lock()
        if let key = key {
            memoryCache.removeValue(forKey: key)
        } else {
            memoryCache.removeAll()
        }
        cacheLock.unlock()
    }
    
    func calculateLocalPrayerTimes(for location: LocationData, date: Date) -> [PrayerType: Date]? {
        let coordinates = Coordinates(latitude: location.latitude, longitude: location.longitude)
        
        let cal = Calendar(identifier: .gregorian)
        guard let tz = TimeZone(identifier: location.timezoneIdentifier) else { return nil }
        var targetCal = cal
        targetCal.timeZone = tz
        let components = targetCal.dateComponents([.year, .month, .day], from: date)
        
        var methodId = defaults.integer(forKey: "calculation_method")
        if defaults.object(forKey: "calculation_method") == nil {
            methodId = 13 // Default to Diyanet (approximated)
        }
        
        var schoolId = defaults.integer(forKey: "asr_madhab")
        if defaults.object(forKey: "asr_madhab") == nil {
            schoolId = (methodId == 1) ? 1 : 0
        }
        
        let method: CalculationMethod
        switch methodId {
        case 13, 3: method = .muslimWorldLeague
        case 2: method = .northAmerica
        case 4: method = .ummAlQura
        case 5: method = .egyptian
        case 1: method = .karachi
        default: method = .muslimWorldLeague
        }
        
        var params = method.params
        params.madhab = (schoolId == 1) ? .hanafi : .shafi
        
        guard let prayerTimes = PrayerTimes(coordinates: coordinates, date: components, calculationParameters: params) else {
            return nil
        }
        
        return [
            .fajr: prayerTimes.fajr,
            .sunrise: prayerTimes.sunrise,
            .dhuhr: prayerTimes.dhuhr,
            .asr: prayerTimes.asr,
            .maghrib: prayerTimes.maghrib,
            .isha: prayerTimes.isha
        ]
    }
    
    func calculatePrayerTimes(for location: LocationData, date: Date) -> [PrayerType: Date]? {
        guard let tz = TimeZone(identifier: location.timezoneIdentifier) else {
            return calculateLocalPrayerTimes(for: location, date: date)
        }
        
        let cal = Calendar(identifier: .gregorian)
        var targetCal = cal
        targetCal.timeZone = tz
        
        let components = targetCal.dateComponents([.year, .month, .day], from: date)
        guard let day = components.day, let month = components.month, let year = components.year else {
            return calculateLocalPrayerTimes(for: location, date: date)
        }
        
        let cacheKey = "namaz_cache_\(location.id.uuidString)_\(year)"
        
        if let response = loadAnnualCache(forKey: cacheKey),
           let data = response.data {
            let monthKey = String(month)
            if let monthList = data[monthKey] {
                let dayStr = String(format: "%02d", day)
                let monthStr = String(format: "%02d", month)
                let dateKey = "\(dayStr)-\(monthStr)-\(year)"

                if let dayData = monthList.first(where: { $0.date.gregorian.date == dateKey }) {
                    var parsedTimes: [PrayerType: Date] = [:]

                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd-MM-yyyy HH:mm"
                    formatter.timeZone = tz
                    formatter.locale = Locale(identifier: "en_US_POSIX")

                    let keyMapping: [PrayerType: String] = [
                        .fajr: "Fajr",
                        .sunrise: "Sunrise",
                        .dhuhr: "Dhuhr",
                        .asr: "Asr",
                        .maghrib: "Maghrib",
                        .isha: "Isha"
                    ]

                    for (type, apiKey) in keyMapping {
                        if let rawTime = dayData.timings[apiKey] {
                            let cleanTime = rawTime.components(separatedBy: " ")[0]
                            let fullDateStr = "\(dateKey) \(cleanTime)"
                            if let parsedDate = formatter.date(from: fullDateStr) {
                                parsedTimes[type] = parsedDate
                            }
                        }
                    }

                    if parsedTimes.count == 6 {
                        return parsedTimes
                    }
                }
            }
        }
        
        // Trigger background fetch if not already in cache
        triggerCacheFetch(for: location, year: year)
        
        // Fallback to local offline calculation
        return calculateLocalPrayerTimes(for: location, date: date)
    }
    
    private func triggerCacheFetch(for location: LocationData, year: Int) {
        let cacheKey = "namaz_cache_\(location.id.uuidString)_\(year)"
        let fetchingKey = "fetching_\(location.id.uuidString)_\(year)"
        
        if defaults.bool(forKey: fetchingKey) { return }
        defaults.set(true, forKey: fetchingKey)
        
        queue.async {
            var methodId = self.defaults.integer(forKey: "calculation_method")
            if self.defaults.object(forKey: "calculation_method") == nil {
                methodId = 13 // Default to Diyanet (approximated)
            }
            
            var schoolId = self.defaults.integer(forKey: "asr_madhab")
            if self.defaults.object(forKey: "asr_madhab") == nil {
                schoolId = (methodId == 1) ? 1 : 0
            }
            
            let urlString = "https://api.aladhan.com/v1/calendar/\(year)?latitude=\(location.latitude)&longitude=\(location.longitude)&method=\(methodId)&school=\(schoolId)"
            guard let url = URL(string: urlString) else {
                self.defaults.removeObject(forKey: fetchingKey)
                return
            }
            
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                defer {
                    self.defaults.removeObject(forKey: fetchingKey)
                }
                
                guard let data = data, error == nil else { return }
                
                do {
                    let responseObj = try JSONDecoder().decode(AladhanApiResponse.self, from: data)
                    if responseObj.code == 200, responseObj.data != nil {
                        if let jsonString = String(data: data, encoding: .utf8) {
                            self.defaults.set(jsonString, forKey: cacheKey)
                            self.invalidateMemoryCache(forKey: cacheKey)

                            // Notify AppViewModel on Main Queue
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: Notification.Name("com.oktay.namaz.ACTION_CACHE_UPDATED"), object: nil)
                            }
                        }
                    }
                } catch {
                    print("Failed to parse network Aladhan response: \(error)")
                }
            }
            task.resume()
        }
    }
    
    func fetchYearCalendar(for location: LocationData, year: Int, completion: @escaping (Bool) -> Void) {
        let cacheKey = "namaz_cache_\(location.id.uuidString)_\(year)"
        
        var methodId = self.defaults.integer(forKey: "calculation_method")
        if self.defaults.object(forKey: "calculation_method") == nil {
            methodId = 13 // Default to Diyanet
        }
        
        var schoolId = self.defaults.integer(forKey: "asr_madhab")
        if self.defaults.object(forKey: "asr_madhab") == nil {
            schoolId = (methodId == 1) ? 1 : 0
        }
        
        let urlString = "https://api.aladhan.com/v1/calendar/\(year)?latitude=\(location.latitude)&longitude=\(location.longitude)&method=\(methodId)&school=\(schoolId)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(false)
                return
            }
            
            do {
                let responseObj = try JSONDecoder().decode(AladhanApiResponse.self, from: data)
                if responseObj.code == 200, responseObj.data != nil {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        self.defaults.set(jsonString, forKey: cacheKey)
                        self.invalidateMemoryCache(forKey: cacheKey)
                        completion(true)
                        return
                    }
                }
                completion(false)
            } catch {
                print("Failed to parse network response in onboarding: \(error)")
                completion(false)
            }
        }
        task.resume()
    }
    
    func getPrayerTimesList(for location: LocationData, date: Date) -> [PrayerTimeItem] {
        guard let times = calculatePrayerTimes(for: location, date: date),
              let tz = TimeZone(identifier: location.timezoneIdentifier) else {
            return []
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = tz
        
        return PrayerType.allCases.map { type in
            let dateVal = times[type] ?? Date()
            return PrayerTimeItem(type: type, date: dateVal, formattedTime: formatter.string(from: dateVal))
        }
    }
    
    func getProgressInfo(for location: LocationData, at referenceDate: Date = Date()) -> PrayerProgressInfo? {
        let calendar = Calendar.current
        
        let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
        
        guard let yesterdayTimes = calculatePrayerTimes(for: location, date: yesterday),
              let todayTimes = calculatePrayerTimes(for: location, date: referenceDate),
              let tomorrowTimes = calculatePrayerTimes(for: location, date: tomorrow) else {
            return nil
        }
        
        struct Milestone {
            let type: PrayerType
            let date: Date
        }
        
        var milestones: [Milestone] = []
        
        if let yIsha = yesterdayTimes[.isha] {
            milestones.append(Milestone(type: .isha, date: yIsha))
        }
        
        for type in PrayerType.allCases {
            if let dateVal = todayTimes[type] {
                milestones.append(Milestone(type: type, date: dateVal))
            }
        }
        
        if let tFajr = tomorrowTimes[.fajr] {
            milestones.append(Milestone(type: .fajr, date: tFajr))
        }
        
        milestones.sort { $0.date < $1.date }
        
        for i in 0..<(milestones.count - 1) {
            let start = milestones[i]
            let end = milestones[i+1]
            
            if referenceDate >= start.date && referenceDate < end.date {
                let totalInterval = end.date.timeIntervalSince(start.date)
                let elapsedInterval = referenceDate.timeIntervalSince(start.date)
                let timeRemaining = end.date.timeIntervalSince(referenceDate)
                
                let progress = totalInterval > 0 ? (elapsedInterval / totalInterval) : 0.0
                
                return PrayerProgressInfo(
                    currentPrayer: start.type,
                    nextPrayer: end.type,
                    timeRemaining: timeRemaining,
                    progress: progress,
                    currentPrayerDate: start.date,
                    nextPrayerDate: end.date
                )
            }
        }
        
        if let first = milestones.first, let last = milestones.last {
            return PrayerProgressInfo(
                currentPrayer: last.type,
                nextPrayer: first.type,
                timeRemaining: 0,
                progress: 1.0,
                currentPrayerDate: last.date,
                nextPrayerDate: first.date
            )
        }
        
        return nil
    }
    
    func getHijriDateString(for location: LocationData, date: Date) -> String? {
        guard let tz = TimeZone(identifier: location.timezoneIdentifier) else { return nil }
        
        let cal = Calendar(identifier: .gregorian)
        var targetCal = cal
        targetCal.timeZone = tz
        
        let components = targetCal.dateComponents([.year, .month, .day], from: date)
        guard let day = components.day, let month = components.month, let year = components.year else {
            return nil
        }
        
        let cacheKey = "namaz_cache_\(location.id.uuidString)_\(year)"
        
        guard let response = loadAnnualCache(forKey: cacheKey),
              let data = response.data else {
            return nil
        }
        
        let monthKey = String(month)
        if let monthList = data[monthKey] {
            let dayStr = String(format: "%02d", day)
            let monthStr = String(format: "%02d", month)
            let dateKey = "\(dayStr)-\(monthStr)-\(year)"
            
            if let dayData = monthList.first(where: { $0.date.gregorian.date == dateKey }) {
                let h = dayData.date.hijri
                return "\(h.day) \(h.month.en) \(h.year)"
            }
        }
        return nil
    }
    
    func clearCache() {
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix("namaz_cache_") {
                defaults.removeObject(forKey: key)
            }
        }
        invalidateMemoryCache()
    }
}

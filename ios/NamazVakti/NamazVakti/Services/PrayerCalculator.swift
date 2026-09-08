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
        return localizedName(for: "tr")
    }
    
    func localizedName(for langCode: String = "tr") -> String {
        let code = langCode.lowercased()
        if code.hasPrefix("tr") {
            switch self {
            case .fajr: return "İmsak"
            case .sunrise: return "Güneş"
            case .dhuhr: return "Öğle"
            case .asr: return "İkindi"
            case .maghrib: return "Akşam"
            case .isha: return "Yatsı"
            }
        } else if code.hasPrefix("ar") {
            switch self {
            case .fajr: return "الفجر"
            case .sunrise: return "الشروق"
            case .dhuhr: return "الظهر"
            case .asr: return "العصر"
            case .maghrib: return "المغرب"
            case .isha: return "العشاء"
            }
        } else if code.hasPrefix("de") {
            switch self {
            case .fajr: return "Fadschr"
            case .sunrise: return "Sonnenaufgang"
            case .dhuhr: return "Zuhr"
            case .asr: return "Asr"
            case .maghrib: return "Maghrib"
            case .isha: return "Ischa"
            }
        } else if code.hasPrefix("fr") {
            switch self {
            case .fajr: return "Fajr"
            case .sunrise: return "Lever du soleil"
            case .dhuhr: return "Dhuhr"
            case .asr: return "Asr"
            case .maghrib: return "Maghrib"
            case .isha: return "Icha"
            }
        } else {
            switch self {
            case .fajr: return "Fajr"
            case .sunrise: return "Sunrise"
            case .dhuhr: return "Dhuhr"
            case .asr: return "Asr"
            case .maghrib: return "Maghrib"
            case .isha: return "Isha"
            }
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

class PrayerCalculator {
    static let shared = PrayerCalculator()
    
    private let defaults = UserDefaults(suiteName: "group.com.okib.namaz") ?? UserDefaults.standard

    /// Memoized day tables. getProgressInfo() needs yesterday/today/tomorrow, and the
    /// countdown asks for it once a second — without this that is three full solar
    /// computations per second on the main thread, forever, while the app is open.
    /// The key carries the method and madhab, so changing either invalidates naturally.
    private var timesCache: [String: [PrayerType: Date]] = [:]
    private let cacheLock = NSLock()
    private static let cacheLimit = 12

    private init() {}

    private func cacheKey(for location: LocationData, components: DateComponents, methodId: Int, schoolId: Int) -> String {
        let y = components.year ?? 0, m = components.month ?? 0, d = components.day ?? 0
        return "\(location.id.uuidString)_\(y)-\(m)-\(d)_\(methodId)_\(schoolId)"
    }

    /// Drops every memoized table. Call when the inputs change in a way the key does not
    /// capture (e.g. a location's coordinates are replaced under the same id).
    func invalidateTimesCache() {
        cacheLock.lock()
        timesCache.removeAll()
        cacheLock.unlock()
    }

    private func resolvedMethodAndSchool() -> (Int, Int) {
        var methodId = defaults.integer(forKey: "calculation_method")
        if defaults.object(forKey: "calculation_method") == nil {
            methodId = 13
        }
        var schoolId = defaults.integer(forKey: "asr_madhab")
        if defaults.object(forKey: "asr_madhab") == nil {
            schoolId = (methodId == 1) ? 1 : 0
        }
        return (methodId, schoolId)
    }

    private func getCalculationParameters(latitude: Double = 39.0) -> CalculationParameters {
        var methodId = defaults.integer(forKey: "calculation_method")
        if defaults.object(forKey: "calculation_method") == nil {
            methodId = 13 // Default to Diyanet
        }
        
        var schoolId = defaults.integer(forKey: "asr_madhab")
        if defaults.object(forKey: "asr_madhab") == nil {
            schoolId = (methodId == 1) ? 1 : 0
        }
        
        var params: CalculationParameters
        switch methodId {
        case 13:
            // Türkiye Diyanet İşleri Başkanlığı:
            if latitude > 48.0 {
                // Avrupa / İskandinavya (Yüksek enlem): Diyanet 16.0° Yatsı açısı ve özel temkinler kullanır
                params = CalculationMethod.other.params
                params.fajrAngle = 18.0
                params.ishaAngle = 16.0
                params.adjustments = PrayerAdjustments(fajr: -1, sunrise: -7, dhuhr: 5, asr: 5, maghrib: 9, isha: 3)
                params.highLatitudeRule = .twilightAngle
            } else {
                params = CalculationMethod.turkey.params
                params.adjustments = PrayerAdjustments(asr: 1, maghrib: 1, isha: 2)
                params.highLatitudeRule = .twilightAngle
            }
        case 1:
            params = CalculationMethod.karachi.params
        case 2:
            params = CalculationMethod.northAmerica.params
        case 4:
            params = CalculationMethod.ummAlQura.params
        case 5:
            params = CalculationMethod.egyptian.params
        case 8, 16:
            params = CalculationMethod.dubai.params
        case 9:
            params = CalculationMethod.kuwait.params
        case 10:
            params = CalculationMethod.qatar.params
        case 11:
            params = CalculationMethod.singapore.params
        case 15:
            params = CalculationMethod.moonsightingCommittee.params
        default:
            params = CalculationMethod.muslimWorldLeague.params
        }
        
        params.madhab = (schoolId == 1) ? .hanafi : .shafi
        return params
    }
    
    /**
     Tamamen çevrimdışı, anlık (0 ms) ve yüksek hassasiyetli namaz vakti hesaplama motoru.
     Ağ bağımlılığı olmadan verilen koordinat, saat dilimi ve tarihe göre vakitleri üretir.
     */
    func calculatePrayerTimes(for location: LocationData, date: Date) -> [PrayerType: Date]? {
        guard let tz = TimeZone(identifier: location.timezoneIdentifier) else { return nil }
        var targetCal = Calendar(identifier: .gregorian)
        targetCal.timeZone = tz
        let components = targetCal.dateComponents([.year, .month, .day], from: date)

        let (methodId, schoolId) = resolvedMethodAndSchool()
        let key = cacheKey(for: location, components: components, methodId: methodId, schoolId: schoolId)

        cacheLock.lock()
        if let cached = timesCache[key] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let coordinates = Coordinates(latitude: location.latitude, longitude: location.longitude)
        let params = getCalculationParameters(latitude: location.latitude)

        guard let prayerTimes = PrayerTimes(coordinates: coordinates, date: components, calculationParameters: params) else {
            return nil
        }

        let result: [PrayerType: Date] = [
            .fajr: prayerTimes.fajr,
            .sunrise: prayerTimes.sunrise,
            .dhuhr: prayerTimes.dhuhr,
            .asr: prayerTimes.asr,
            .maghrib: prayerTimes.maghrib,
            .isha: prayerTimes.isha
        ]

        cacheLock.lock()
        // A handful of days is all that is ever live (yesterday/today/tomorrow, plus the
        // notification scheduling window); clear rather than grow without bound.
        if timesCache.count >= Self.cacheLimit { timesCache.removeAll() }
        timesCache[key] = result
        cacheLock.unlock()

        return result
    }

    func calculateLocalPrayerTimes(for location: LocationData, date: Date) -> [PrayerType: Date]? {
        return calculatePrayerTimes(for: location, date: date)
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
        
        guard milestones.count >= 2 else { return nil }
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
    
    /**
     Hicri tarih üretimi (örn: Türkçe "24 Rebiülevvel 1448", İngilizce "24 Rabi' al-Awwal 1448", Arapça "٢٤ ربيع الأول ١٤٤٨").
     */
    func getHijriDateString(for location: LocationData, date: Date = Date(), locale: Locale = Locale(identifier: "tr")) -> String? {
        guard let tz = TimeZone(identifier: location.timezoneIdentifier) else { return nil }
        
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = tz
        
        let components = cal.dateComponents([.day, .month, .year], from: date)
        guard let day = components.day, let month = components.month, let year = components.year else {
            return nil
        }
        
        let lang = locale.language.languageCode?.identifier.lowercased() ?? locale.identifier.lowercased()
        if lang.hasPrefix("ar") {
            let arabicHijriMonths = [
                "المحرم", "صفر", "ربيع الأول", "ربيع الآخر",
                "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان",
                "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
            ]
            let monthName = (month >= 1 && month <= 12) ? arabicHijriMonths[month - 1] : ""
            let numberFormatter = NumberFormatter()
            numberFormatter.locale = Locale(identifier: "ar")
            let dStr = numberFormatter.string(from: NSNumber(value: day)) ?? "\(day)"
            let yStr = numberFormatter.string(from: NSNumber(value: year)) ?? "\(year)"
            return "\(dStr) \(monthName) \(yStr)"
        } else if lang.hasPrefix("tr") {
            let turkishHijriMonths = [
                "Muharrem", "Safer", "Rebiülevvel", "Rebiülahir",
                "Cemaziyelevvel", "Cemaziyelahir", "Recep", "Şaban",
                "Ramazan", "Şevval", "Zilkade", "Zilhicce"
            ]
            let monthName = (month >= 1 && month <= 12) ? turkishHijriMonths[month - 1] : ""
            return "\(day) \(monthName) \(year)"
        } else {
            let englishHijriMonths = [
                "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
                "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
                "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"
            ]
            let monthName = (month >= 1 && month <= 12) ? englishHijriMonths[month - 1] : ""
            return "\(day) \(monthName) \(year)"
        }
    }
    
    /**
     Lokalize Miladi tarih formatı (örn: "6 Eylül 2026, Pazar" veya "September 6, 2026, Sunday").
     */
    func getGregorianDateString(for location: LocationData, date: Date = Date(), locale: Locale = Locale(identifier: "tr")) -> String? {
        guard let tz = TimeZone(identifier: location.timezoneIdentifier) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy, EEEE"
        formatter.locale = locale
        formatter.timeZone = tz
        return formatter.string(from: date)
    }
    
}

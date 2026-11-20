import XCTest
import Adhan
@testable import NamazVakti

final class PrayerCalculatorTests: XCTestCase {

    private let defaults = UserDefaults(suiteName: "group.com.okib.namaz") ?? UserDefaults.standard

    private let istanbul = LocationData(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "İstanbul",
        country: "Türkiye",
        latitude: 41.0082,
        longitude: 28.9784,
        timezoneIdentifier: "Europe/Istanbul"
    )

    private let berlin = LocationData(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        name: "Berlin",
        country: "Germany",
        latitude: 52.5200,
        longitude: 13.4050,
        timezoneIdentifier: "Europe/Berlin"
    )

    private let makkah = LocationData(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        name: "Makkah",
        country: "Saudi Arabia",
        latitude: 21.4225,
        longitude: 39.8262,
        timezoneIdentifier: "Asia/Riyadh"
    )

    private var savedMethod: Any?
    private var savedMadhab: Any?

    override func setUp() {
        super.setUp()
        savedMethod = defaults.object(forKey: "calculation_method")
        savedMadhab = defaults.object(forKey: "asr_madhab")
        defaults.set(13, forKey: "calculation_method")
        defaults.set(0, forKey: "asr_madhab")
        PrayerCalculator.shared.invalidateTimesCache()
    }

    override func tearDown() {
        if let savedMethod = savedMethod {
            defaults.set(savedMethod, forKey: "calculation_method")
        } else {
            defaults.removeObject(forKey: "calculation_method")
        }
        if let savedMadhab = savedMadhab {
            defaults.set(savedMadhab, forKey: "asr_madhab")
        } else {
            defaults.removeObject(forKey: "asr_madhab")
        }
        PrayerCalculator.shared.invalidateTimesCache()
        super.tearDown()
    }

    // MARK: - Prayer Times Calculation & Chronological Ordering

    func testCalculatePrayerTimesProducesAllSixOrderedTimesForIstanbul() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Istanbul"))
        let fixedDate = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12, minute: 0)))

        let times = try XCTUnwrap(PrayerCalculator.shared.calculatePrayerTimes(for: istanbul, date: fixedDate))
        XCTAssertEqual(times.count, 6)

        let fajr = try XCTUnwrap(times[.fajr])
        let sunrise = try XCTUnwrap(times[.sunrise])
        let dhuhr = try XCTUnwrap(times[.dhuhr])
        let asr = try XCTUnwrap(times[.asr])
        let maghrib = try XCTUnwrap(times[.maghrib])
        let isha = try XCTUnwrap(times[.isha])

        XCTAssertLessThan(fajr, sunrise)
        XCTAssertLessThan(sunrise, dhuhr)
        XCTAssertLessThan(dhuhr, asr)
        XCTAssertLessThan(asr, maghrib)
        XCTAssertLessThan(maghrib, isha)
    }

    func testHighLatitudeDiyanetCalculationProducesValidOrderedTimesForBerlin() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        // Summer solstice in Berlin (latitude 52.52 > 48.0 high-latitude threshold)
        let solstice = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12, minute: 0)))

        let list = PrayerCalculator.shared.getPrayerTimesList(for: berlin, date: solstice)
        XCTAssertEqual(list.count, 6)
        for i in 0..<(list.count - 1) {
            XCTAssertLessThan(list[i].date, list[i + 1].date)
            XCTAssertFalse(list[i].formattedTime.isEmpty)
        }
    }

    func testHanafiAsrIsLaterThanStandardAsr() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Istanbul"))
        let date = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 12, minute: 0)))

        defaults.set(0, forKey: "asr_madhab")
        PrayerCalculator.shared.invalidateTimesCache()
        let shafiTimes = try XCTUnwrap(PrayerCalculator.shared.calculatePrayerTimes(for: istanbul, date: date))
        let shafiAsr = try XCTUnwrap(shafiTimes[.asr])

        defaults.set(1, forKey: "asr_madhab")
        PrayerCalculator.shared.invalidateTimesCache()
        let hanafiTimes = try XCTUnwrap(PrayerCalculator.shared.calculatePrayerTimes(for: istanbul, date: date))
        let hanafiAsr = try XCTUnwrap(hanafiTimes[.asr])

        XCTAssertGreaterThan(hanafiAsr, shafiAsr, "Hanafi Asr must be later than Standard (Shafi) Asr")
    }

    func testInvalidTimezoneReturnsNilGracefully() {
        let invalidLocation = LocationData(
            name: "Nowhere",
            country: "Invalid",
            latitude: 0,
            longitude: 0,
            timezoneIdentifier: "Invalid/Timezone_Identifier"
        )
        XCTAssertNil(PrayerCalculator.shared.calculatePrayerTimes(for: invalidLocation, date: Date()))
        XCTAssertTrue(PrayerCalculator.shared.getPrayerTimesList(for: invalidLocation, date: Date()).isEmpty)
        XCTAssertNil(PrayerCalculator.shared.getProgressInfo(for: invalidLocation, at: Date()))
        XCTAssertNil(PrayerCalculator.shared.getHijriDateString(for: invalidLocation, date: Date()))
        XCTAssertNil(PrayerCalculator.shared.getGregorianDateString(for: invalidLocation, date: Date()))
    }

    // MARK: - Progress Info & Boundary Transitions

    func testProgressInfoMiddayAndBoundaries() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Istanbul"))
        let date = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 12, minute: 0)))

        let times = try XCTUnwrap(PrayerCalculator.shared.calculatePrayerTimes(for: istanbul, date: date))
        let dhuhr = try XCTUnwrap(times[.dhuhr])
        let asr = try XCTUnwrap(times[.asr])
        let isha = try XCTUnwrap(times[.isha])
        let fajr = try XCTUnwrap(times[.fajr])

        // Midpoint between Dhuhr and Asr
        let midpoint = dhuhr.addingTimeInterval(asr.timeIntervalSince(dhuhr) / 2.0)
        let midInfo = try XCTUnwrap(PrayerCalculator.shared.getProgressInfo(for: istanbul, at: midpoint))
        XCTAssertEqual(midInfo.currentPrayer, .dhuhr)
        XCTAssertEqual(midInfo.nextPrayer, .asr)
        XCTAssertEqual(midInfo.progress, 0.5, accuracy: 0.01)
        XCTAssertGreaterThan(midInfo.timeRemaining, 0)

        // Post-Isha (before midnight): current is Isha, next is tomorrow's Fajr
        let afterIsha = isha.addingTimeInterval(600)
        let postIshaInfo = try XCTUnwrap(PrayerCalculator.shared.getProgressInfo(for: istanbul, at: afterIsha))
        XCTAssertEqual(postIshaInfo.currentPrayer, .isha)
        XCTAssertEqual(postIshaInfo.nextPrayer, .fajr)
        XCTAssertGreaterThanOrEqual(postIshaInfo.progress, 0.0)
        XCTAssertLessThanOrEqual(postIshaInfo.progress, 1.0)

        // Pre-Fajr (after midnight): current is yesterday's Isha, next is today's Fajr
        let beforeFajr = fajr.addingTimeInterval(-600)
        let preFajrInfo = try XCTUnwrap(PrayerCalculator.shared.getProgressInfo(for: istanbul, at: beforeFajr))
        XCTAssertEqual(preFajrInfo.currentPrayer, .isha)
        XCTAssertEqual(preFajrInfo.nextPrayer, .fajr)
        XCTAssertEqual(preFajrInfo.nextPrayerDate, fajr)
    }

    // MARK: - Hijri & Gregorian Formatting

    func testHijriAndGregorianFormattingAcrossLocales() throws {
        let now = Date()
        for lang in ["tr", "en", "ar", "de", "fr"] {
            let locale = Locale(identifier: lang)
            let hijri = try XCTUnwrap(PrayerCalculator.shared.getHijriDateString(for: istanbul, date: now, locale: locale))
            let gregorian = try XCTUnwrap(PrayerCalculator.shared.getGregorianDateString(for: istanbul, date: now, locale: locale))
            XCTAssertFalse(hijri.isEmpty, "Hijri date should not be empty for \(lang)")
            XCTAssertFalse(gregorian.isEmpty, "Gregorian date should not be empty for \(lang)")
        }
    }

    // MARK: - Models & Default Parameter Detection

    func testLocationDataCoordinateEqualityAndCodable() throws {
        let loc1 = LocationData(name: "İstanbul", country: "Türkiye", latitude: 41.0082, longitude: 28.9784, timezoneIdentifier: "Europe/Istanbul")
        let loc2 = LocationData(name: "Istanbul", country: "Turkey", latitude: 41.0085, longitude: 28.9781, timezoneIdentifier: "Europe/Istanbul")
        let loc3 = LocationData(name: "Ankara", country: "Türkiye", latitude: 39.9334, longitude: 32.8597, timezoneIdentifier: "Europe/Istanbul")

        XCTAssertTrue(loc1.isSameLocation(as: loc2))
        XCTAssertFalse(loc1.isSameLocation(as: loc3))

        let encoded = try JSONEncoder().encode(loc1)
        let decoded = try JSONDecoder().decode(LocationData.self, from: encoded)
        XCTAssertEqual(decoded, loc1)
    }

    func testDefaultParameterDetectionByCountry() {
        let vm = AppViewModel.shared
        XCTAssertEqual(vm.determineDefaultParameters(for: istanbul).0, 13)
        XCTAssertEqual(vm.determineDefaultParameters(for: makkah).0, 4)
        XCTAssertEqual(vm.determineDefaultParameters(for: berlin).0, 3)

        let karachi = LocationData(name: "Karachi", country: "Pakistan", latitude: 24.8607, longitude: 67.0011, timezoneIdentifier: "Asia/Karachi")
        let karachiDefaults = vm.determineDefaultParameters(for: karachi)
        XCTAssertEqual(karachiDefaults.0, 1)
        XCTAssertEqual(karachiDefaults.1, 1)

        let nyc = LocationData(name: "New York", country: "United States", latitude: 40.7128, longitude: -74.0060, timezoneIdentifier: "America/New_York")
        XCTAssertEqual(vm.determineDefaultParameters(for: nyc).0, 2)
    }

    func testPrayerTypeLocalization() {
        XCTAssertEqual(PrayerType.fajr.localizedName(for: "tr"), "İmsak")
        XCTAssertEqual(PrayerType.fajr.localizedName(for: "en"), "Fajr")
        XCTAssertEqual(PrayerType.fajr.localizedName(for: "de"), "Fadschr")
        XCTAssertEqual(PrayerType.fajr.localizedName(for: "fr"), "Fajr")
        XCTAssertEqual(PrayerType.fajr.localizedName(for: "ar"), "الفجر")
    }
}

import Combine
import Foundation
import WidgetKit
import CoreLocation

class AppViewModel: ObservableObject {
    static let shared = AppViewModel()
    
    let defaults = UserDefaults(suiteName: "group.com.oktay.namaz") ?? UserDefaults.standard
    
    @Published var savedLocations: [LocationData] = []
    @Published var activeLocation: LocationData? = nil
    
    @Published var todayTimes: [PrayerTimeItem] = []
    @Published var progressInfo: PrayerProgressInfo? = nil
    @Published var timeRemainingString: String = "00:00:00"
    @Published var progress: Double = 0.0
    @Published var hijriDateString: String? = nil
    
    @Published var isDetectingLocation = false
    @Published var showFirstLaunchLocationRequest = false
    @Published var onboardingLoading = false
    @Published var detectedLocation: LocationData? = nil
    
    private var timer: AnyCancellable?
    private let locationsKey = "saved_locations"
    private let activeLocationIdKey = "active_location_id"
    
    private init() {
        loadData()
        startTimer()
        
        // Listen for background Aladhan API cache updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cacheUpdated),
            name: Notification.Name("com.oktay.namaz.ACTION_CACHE_UPDATED"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func cacheUpdated() {
        DispatchQueue.main.async {
            self.updateTimes()
            self.saveLocations()
        }
    }
    
    func loadData() {
        // Load saved locations
        if let data = defaults.data(forKey: locationsKey) {
            do {
                savedLocations = try JSONDecoder().decode([LocationData].self, from: data)
            } catch {
                print("Failed to decode locations: \(error)")
            }
        }
        
        // Load active location
        if let activeIdString = defaults.string(forKey: activeLocationIdKey),
           let activeId = UUID(uuidString: activeIdString) {
            activeLocation = savedLocations.first(where: { $0.id == activeId })
        }
        
        // Fallback to first if active location is not found but we have locations
        if activeLocation == nil && !savedLocations.isEmpty {
            activeLocation = savedLocations.first
            defaults.set(activeLocation?.id.uuidString, forKey: activeLocationIdKey)
        }
        
        if activeLocation == nil {
            // First launch or no locations added
            showFirstLaunchLocationRequest = true
        } else {
            updateTimes()
        }
    }
    
    func saveLocations() {
        do {
            let data = try JSONEncoder().encode(savedLocations)
            defaults.set(data, forKey: locationsKey)
            
            // Also save individual times for widget to read easily without calculating
            if let active = activeLocation {
                let timesList = PrayerCalculator.shared.getPrayerTimesList(for: active, date: Date())
                var widgetTimes: [String: String] = [:]
                widgetTimes["cityName"] = active.name
                widgetTimes["countryName"] = active.country
                
                // Add next prayer details for widget
                if let info = PrayerCalculator.shared.getProgressInfo(for: active) {
                    widgetTimes["nextPrayerName"] = info.nextPrayer.turkishName
                    let hours = Int(info.timeRemaining) / 3600
                    let minutes = (Int(info.timeRemaining) % 3600) / 60
                    widgetTimes["nextPrayerTimeRemaining"] = String(format: "%02d:%02d", hours, minutes)
                    widgetTimes["currentPrayer"] = info.currentPrayer.rawValue.lowercased()
                }
                
                for item in timesList {
                    widgetTimes[item.type.rawValue] = item.formattedTime
                }
                
                defaults.set(widgetTimes, forKey: "widget_prayer_times")
            } else {
                defaults.removeObject(forKey: "widget_prayer_times")
            }
            
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Failed to save locations: \(error)")
        }
    }
    
    func selectLocation(_ location: LocationData) {
        activeLocation = location
        defaults.set(location.id.uuidString, forKey: activeLocationIdKey)
        updateTimes()
        saveLocations()
        
        NotificationManager.shared.scheduleAllNotifications(for: location)
    }
    
    func addLocation(_ location: LocationData) {
        if let existing = savedLocations.first(where: { $0.isSameLocation(as: location) }) {
            selectLocation(existing)
            return
        }
        
        let defaultsVal = determineDefaultParameters(for: location)
        if defaults.object(forKey: "calculation_method") == nil {
            defaults.set(defaultsVal.0, forKey: "calculation_method")
        }
        if defaults.object(forKey: "asr_madhab") == nil {
            defaults.set(defaultsVal.1, forKey: "asr_madhab")
        }
        
        savedLocations.append(location)
        selectLocation(location)
    }
    
    func removeLocation(at indexSet: IndexSet) {
        let activeIdBefore = activeLocation?.id
        savedLocations.remove(atOffsets: indexSet)
        
        if savedLocations.isEmpty {
            activeLocation = nil
            defaults.removeObject(forKey: activeLocationIdKey)
            defaults.removeObject(forKey: "widget_prayer_times")
            WidgetCenter.shared.reloadAllTimelines()
        } else if activeIdBefore != nil, !savedLocations.contains(where: { $0.id == activeIdBefore }) {
            selectLocation(savedLocations.first!)
        } else {
            saveLocations()
        }
    }
    
    func detectLocationForOnboarding() {
        isDetectingLocation = true
        LocationManager.shared.getCurrentLocation { [weak self] locationData in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isDetectingLocation = false
                if let location = locationData {
                    self.detectedLocation = location
                }
            }
        }
    }
    
    func completeOnboarding(location: LocationData, methodId: Int, completion: @escaping () -> Void) {
        onboardingLoading = true
        
        defaults.set(methodId, forKey: "calculation_method")
        let schoolId = (methodId == 1) ? 1 : 0
        defaults.set(schoolId, forKey: "asr_madhab")
        
        PrayerCalculator.shared.clearCache()
        
        let currentYear = Calendar.current.component(.year, from: Date())
        
        PrayerCalculator.shared.fetchYearCalendar(for: location, year: currentYear) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.onboardingLoading = false
                self.addLocation(location)
                
                // Request notification permission on iOS. addLocation above already
                // scheduled notifications, but that ran before authorization existed;
                // re-schedule once the user grants so delivery is guaranteed.
                NotificationManager.shared.requestPermission { granted in
                    if granted, let active = self.activeLocation {
                        NotificationManager.shared.scheduleAllNotifications(for: active)
                    }
                    self.showFirstLaunchLocationRequest = false
                    completion()
                }
            }
        }
    }
    
    func detectCurrentLocation() {
        isDetectingLocation = true
        LocationManager.shared.getCurrentLocation { [weak self] locationData in
            guard let self = self else { return }
            self.isDetectingLocation = false
            
            if let location = locationData {
                DispatchQueue.main.async {
                    let defaultsVal = self.determineDefaultParameters(for: location)
                    if self.defaults.object(forKey: "calculation_method") == nil {
                        self.defaults.set(defaultsVal.0, forKey: "calculation_method")
                    }
                    if self.defaults.object(forKey: "asr_madhab") == nil {
                        self.defaults.set(defaultsVal.1, forKey: "asr_madhab")
                    }
                    self.addLocation(location)
                    self.showFirstLaunchLocationRequest = false
                }
            } else {
                print("Failed to detect location or permission denied.")
            }
        }
    }
    
    func determineDefaultParameters(for location: LocationData) -> (Int, Int) {
        let countryLower = location.country.lowercased()
        let defaultMethod: Int
        if countryLower.contains("turkey") || countryLower.contains("türkiye") {
            defaultMethod = 13 // Diyanet
        } else if countryLower.contains("saudi") || countryLower.contains("arabia") || countryLower.contains("makkah") {
            defaultMethod = 4 // Umm Al-Qura
        } else if countryLower.contains("egypt") {
            defaultMethod = 5 // Egyptian
        } else if countryLower.contains("pakistan") || countryLower.contains("india") || countryLower.contains("bangladesh") {
            defaultMethod = 1 // Karachi
        } else if countryLower.contains("united states") || countryLower.contains("canada") || countryLower.contains("america") {
            defaultMethod = 2 // ISNA
        } else {
            defaultMethod = 3 // Muslim World League
        }
        
        let defaultSchool: Int
        if countryLower.contains("pakistan") || countryLower.contains("india") || countryLower.contains("bangladesh") {
            defaultSchool = 1 // Hanafi
        } else {
            defaultSchool = 0 // Shafi/Standard
        }
        
        return (defaultMethod, defaultSchool)
    }
    
    func getCalculationMethod() -> Int {
        if defaults.object(forKey: "calculation_method") == nil {
            return 13 // Default to Diyanet
        }
        return defaults.integer(forKey: "calculation_method")
    }
    
    func setCalculationMethod(_ methodId: Int) {
        defaults.set(methodId, forKey: "calculation_method")
        let schoolId = (methodId == 1) ? 1 : 0
        defaults.set(schoolId, forKey: "asr_madhab")
        
        PrayerCalculator.shared.clearCache()
        updateTimes()
        saveLocations()
        if let active = activeLocation {
            NotificationManager.shared.scheduleAllNotifications(for: active)
        }
    }
    
    func getAsrMadhab() -> Int {
        if defaults.object(forKey: "asr_madhab") == nil {
            let method = getCalculationMethod()
            return method == 1 ? 1 : 0
        }
        return defaults.integer(forKey: "asr_madhab")
    }
    
    func setAsrMadhab(_ schoolId: Int) {
        defaults.set(schoolId, forKey: "asr_madhab")
        PrayerCalculator.shared.clearCache()
        updateTimes()
        saveLocations()
        if let active = activeLocation {
            NotificationManager.shared.scheduleAllNotifications(for: active)
        }
    }
    
    func updateTimes() {
        guard let active = activeLocation else { return }
        
        todayTimes = PrayerCalculator.shared.getPrayerTimesList(for: active, date: Date())
        progressInfo = PrayerCalculator.shared.getProgressInfo(for: active)
        hijriDateString = PrayerCalculator.shared.getHijriDateString(for: active, date: Date())
        
        updateTimerTick()
    }
    
    private func startTimer() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTimerTick()
            }
    }
    
    private func updateTimerTick() {
        guard let active = activeLocation else { return }
        
        if let info = PrayerCalculator.shared.getProgressInfo(for: active) {
            self.progressInfo = info
            self.progress = info.progress
            
            let hours = Int(info.timeRemaining) / 3600
            let minutes = (Int(info.timeRemaining) % 3600) / 60
            let seconds = Int(info.timeRemaining) % 60
            self.timeRemainingString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}

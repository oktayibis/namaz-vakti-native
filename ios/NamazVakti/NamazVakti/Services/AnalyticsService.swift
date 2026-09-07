import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

/// Centralized service for Google Analytics events and Crashlytics diagnostics
final class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Analytics Events
    
    func logScreen(name: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: name
        ])
    }
    
    func logLocationSelected(cityName: String, country: String) {
        Analytics.logEvent("location_selected", parameters: [
            "city": cityName,
            "country": country
        ])
        
        // Also tag Crashlytics session for contextual crash debugging
        Crashlytics.crashlytics().setCustomValue(cityName, forKey: "last_city")
        Crashlytics.crashlytics().setCustomValue(country, forKey: "last_country")
    }
    
    func logLanguageChanged(language: String) {
        Analytics.logEvent("language_changed", parameters: [
            "language": language
        ])
        Crashlytics.crashlytics().setCustomValue(language, forKey: "app_language")
    }
    
    func logCalculationMethodChanged(methodId: Int, methodName: String) {
        Analytics.logEvent("calculation_method_changed", parameters: [
            "method_id": methodId,
            "method_name": methodName
        ])
        Crashlytics.crashlytics().setCustomValue(methodId, forKey: "calc_method")
    }
    
    func logMadhabChanged(madhab: Int) {
        Analytics.logEvent("madhab_changed", parameters: [
            "madhab": madhab == 1 ? "Hanafi" : "Standard"
        ])
        Crashlytics.crashlytics().setCustomValue(madhab, forKey: "asr_madhab")
    }
    
    func logNotificationToggle(prayerName: String, isEnabled: Bool) {
        Analytics.logEvent("notification_toggle", parameters: [
            "prayer": prayerName,
            "enabled": isEnabled
        ])
    }
    
    // MARK: - Crashlytics Diagnostics
    
    func logMessage(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }
    
    func recordError(_ error: Error, userInfo: [String: Any]? = nil) {
        if let userInfo = userInfo {
            let nsError = error as NSError
            var combinedInfo = nsError.userInfo
            userInfo.forEach { combinedInfo[$0.key] = $0.value }
            let enrichedError = NSError(domain: nsError.domain, code: nsError.code, userInfo: combinedInfo)
            Crashlytics.crashlytics().record(error: enrichedError)
        } else {
            Crashlytics.crashlytics().record(error: error)
        }
    }
}

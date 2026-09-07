import Foundation
import SwiftUI
import WidgetKit

struct SupportedLanguage: Identifiable, Hashable {
    let code: String
    let displayName: String
    
    var id: String { code }
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    private let defaults = UserDefaults(suiteName: "group.com.okib.namaz") ?? UserDefaults.standard
    private let languageKey = "app_language"
    
    @Published var currentLanguage: String {
        didSet {
            defaults.set(currentLanguage, forKey: languageKey)
            updateBundle()
        }
    }
    
    private(set) var bundle: Bundle = Bundle.main
    
    let supportedLanguages: [SupportedLanguage] = [
        SupportedLanguage(code: "system", displayName: "System Default"),
        SupportedLanguage(code: "tr", displayName: "Türkçe"),
        SupportedLanguage(code: "en", displayName: "English"),
        SupportedLanguage(code: "de", displayName: "Deutsch"),
        SupportedLanguage(code: "ar", displayName: "العربية"),
        SupportedLanguage(code: "fr", displayName: "Français")
    ]
    
    private init() {
        let saved = defaults.string(forKey: languageKey) ?? "system"
        self.currentLanguage = saved
        self.updateBundle()
    }
    
    var effectiveLanguageCode: String {
        if currentLanguage == "system" {
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "tr"
            if preferred.hasPrefix("tr") { return "tr" }
            if preferred.hasPrefix("de") { return "de" }
            if preferred.hasPrefix("ar") { return "ar" }
            if preferred.hasPrefix("fr") { return "fr" }
            if preferred.hasPrefix("en") { return "en" }
            return "tr" // Default for diaspora app
        }
        return currentLanguage
    }
    
    var currentLocale: Locale {
        return Locale(identifier: effectiveLanguageCode)
    }
    
    var isRTL: Bool {
        return effectiveLanguageCode == "ar"
    }
    
    var layoutDirection: LayoutDirection {
        return isRTL ? .rightToLeft : .leftToRight
    }
    
    private func updateBundle() {
        let langCode = effectiveLanguageCode
        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            self.bundle = langBundle
        } else {
            self.bundle = Bundle.main
        }
    }
    
    func localizedString(forKey key: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    
    func localizedString(forKey key: String, _ args: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        if args.isEmpty {
            return format
        }
        return String(format: format, arguments: args)
    }
}

/// Shorthand helper for clean SwiftUI usage: tr("key") or tr("key", 10)
func tr(_ key: String) -> String {
    return LanguageManager.shared.localizedString(forKey: key)
}

func tr(_ key: String, _ args: CVarArg...) -> String {
    let format = LanguageManager.shared.localizedString(forKey: key)
    if args.isEmpty {
        return format
    }
    return String(format: format, arguments: args)
}

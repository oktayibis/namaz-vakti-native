import SwiftUI

extension Color {
    static let customFajrStart = Color(red: 10/255, green: 15/255, blue: 45/255)
    static let customFajrEnd = Color(red: 253/255, green: 147/255, blue: 76/255)
    
    static let customDhuhrStart = Color(red: 44/255, green: 119/255, blue: 216/255)
    static let customDhuhrEnd = Color(red: 90/255, green: 120/255, blue: 140/255)
    
    static let customAsrStart = Color(red: 34/255, green: 90/255, blue: 180/255)
    static let customAsrEnd = Color(red: 120/255, green: 140/255, blue: 160/255)
    
    static let customMaghribStart = Color(red: 220/255, green: 68/255, blue: 78/255)
    static let customMaghribEnd = Color(red: 50/255, green: 15/255, blue: 70/255)
    
    static let customIshaStart = Color(red: 5/255, green: 5/255, blue: 20/255)
    static let customIshaEnd = Color(red: 25/255, green: 40/255, blue: 80/255)
    
    static let customGlassBG = Color.white.opacity(0.08)
    static let customGlassBorder = Color.white.opacity(0.12)
}

struct SkyGradient: View {
    let prayerType: PrayerType
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: colorsForPrayer),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private var colorsForPrayer: [Color] {
        switch prayerType {
        case .fajr, .sunrise:
            return [.customFajrStart, .customFajrEnd]
        case .dhuhr:
            return [.customDhuhrStart, .customDhuhrEnd]
        case .asr:
            return [.customAsrStart, .customAsrEnd]
        case .maghrib:
            return [.customMaghribStart, .customMaghribEnd]
        case .isha:
            return [.customIshaStart, .customIshaEnd]
        }
    }
}

import WidgetKit
import SwiftUI
import Adhan

// Extension entry point — without @main the widget never appears in the gallery.
@main
struct NamazVaktiWidgetBundle: WidgetBundle {
    var body: some Widget {
        NamazVaktiWidget()
    }
}

struct Provider: TimelineProvider {
    // Shared defaults
    let defaults = UserDefaults(suiteName: "group.com.oktay.namaz") ?? UserDefaults.standard
    private let locationsKey = "saved_locations"
    private let activeLocationIdKey = "active_location_id"
    
    private func getActiveLocation() -> LocationData? {
        if let data = defaults.data(forKey: locationsKey) {
            do {
                let locations = try JSONDecoder().decode([LocationData].self, from: data)
                if let activeIdString = defaults.string(forKey: activeLocationIdKey),
                   let activeId = UUID(uuidString: activeIdString) {
                    return locations.first(where: { $0.id == activeId })
                }
                return locations.first
            } catch {
                print("Widget failed to decode locations: \(error)")
            }
        }
        return nil
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            location: LocationData(name: "İstanbul", country: "Türkiye", latitude: 41.0082, longitude: 28.9784, timezoneIdentifier: "Europe/Istanbul"),
            todayTimes: dummyTimes(),
            progressInfo: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let location = getActiveLocation()
        let todayTimes = location.map { PrayerCalculator.shared.getPrayerTimesList(for: $0, date: Date()) } ?? dummyTimes()
        let progressInfo = location.flatMap { PrayerCalculator.shared.getProgressInfo(for: $0, at: Date()) }
        
        let entry = SimpleEntry(date: Date(), location: location, todayTimes: todayTimes, progressInfo: progressInfo)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        
        guard let location = getActiveLocation() else {
            // No location selected yet
            let entry = SimpleEntry(date: currentDate, location: nil, todayTimes: [], progressInfo: nil)
            let timeline = Timeline(entries: [entry], policy: .after(currentDate.addingTimeInterval(3600))) // retry in an hour
            completion(timeline)
            return
        }
        
        // Calculate times for today
        let todayTimes = PrayerCalculator.shared.getPrayerTimesList(for: location, date: currentDate)
        let progressInfo = PrayerCalculator.shared.getProgressInfo(for: location, at: currentDate)
        
        // Add immediate entry
        entries.append(SimpleEntry(date: currentDate, location: location, todayTimes: todayTimes, progressInfo: progressInfo))
        
        // Schedule reloads at each upcoming prayer time of today
        let calendar = Calendar.current
        guard let todayTimesDict = PrayerCalculator.shared.calculatePrayerTimes(for: location, date: currentDate) else {
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
            return
        }
        
        for (_, prayerDate) in todayTimesDict {
            if prayerDate > currentDate {
                // Fetch progress info for that specific upcoming moment
                let upcomingProgress = PrayerCalculator.shared.getProgressInfo(for: location, at: prayerDate.addingTimeInterval(1))
                entries.append(SimpleEntry(
                    date: prayerDate,
                    location: location,
                    todayTimes: todayTimes,
                    progressInfo: upcomingProgress
                ))
            }
        }
        
        // Reload also at midnight
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: currentDate),
           let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 1, of: tomorrow) {
            let midnightTimes = PrayerCalculator.shared.getPrayerTimesList(for: location, date: midnight)
            let midnightProgress = PrayerCalculator.shared.getProgressInfo(for: location, at: midnight)
            entries.append(SimpleEntry(
                date: midnight,
                location: location,
                todayTimes: midnightTimes,
                progressInfo: midnightProgress
            ))
        }
        
        // Create timeline
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func dummyTimes() -> [PrayerTimeItem] {
        return [
            PrayerTimeItem(type: .fajr, date: Date(), formattedTime: "04:30"),
            PrayerTimeItem(type: .sunrise, date: Date(), formattedTime: "06:05"),
            PrayerTimeItem(type: .dhuhr, date: Date(), formattedTime: "13:12"),
            PrayerTimeItem(type: .asr, date: Date(), formattedTime: "17:01"),
            PrayerTimeItem(type: .maghrib, date: Date(), formattedTime: "20:18"),
            PrayerTimeItem(type: .isha, date: Date(), formattedTime: "21:45")
        ]
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let location: LocationData?
    let todayTimes: [PrayerTimeItem]
    let progressInfo: PrayerProgressInfo?
}

struct NamazVaktiWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if let location = entry.location, !entry.todayTimes.isEmpty {
                switch family {
                case .systemSmall:
                    SmallWidgetView(location: location, entry: entry)
                case .systemMedium:
                    MediumWidgetView(location: location, entry: entry)
                default:
                    MediumWidgetView(location: location, entry: entry)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "mappin.slash")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                    Text("Konum Seçilmedi")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Lütfen uygulamayı açın")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .widgetBackground(backgroundView)
    }

    // Background color based on active phase
    @ViewBuilder
    private var backgroundView: some View {
        if entry.location != nil && !entry.todayTimes.isEmpty {
            WidgetBackgroundGradient(currentPrayer: entry.progressInfo?.currentPrayer ?? .isha)
        } else {
            Color.black
        }
    }
}

// iOS 17 requires containerBackground for widgets; older versions use a plain background.
extension View {
    @ViewBuilder
    func widgetBackground<Background: View>(_ background: Background) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { background }
        } else {
            self.background(background)
        }
    }
}

// Widget Sky Background Gradient
struct WidgetBackgroundGradient: View {
    let currentPrayer: PrayerType
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: colorsForPrayer),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private var colorsForPrayer: [Color] {
        switch currentPrayer {
        case .fajr, .sunrise:
            return [Color(red: 10/255, green: 15/255, blue: 45/255), Color(red: 253/255, green: 147/255, blue: 76/255).opacity(0.8)]
        case .dhuhr:
            return [Color(red: 44/255, green: 119/255, blue: 216/255), Color(red: 90/255, green: 120/255, blue: 140/255).opacity(0.8)]
        case .asr:
            return [Color(red: 34/255, green: 90/255, blue: 180/255), Color(red: 120/255, green: 140/255, blue: 160/255).opacity(0.8)]
        case .maghrib:
            return [Color(red: 220/255, green: 68/255, blue: 78/255), Color(red: 50/255, green: 15/255, blue: 70/255).opacity(0.8)]
        case .isha:
            return [Color(red: 5/255, green: 5/255, blue: 20/255), Color(red: 25/255, green: 40/255, blue: 80/255).opacity(0.8)]
        }
    }
}

// Small Widget Layout
struct SmallWidgetView: View {
    let location: LocationData
    let entry: SimpleEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Text(location.name)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            if let next = entry.progressInfo?.nextPrayer {
                Text("\(next.turkishName) Vakti")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                
                if let nextTime = entry.todayTimes.first(where: { $0.type == next }) {
                    Text(nextTime.formattedTime)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            // Show upcoming times summary
            if let current = entry.progressInfo?.currentPrayer,
               let currentTime = entry.todayTimes.first(where: { $0.type == current }) {
                Text("Şu an: \(current.turkishName) (\(currentTime.formattedTime))")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// Medium Widget Layout (Premium splits layout)
struct MediumWidgetView: View {
    let location: LocationData
    let entry: SimpleEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Left Column: Next Prayer countdown/details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundColor(.amberColor)
                    Text(location.name)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                if let next = entry.progressInfo?.nextPrayer {
                    Text("Sıradaki: \(next.turkishName)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    
                    if let nextTime = entry.todayTimes.first(where: { $0.type == next }) {
                        Text(nextTime.formattedTime)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                if let current = entry.progressInfo?.currentPrayer {
                    Text("Şu an: \(current.turkishName)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.vertical, 12)
            .padding(.leading, 12)
            .frame(width: 140, alignment: .leading)
            
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 10)
            
            // Right Column: Vertical list of times
            VStack(spacing: 4) {
                // Show 5 main prayers in right column (fajr, dhuhr, asr, maghrib, isha)
                ForEach(entry.todayTimes.filter { $0.type != .sunrise }) { item in
                    let isActive = entry.progressInfo?.currentPrayer == item.type
                    
                    HStack(spacing: 8) {
                        Image(systemName: item.type.iconName)
                            .font(.system(size: 10))
                            .foregroundColor(isActive ? .amberColor : .white.opacity(0.6))
                            .frame(width: 12)
                        
                        Text(item.type.turkishName)
                            .font(.system(size: 11, design: .rounded))
                            .fontWeight(isActive ? .bold : .regular)
                            .foregroundColor(isActive ? .white : .white.opacity(0.7))
                        
                        Spacer()
                        
                        Text(item.formattedTime)
                            .font(.system(size: 11, design: .monospaced))
                            .fontWeight(isActive ? .bold : .regular)
                            .foregroundColor(isActive ? .white : .white.opacity(0.7))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isActive ? Color.white.opacity(0.12) : Color.clear)
                    .cornerRadius(4)
                }
            }
            .padding(.vertical, 6)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NamazVaktiWidget: Widget {
    let kind: String = "NamazVaktiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NamazVaktiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Namaz Vakitleri")
        .description("Günlük namaz vakitlerini ve sıradaki vakti gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled() // views manage their own padding on every OS version
    }
}

// Color asset fallback helper
extension Color {
    static let amberColor = Color(red: 254/255, green: 195/255, blue: 67/255)
}

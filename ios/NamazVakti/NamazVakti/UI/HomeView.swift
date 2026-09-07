import SwiftUI

struct HomeView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @StateObject private var viewModel = AppViewModel.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var showSettings = false
    @State private var showLocations = false
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic Sky Background Gradient
                if let progressInfo = viewModel.progressInfo {
                    SkyGradient(prayerType: progressInfo.currentPrayer)
                } else {
                    SkyGradient(prayerType: .isha) // Fallback
                }
                
                // Stars layer for night/dawn
                if isNightOrDawn {
                    StarsOverlay()
                }
                
                if viewModel.activeLocation == nil {
                    OnboardingView(viewModel: viewModel, onFinished: {
                        viewModel.updateTimes()
                    })
                } else {
                    TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                        let currentTime = Self.timeFormatter.string(from: timeline.date)
                        
                        GeometryReader { geometry in
                            let isPhoneLandscape = verticalSizeClass == .compact
                            let isTablet = geometry.size.width >= 600 || horizontalSizeClass == .regular
                            
                            if isPhoneLandscape {
                                // Dedicated Landscape / Desk Clock (StandBy) Mode
                                landscapeDeskClockView(currentTime: currentTime, insets: geometry.safeAreaInsets)
                            } else {
                                // Portrait / Tablet Layout
                                ScrollView(showsIndicators: false) {
                                    VStack(spacing: 20) {
                                        // Header Section
                                        HStack {
                                            Button(action: { showLocations = true }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "mappin.and.ellipse")
                                                    Text(viewModel.activeLocation?.name ?? tr("select_location"))
                                                        .font(.system(.headline, design: .rounded))
                                                        .fontWeight(.semibold)
                                                    Image(systemName: "chevron.down")
                                                        .font(.caption2)
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(Color.white.opacity(0.12))
                                                .cornerRadius(20)
                                            }
                                            
                                            Spacer()
                                            
                                            Button(action: { showSettings = true }) {
                                                Image(systemName: "slider.horizontal.3")
                                                    .font(.system(.title3, design: .rounded))
                                                    .foregroundColor(.white)
                                                    .padding(10)
                                                    .background(Color.white.opacity(0.12))
                                                    .clipShape(Circle())
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.top, 10)
                                        .frame(maxWidth: 1040)
                                        
                                        if isTablet {
                                            // Dual-Column Dashboard for iPad / Large Screens
                                            HStack(alignment: .top, spacing: 32) {
                                                // Left Column: Digital Clock + Hero Countdown Ring
                                                VStack(spacing: 16) {
                                                    Text(currentTime)
                                                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                                                        .foregroundColor(.white)
                                                        .padding(.top, 8)
                                                    
                                                    if let progressInfo = viewModel.progressInfo {
                                                        let prayerName = progressInfo.nextPrayer.localizedName(for: languageManager.effectiveLanguageCode)
                                                        CircularProgressView(
                                                            progress: viewModel.progress,
                                                            timeRemaining: viewModel.timeRemainingString,
                                                            nextPrayerName: tr("time_remaining_label", prayerName)
                                                        )
                                                        .padding(.vertical, 12)
                                                    }
                                                }
                                                .frame(maxWidth: .infinity)
                                                
                                                // Right Column: Prayer Times Card
                                                prayerTimesCard
                                                    .frame(maxWidth: .infinity)
                                            }
                                            .padding(.horizontal, 24)
                                            .frame(maxWidth: 1040)
                                        } else {
                                            // Single-Column Layout for iPhones in Portrait
                                            // Subtle digital clock
                                            Text(currentTime)
                                                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.9))
                                                .padding(.top, 2)
                                            
                                            if let progressInfo = viewModel.progressInfo {
                                                let prayerName = progressInfo.nextPrayer.localizedName(for: languageManager.effectiveLanguageCode)
                                                CircularProgressView(
                                                    progress: viewModel.progress,
                                                    timeRemaining: viewModel.timeRemainingString,
                                                    nextPrayerName: tr("time_remaining_label", prayerName)
                                                )
                                                .padding(.vertical, 6)
                                            }
                                            
                                            prayerTimesCard
                                                .padding(.horizontal)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom, 30)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showLocations) {
                LocationView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.updateTimes()
            AnalyticsService.shared.logScreen(name: "HomeView")
        }
    }
    
    // Dedicated Landscape / Desk Clock (StandBy) Mode
    @ViewBuilder
    private func landscapeDeskClockView(currentTime: String, insets: EdgeInsets) -> some View {
        let leadingInset = max(insets.leading, 24)
        let trailingInset = max(insets.trailing, 24)
        let topInset = max(insets.top, 10)
        let bottomInset = max(insets.bottom, 10)
        
        VStack(spacing: 0) {
            // Minimalist Top Bar (honoring safe area insets to clear Dynamic Island / Notch)
            HStack {
                Button(action: { showLocations = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.amberColor)
                        Text(viewModel.activeLocation?.name ?? tr("select_location"))
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(16)
                }
                
                Spacer()
                
                if let hijriDate = viewModel.hijriDateString {
                    Text(hijriDate)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.amberColor)
                }
                
                Spacer()
                
                Button(action: { showSettings = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)
            .padding(.top, topInset)
            
            Spacer(minLength: 6)
            
            // 3-Column Desk Dashboard (Vertically Centered with generous breathing room)
            HStack(alignment: .center, spacing: 14) {
                // Column 1: Big Digital Clock & Dates & Active Prayer Badge
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentTime)
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                    
                    if let gregorianDate = viewModel.gregorianDateString {
                        Text(gregorianDate)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    
                    if let progressInfo = viewModel.progressInfo {
                        let currentName = progressInfo.currentPrayer.localizedName(for: languageManager.effectiveLanguageCode)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.amberColor)
                                .frame(width: 8, height: 8)
                            Text(currentName)
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.amberColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.amberColor.opacity(0.18))
                        .cornerRadius(12)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Column 2: Native Sharp Circular Progress Countdown
                if let progressInfo = viewModel.progressInfo {
                    let nextName = progressInfo.nextPrayer.localizedName(for: languageManager.effectiveLanguageCode)
                    CircularProgressView(
                        progress: viewModel.progress,
                        timeRemaining: viewModel.timeRemainingString,
                        nextPrayerName: tr("time_remaining_label", nextName),
                        size: 165
                    )
                }
                
                // Column 3: 2x3 Grid of Prayer Times
                HStack(spacing: 6) {
                    let prayers = viewModel.todayTimes
                    let leftCol = prayers.prefix(3)
                    let rightCol = prayers.dropFirst(3).prefix(3)
                    
                    VStack(spacing: 6) {
                        ForEach(Array(leftCol)) { item in
                            miniPrayerPill(item: item)
                        }
                    }
                    VStack(spacing: 6) {
                        ForEach(Array(rightCol)) { item in
                            miniPrayerPill(item: item)
                        }
                    }
                }
            }
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)
            
            Spacer(minLength: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, bottomInset)
    }
    
    @ViewBuilder
    private func miniPrayerPill(item: PrayerTimeItem) -> some View {
        let isActive = viewModel.progressInfo?.currentPrayer == item.type
        let prayerName = item.type.localizedName(for: languageManager.effectiveLanguageCode)
        
        HStack(spacing: 6) {
            Image(systemName: item.type.iconName)
                .font(.system(size: 11))
                .foregroundColor(isActive ? .amberColor : .white.opacity(0.7))
                .frame(width: 14)
            
            Text(prayerName)
                .font(.system(size: 12, weight: isActive ? .bold : .regular, design: .rounded))
                .foregroundColor(isActive ? .white : .white.opacity(0.85))
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            Text(item.formattedTime)
                .font(.system(size: 12, weight: isActive ? .bold : .regular, design: .monospaced))
                .foregroundColor(isActive ? .amberColor : .white.opacity(0.85))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minWidth: 115)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isActive ? Color.white.opacity(0.18) : Color.white.opacity(0.07))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.amberColor.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // Extracted Prayer Times Card
    @ViewBuilder
    private var prayerTimesCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("today_prayers"))
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    if let gregorianDate = viewModel.gregorianDateString {
                        Text(gregorianDate)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                    }
                }
                Spacer()
                if let hijriDate = viewModel.hijriDateString {
                    Text(hijriDate)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.amberColor)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            ForEach(viewModel.todayTimes) { item in
                let isActive = viewModel.progressInfo?.currentPrayer == item.type
                let prayerName = item.type.localizedName(for: languageManager.effectiveLanguageCode)
                
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: item.type.iconName)
                            .font(.system(.title3))
                            .foregroundColor(isActive ? .amberColor : .white.opacity(0.7))
                            .frame(width: 24)
                        
                        Text(prayerName)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(isActive ? .bold : .regular)
                            .foregroundColor(isActive ? .white : .white.opacity(0.85))
                    }
                    
                    Spacer()
                    
                    Text(item.formattedTime)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(isActive ? .bold : .regular)
                        .foregroundColor(isActive ? .white : .white.opacity(0.85))
                    
                    if isActive {
                        Image(systemName: languageManager.isRTL ? "chevron.right" : "chevron.left")
                            .font(.caption2)
                            .foregroundColor(.amberColor)
                            .padding(.leading, 6)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 14)
                .background(isActive ? Color.white.opacity(0.14) : Color.clear)
            }
        }
        .background(Color.customGlassBG)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.customGlassBorder, lineWidth: 1.5)
        )
    }
    
    private var isNightOrDawn: Bool {
        guard let progressInfo = viewModel.progressInfo else { return true }
        return progressInfo.currentPrayer == .isha || progressInfo.currentPrayer == .fajr
    }
}

// Subtle Amber Accent Color helper
extension Color {
    static let amberColor = Color(red: 254/255, green: 195/255, blue: 67/255)
}

// Stars Overlay for Night Background
struct StarsOverlay: View {
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<15, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.3...0.8)))
                    .frame(width: CGFloat.random(in: 1.5...3), height: CGFloat.random(in: 1.5...3))
                    .position(
                        x: CGFloat.random(in: 10...max(20, geo.size.width - 10)),
                        y: CGFloat.random(in: 10...min(300, max(50, geo.size.height * 0.4)))
                    )
            }
        }
        .ignoresSafeArea()
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

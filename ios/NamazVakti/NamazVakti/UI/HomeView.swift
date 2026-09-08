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

    /// Spoken form of the clock. The visible one ticks seconds; announcing that to
    /// VoiceOver would re-interrupt every second.
    private static let accessibleTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    // Fixed point sizes do not respond to Dynamic Type; these scale from the same bases.
    @ScaledMetric(relativeTo: .largeTitle) private var tabletClockSize: CGFloat = 42
    @ScaledMetric(relativeTo: .title) private var phoneClockSize: CGFloat = 28
    @ScaledMetric(relativeTo: .largeTitle) private var landscapeClockSize: CGFloat = 44
    @ScaledMetric(relativeTo: .caption2) private var pillIconSize: CGFloat = 12
    @ScaledMetric(relativeTo: .caption) private var pillTextSize: CGFloat = 12
    
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
                        let spokenTime = Self.accessibleTimeFormatter.string(from: timeline.date)
                        
                        GeometryReader { geometry in
                            let isPhoneLandscape = verticalSizeClass == .compact
                            let isTablet = geometry.size.width >= 600 || horizontalSizeClass == .regular
                            
                            if isPhoneLandscape {
                                // Dedicated Landscape / Desk Clock (StandBy) Mode
                                landscapeDeskClockView(currentTime: currentTime, spokenTime: spokenTime, insets: geometry.safeAreaInsets)
                            } else {
                                // Portrait / Tablet Layout
                                ScrollView(showsIndicators: false) {
                                    VStack(spacing: 20) {
                                        // Header Section
                                        HStack {
                                            Button(action: { showLocations = true }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "mappin.and.ellipse")
                                                        .accessibilityHidden(true)
                                                    Text(viewModel.activeLocation?.name ?? tr("select_location"))
                                                        .font(.system(.headline, design: .rounded))
                                                        .fontWeight(.semibold)
                                                    Image(systemName: "chevron.down")
                                                        .font(.caption2)
                                                        .accessibilityHidden(true)
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(Color.white.opacity(0.12))
                                                .cornerRadius(20)
                                            }
                                            .accessibilityLabel(viewModel.activeLocation?.name ?? tr("select_location"))
                                            .accessibilityHint(tr("select_location"))
                                            
                                            Spacer()
                                            
                                            Button(action: { showSettings = true }) {
                                                Image(systemName: "slider.horizontal.3")
                                                    .font(.system(.title3, design: .rounded))
                                                    .foregroundColor(.white)
                                                    .frame(minWidth: 44, minHeight: 44)
                                                    .background(Color.white.opacity(0.12))
                                                    .clipShape(Circle())
                                            }
                                            .accessibilityLabel(tr("settings"))
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
                                                        .font(.system(size: tabletClockSize, weight: .bold, design: .monospaced))
                                                        .foregroundColor(.white)
                                                        .minimumScaleFactor(0.6)
                                                        .lineLimit(1)
                                                        .padding(.top, 8)
                                                        .accessibilityLabel(tr("a11y_current_time"))
                                                        .accessibilityValue(spokenTime)
                                                    
                                                    if let progressInfo = viewModel.progressInfo {
                                                        let prayerName = progressInfo.nextPrayer.localizedName(for: languageManager.effectiveLanguageCode)
                                                        CircularProgressView(
                                                            progress: viewModel.progress,
                                                            timeRemaining: viewModel.timeRemainingString,
                                                            nextPrayerName: tr("time_remaining_label", prayerName),
                                                            accessibleTimeRemaining: viewModel.accessibleTimeRemaining
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
                                                .font(.system(size: phoneClockSize, weight: .semibold, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.9))
                                                .minimumScaleFactor(0.6)
                                                .lineLimit(1)
                                                .padding(.top, 2)
                                                .accessibilityLabel(tr("a11y_current_time"))
                                                .accessibilityValue(spokenTime)
                                            
                                            if let progressInfo = viewModel.progressInfo {
                                                let prayerName = progressInfo.nextPrayer.localizedName(for: languageManager.effectiveLanguageCode)
                                                CircularProgressView(
                                                    progress: viewModel.progress,
                                                    timeRemaining: viewModel.timeRemainingString,
                                                    nextPrayerName: tr("time_remaining_label", prayerName),
                                                    accessibleTimeRemaining: viewModel.accessibleTimeRemaining
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
    private func landscapeDeskClockView(currentTime: String, spokenTime: String, insets: EdgeInsets) -> some View {
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
                            .accessibilityHidden(true)
                        Text(viewModel.activeLocation?.name ?? tr("select_location"))
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .accessibilityHidden(true)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(16)
                }
                .accessibilityLabel(viewModel.activeLocation?.name ?? tr("select_location"))
                .accessibilityHint(tr("select_location"))
                
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
                        .frame(minWidth: 44, minHeight: 44)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel(tr("settings"))
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
                        .font(.system(size: landscapeClockSize, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .accessibilityLabel(tr("a11y_current_time"))
                        .accessibilityValue(spokenTime)
                    
                    if let gregorianDate = viewModel.gregorianDateString {
                        Text(gregorianDate)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    
                    if let progressInfo = viewModel.progressInfo {
                        let currentName = progressInfo.currentPrayer.localizedName(for: languageManager.effectiveLanguageCode)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.amberColor)
                                .frame(width: 8, height: 8)
                                .accessibilityHidden(true)
                            Text(currentName)
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.amberColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.amberColor.opacity(0.28))
                        .cornerRadius(12)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(tr("a11y_current_prayer")): \(currentName)")
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
                        accessibleTimeRemaining: viewModel.accessibleTimeRemaining,
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
                .font(.system(size: pillIconSize))
                .foregroundColor(isActive ? .amberColor : .white.opacity(0.85))
                .frame(width: 14)
                .accessibilityHidden(true)

            Text(prayerName)
                .font(.system(size: pillTextSize, weight: isActive ? .bold : .regular, design: .rounded))
                .foregroundColor(isActive ? .white : .white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 4)

            Text(item.formattedTime)
                .font(.system(size: pillTextSize, weight: isActive ? .bold : .regular, design: .monospaced))
                .foregroundColor(isActive ? .amberColor : .white.opacity(0.9))
                .lineLimit(1)
                // Previously .fixedSize, which forced the prayer *name* to absorb all
                // truncation; let the time shrink a little instead.
                .minimumScaleFactor(0.8)
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
        .accessibilityElement(children: .combine)
        .accessibilityValue(isActive ? tr("a11y_current_prayer") : "")
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
                            .foregroundColor(.white.opacity(0.85))
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
                            .foregroundColor(isActive ? .amberColor : .white.opacity(0.85))
                            .frame(width: 24)
                            .accessibilityHidden(true)

                        Text(prayerName)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(isActive ? .bold : .regular)
                            .foregroundColor(isActive ? .white : .white.opacity(0.9))
                    }

                    Spacer()

                    Text(item.formattedTime)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(isActive ? .bold : .regular)
                        .foregroundColor(isActive ? .white : .white.opacity(0.9))

                    if isActive {
                        // "chevron.backward" is the direction-aware variant: it points
                        // left in LTR and mirrors automatically in RTL. Plain
                        // "chevron.left" does NOT mirror, which is why this was
                        // originally flipped by hand.
                        Image(systemName: "chevron.backward")
                            .font(.caption2)
                            .foregroundColor(.amberColor)
                            .padding(.leading, 6)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 14)
                .background(isActive ? Color.white.opacity(0.14) : Color.clear)
                .accessibilityElement(children: .combine)
                .accessibilityValue(isActive ? tr("a11y_current_prayer") : "")
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
    private struct Star {
        let xFraction: CGFloat
        let yFraction: CGFloat
        let size: CGFloat
        let opacity: Double
    }

    /// Seeded once. These used to be randomised inside `body`, which the parent
    /// re-evaluates every second, so the stars visibly jittered — motion the user could
    /// not turn off. @State keeps the first value across re-inits.
    @State private var stars: [Star] = (0..<15).map { _ in
        Star(
            xFraction: CGFloat.random(in: 0.03...0.97),
            yFraction: CGFloat.random(in: 0.03...1.0),
            size: CGFloat.random(in: 1.5...3),
            opacity: Double.random(in: 0.3...0.8)
        )
    }

    var body: some View {
        GeometryReader { geo in
            let band = min(300, max(50, geo.size.height * 0.4))
            ForEach(Array(stars.enumerated()), id: \.offset) { _, star in
                Circle()
                    .fill(Color.white.opacity(star.opacity))
                    .frame(width: star.size, height: star.size)
                    .position(
                        x: star.xFraction * max(geo.size.width, 1),
                        y: 10 + star.yFraction * max(band - 10, 1)
                    )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

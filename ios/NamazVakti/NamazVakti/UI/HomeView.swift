import SwiftUI

struct HomeView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @StateObject private var viewModel = AppViewModel.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var showSettings = false
    @State private var showLocations = false
    
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
                    GeometryReader { geometry in
                        let isTablet = geometry.size.width >= 600 || horizontalSizeClass == .regular
                        
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 24) {
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
                                        // Left Column: Hero Countdown Ring
                                        VStack {
                                            if let progressInfo = viewModel.progressInfo {
                                                let prayerName = progressInfo.nextPrayer.localizedName(for: languageManager.effectiveLanguageCode)
                                                CircularProgressView(
                                                    progress: viewModel.progress,
                                                    timeRemaining: viewModel.timeRemainingString,
                                                    nextPrayerName: tr("time_remaining_label", prayerName)
                                                )
                                                .padding(.vertical, 24)
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
                                    // Single-Column Layout for iPhones
                                    if let progressInfo = viewModel.progressInfo {
                                        let prayerName = progressInfo.nextPrayer.localizedName(for: languageManager.effectiveLanguageCode)
                                        CircularProgressView(
                                            progress: viewModel.progress,
                                            timeRemaining: viewModel.timeRemainingString,
                                            nextPrayerName: tr("time_remaining_label", prayerName)
                                        )
                                        .padding(.vertical, 10)
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
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showLocations) {
                LocationView()
            }
        }
        .onAppear {
            viewModel.updateTimes()
        }
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

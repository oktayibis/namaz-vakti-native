import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = AppViewModel.shared
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
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Header Section
                            HStack {
                                Button(action: { showLocations = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "mappin.and.ellipse")
                                        Text(viewModel.activeLocation?.name ?? "Konum Seçin")
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
                            
                            // Countdown Ring Section
                            if let progressInfo = viewModel.progressInfo {
                                CircularProgressView(
                                    progress: viewModel.progress,
                                    timeRemaining: viewModel.timeRemainingString,
                                    nextPrayerName: "\(progressInfo.nextPrayer.turkishName) vaktine kalan"
                                )
                                .padding(.vertical, 10)
                            }
                            
                            // Today's Prayer Times Card
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Bugün Vakitler")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.white.opacity(0.9))
                                    Spacer()
                                    if let hijriDate = viewModel.hijriDateString {
                                        Text(hijriDate)
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 14)
                                
                                Divider()
                                    .background(Color.white.opacity(0.15))
                                
                                ForEach(viewModel.todayTimes) { item in
                                    let isActive = viewModel.progressInfo?.currentPrayer == item.type
                                    
                                    HStack {
                                        HStack(spacing: 12) {
                                            Image(systemName: item.type.iconName)
                                                .font(.system(.title3))
                                                .foregroundColor(isActive ? .amberColor : .white.opacity(0.7))
                                                .frame(width: 24)
                                            
                                            Text(item.type.turkishName)
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
                                            Image(systemName: "chevron.left")
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
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 30)
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
        GeometryReader { _ in
            ForEach(0..<15, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.3...0.8)))
                    .frame(width: CGFloat.random(in: 1.5...3), height: CGFloat.random(in: 1.5...3))
                    .position(
                        x: CGFloat.random(in: 10...UIScreen.main.bounds.width - 10),
                        y: CGFloat.random(in: 10...300)
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

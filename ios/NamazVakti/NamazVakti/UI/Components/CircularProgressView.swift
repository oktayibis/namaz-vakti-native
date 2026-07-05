import SwiftUI

struct CircularProgressView: View {
    let progress: Double // 0.0 to 1.0
    let timeRemaining: String
    let nextPrayerName: String
    
    var body: some View {
        ZStack {
            // Background blur glassmorphic circle
            Circle()
                .fill(Color.customGlassBG)
                .overlay(
                    Circle()
                        .stroke(Color.customGlassBorder, lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            
            // Progress Track
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 10)
            
            // Progress Fill with gradient and glow
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    AngularGradient(
                        colors: [.white, .white.opacity(0.7), .white],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))
                .animation(.easeInOut(duration: 0.8), value: progress)
                .shadow(color: .white.opacity(0.3), radius: 5)
            
            // Inside text info
            VStack(spacing: 8) {
                Text(nextPrayerName)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(0.5)
                
                Text(timeRemaining)
                    .font(.system(size: 38, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2)
                    .contentTransition(.numericText()) // Smooth digital transition in iOS 17
            }
            .padding(25)
        }
        .frame(width: 250, height: 250)
    }
}

struct CircularProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.customIshaStart
            CircularProgressView(
                progress: 0.45,
                timeRemaining: "01:23:45",
                nextPrayerName: "Öğle vaktine kalan"
            )
        }
    }
}

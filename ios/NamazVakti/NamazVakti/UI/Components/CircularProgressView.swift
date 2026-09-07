import SwiftUI

struct CircularProgressView: View {
    let progress: Double // 0.0 to 1.0
    let timeRemaining: String
    let nextPrayerName: String
    var size: CGFloat = 250
    
    private var strokeWidth: CGFloat {
        max(size * 0.04, 6)
    }
    
    private var timeFontSize: CGFloat {
        size * 0.152
    }
    
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
                .stroke(Color.white.opacity(0.15), lineWidth: strokeWidth)
            
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
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))
                .animation(.easeInOut(duration: 0.8), value: progress)
                .shadow(color: .white.opacity(0.3), radius: 5)
            
            // Inside text info
            VStack(spacing: size < 200 ? 4 : 8) {
                Text(nextPrayerName)
                    .font(.system(size: size < 200 ? 11 : 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(0.5)
                    .lineLimit(1)
                
                if #available(iOS 16.0, *) {
                    Text(timeRemaining)
                        .font(.system(size: timeFontSize, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2)
                        .contentTransition(.numericText())
                } else {
                    Text(timeRemaining)
                        .font(.system(size: timeFontSize, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2)
                }
            }
            .padding(size * 0.1)
        }
        .frame(width: size, height: size)
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

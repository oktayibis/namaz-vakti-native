import SwiftUI

struct CircularProgressView: View {
    let progress: Double // 0.0 to 1.0
    let timeRemaining: String
    let nextPrayerName: String
    /// Coarse spoken form of `timeRemaining`. Kept separate because the digit string
    /// ticks every second and must never reach VoiceOver.
    var accessibleTimeRemaining: String = ""
    var size: CGFloat = 250

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The caption scales with Dynamic Type. The countdown itself stays proportional to
    // the ring: it is already large, and growing it inside a fixed-diameter circle would
    // overflow rather than help. VoiceOver users get `spokenValue` instead.
    @ScaledMetric(relativeTo: .footnote) private var captionSizeSmall: CGFloat = 11
    @ScaledMetric(relativeTo: .footnote) private var captionSizeLarge: CGFloat = 14

    private var strokeWidth: CGFloat {
        max(size * 0.04, 6)
    }

    private var timeFontSize: CGFloat {
        size * 0.152
    }

    private var captionSize: CGFloat {
        size < 200 ? captionSizeSmall : captionSizeLarge
    }

    private var spokenValue: String {
        let percent = Int((min(max(progress, 0), 1) * 100).rounded())
        let elapsed = tr("a11y_prayer_progress", percent)
        return accessibleTimeRemaining.isEmpty ? elapsed : "\(accessibleTimeRemaining), \(elapsed)"
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
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: progress)
                .shadow(color: .white.opacity(0.3), radius: 5)

            // Inside text info
            VStack(spacing: size < 200 ? 4 : 8) {
                Text(nextPrayerName)
                    .font(.system(size: captionSize, weight: .regular, design: .rounded))
                    // Raised from 0.7: white at 0.7 alpha over the lighter sky gradients
                    // falls under the 4.5:1 contrast floor.
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(0.5)
                    // Wrap rather than truncate — this sits inside a fixed circle and
                    // German/French run long at any elevated text size.
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)

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
        // One element, announced once per minute, instead of three that re-announce
        // every second.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nextPrayerName)
        .accessibilityValue(spokenValue)
    }
}

struct CircularProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.customIshaStart
            CircularProgressView(
                progress: 0.45,
                timeRemaining: "01:23:45",
                nextPrayerName: "Öğle vaktine kalan",
                accessibleTimeRemaining: "1 saat 23 dakika"
            )
        }
    }
}

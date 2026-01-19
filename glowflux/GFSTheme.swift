import SwiftUI
import Combine

enum GFSTheme {

    // MARK: - Base Colors (tropical / jelly)

    static let background = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.12, blue: 0.20),
            Color(red: 0.12, green: 0.22, blue: 0.32)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let surface = Color(red: 0.14, green: 0.28, blue: 0.36)

    static let accent = Color(red: 0.98, green: 0.42, blue: 0.55)
    static let accentSoft = Color(red: 0.98, green: 0.62, blue: 0.70)

    static let jellyGreen = Color(red: 0.42, green: 0.92, blue: 0.72)
    static let jellyBlue  = Color(red: 0.46, green: 0.78, blue: 0.98)
    static let jellyYellow = Color(red: 0.98, green: 0.86, blue: 0.42)
    static let mint = Color(red: 0.35, green: 0.95, blue: 0.78)
    static let sun = Color(red: 1.00, green: 0.78, blue: 0.32)
    static let mist = Color.white.opacity(0.18)

    // MARK: - Text

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textMuted = Color.white.opacity(0.45)

    // MARK: - Shadows / Effects

    static let glowStrong = Color.white.opacity(0.35)
    static let glowSoft = Color.white.opacity(0.18)

    // MARK: - Helpers

    static func jellyGradient(_ a: Color, _ b: Color) -> LinearGradient {
        LinearGradient(
            colors: [a, b],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func glow(_ color: Color, radius: CGFloat = 16) -> some View {
        Circle()
            .fill(color)
            .blur(radius: radius)
            .opacity(0.65)
    }
}

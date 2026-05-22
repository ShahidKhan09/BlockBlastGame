import SwiftUI

struct AppTheme {
    static let background = Color.darkBg
    static let backgroundGradient: [Color] = [
        Color.darkBg,
        Color(hex: "0D0628"),
        Color(hex: "0A0520")
    ]
    static let surface = Color.surface
    static let surfaceSoft = Color.surface.opacity(0.62)
    static let accent = Color.neonCyan
    static let accentSoft = Color.neonCyan.opacity(0.18)
    static let accentAlt = Color.neonPink
    static let success = Color.neonGreen
    static let warning = Color.gold
    static let textSecondary = Color.white.opacity(0.65)
    static let border = Color.white.opacity(0.12)
}

struct AppButtonStyle: ButtonStyle {
    var color: Color = AppTheme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.95), color.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(color: color.opacity(configuration.isPressed ? 0.18 : 0.33), radius: configuration.isPressed ? 6 : 12, x: 0, y: 6)
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    static func app(color: Color = AppTheme.accent) -> AppButtonStyle {
        AppButtonStyle(color: color)
    }
}

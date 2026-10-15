import SwiftUI
import UIKit
import IncomeKit

// MARK: - Burgundy design tokens (spec §4). Dark is primary; every token adapts to light mode.

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }

    /// A colour that switches between dark and light values.
    static func adaptive(dark: UInt32, light: UInt32, darkAlpha: Double = 1, lightAlpha: Double = 1) -> Color {
        Color(UIColor { tc in
            let (hex, a) = tc.userInterfaceStyle == .dark ? (dark, darkAlpha) : (light, lightAlpha)
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: a)
        })
    }
}

enum Theme {
    // Backgrounds
    static let bgBase = Color.adaptive(dark: 0x0D0A0B, light: 0xFAF7F7)
    static let bgGlow = Color.adaptive(dark: 0x7A1F33, light: 0x8E2A40, darkAlpha: 0.22, lightAlpha: 0.10)
    static let cardTop = Color.adaptive(dark: 0x171214, light: 0xFFFFFF)
    static let cardBottom = Color.adaptive(dark: 0x121011, light: 0xFFFFFF)
    static let elevated = Color.adaptive(dark: 0x211A1C, light: 0xF2ECED)
    static let hairline = Color.adaptive(dark: 0xFFFFFF, light: 0x3A1A22, darkAlpha: 0.07, lightAlpha: 0.08)

    // Accent
    static let accent = Color.adaptive(dark: 0x8E2A40, light: 0x7A1F33)
    static let accentPressed = Color.adaptive(dark: 0x74202F, light: 0x63182A)
    static let accentTint = Color.adaptive(dark: 0xD98A9B, light: 0x9E3550)
    static let accentSubtle = Color.adaptive(dark: 0x2A1419, light: 0xF4E3E7)
    static let onAccent = Color.adaptive(dark: 0xFFF5F7, light: 0xFFFFFF)

    // Text
    static let textPrimary = Color.adaptive(dark: 0xF5F1F2, light: 0x1C1416)
    static let textSecondary = Color.adaptive(dark: 0x9A8F92, light: 0x6E6366)
    static let textTertiary = Color.adaptive(dark: 0x5E5557, light: 0xA69A9D)

    // Badges
    static let pastBg = Color.adaptive(dark: 0x221E1F, light: 0xEEEAEB)
    static let pastText = Color.adaptive(dark: 0x8E8587, light: 0x7D7275)
    static let destructive = Color.adaptive(dark: 0xE5484D, light: 0xCC2F35)
    static let segmentPill = Color.adaptive(dark: 0xEDE6E8, light: 0xFFFFFF)
    static let segmentPillText = Color.adaptive(dark: 0x1C1416, light: 0x1C1416)

    // Metrics
    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 24
    static let gap: CGFloat = 16
    static let cardRadius: CGFloat = 28
    static let rowRadius: CGFloat = 20
}

extension StreamColor {
    var color: Color {
        switch self {
        case .burgundy: Color(hex: 0xA8324E)
        case .rose: Color(hex: 0xD98A9B)
        case .plum: Color(hex: 0x7D4E8C)
        case .mauve: Color(hex: 0xB48EAD)
        case .copper: Color(hex: 0xC27A52)
        case .sand: Color(hex: 0xD8B98A)
        case .teal: Color(hex: 0x4F8A8B)
        case .steel: Color(hex: 0x6E83A8)
        }
    }
}

// MARK: Typography
extension Font {
    static let heroAmount = Font.system(size: 44, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(size: 20, weight: .semibold)
    static let badge = Font.system(size: 11, weight: .bold)
}

/// Screen background: near-black with a faint burgundy glow at the top.
struct ManiBackground: View {
    var body: some View {
        ZStack {
            Theme.bgBase
            RadialGradient(colors: [Theme.bgGlow, .clear], center: .top, startRadius: 0, endRadius: 420)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
    }
}

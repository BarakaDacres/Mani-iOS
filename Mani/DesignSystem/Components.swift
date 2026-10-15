import SwiftUI
import IncomeKit

/// Flat content card (no glass).
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.cardPadding
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Theme.cardTop, Theme.cardBottom], startPoint: .top, endPoint: .bottom),
                in: .rect(cornerRadius: Theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).strokeBorder(Theme.hairline))
    }
}

/// Amount text that rolls digits when the value changes.
struct RollingAmount: View {
    let cents: Int
    var font: Font = .heroAmount
    var color: Color = Theme.textPrimary
    var body: some View {
        Text(Money.format(cents))
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(cents)))
            .animation(Motion.spring, value: cents)
            .lineLimit(1).minimumScaleFactor(0.6)
    }
}

struct StreamIconTile: View {
    let icon: StreamIcon
    let color: StreamColor
    var size: CGFloat = 44
    var body: some View {
        Image(systemName: icon.systemImage)
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundStyle(color.color)
            .frame(width: size, height: size)
            .background(color.color.opacity(0.16), in: .circle)
    }
}

struct StatusBadge: View {
    let status: EntryStatus
    var body: some View {
        let (bg, fg): (Color, Color) = switch status {
        case .today: (Theme.accent, Theme.onAccent)
        case .upcoming: (Theme.accentSubtle, Theme.accentTint)
        case .past: (Theme.pastBg, Theme.pastText)
        }
        Text(status.rawValue.uppercased())
            .font(.badge).tracking(1)
            .foregroundStyle(fg)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(bg, in: .capsule)
    }
}

/// "● All Income ▾" stream filter menu.
struct StreamFilterMenu: View {
    let streams: [IncomeStream]
    @Binding var selection: IncomeStream?
    var body: some View {
        Menu {
            Button("All Income") { selection = nil }
            ForEach(streams) { s in
                Button { selection = s } label: { Label(s.name, systemImage: s.iconKey.systemImage) }
            }
        } label: {
            HStack(spacing: 8) {
                Circle().fill(selection?.colorKey.color ?? Theme.accentTint).frame(width: 9, height: 9)
                Text(selection?.name ?? "All Income").font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(Theme.elevated, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.hairline))
        }
    }
}

/// Rounded input field styling used throughout the Add Income sheet.
struct FieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20).frame(minHeight: 56)
            .background(Theme.elevated, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.hairline))
    }
}
extension View { func fieldStyle() -> some View { modifier(FieldBackground()) } }

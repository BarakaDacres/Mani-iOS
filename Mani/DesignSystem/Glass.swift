import SwiftUI

// Liquid Glass is reserved for key controls (tab bar, + button, Add/Save buttons, segmented
// controls, sheet toolbar). Cards stay flat surfaces so content reads calmly.

/// Full-width burgundy-tinted glass capsule (Add Income / Save income).
struct PrimaryGlassButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.headline) }
                Text(title).font(.headline)
            }
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 58)
            .contentShape(.capsule)
        }
        .buttonStyle(PressScaleStyle())
        .glassEffect(.regular.tint(Theme.accent.opacity(enabled ? 0.85 : 0.35)).interactive(), in: .capsule)
        .shadow(color: Theme.accent.opacity(0.28), radius: 20, y: 6)
        .disabled(!enabled)
    }
}

/// The floating centre + button in the tab bar.
struct PlusGlassButton: View {
    let action: () -> Void
    @State private var taps = 0
    var body: some View {
        Button { taps += 1; action() } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.onAccent)
                .symbolEffect(.bounce, value: taps)
                .frame(width: 58, height: 58)
                .contentShape(.circle)
        }
        .buttonStyle(PressScaleStyle())
        .glassEffect(.regular.tint(Theme.accent.opacity(0.9)).interactive(), in: .circle)
        .shadow(color: Theme.accent.opacity(0.35), radius: 16, y: 4)
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .accessibilityLabel("Add income")
    }
}

/// Segmented control whose selected pill slides between options.
struct GlassSegmented<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    withAnimation(Motion.snappy) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Theme.segmentPillText : Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if selected {
                                Capsule().fill(Theme.segmentPill)
                                    .matchedGeometryEffect(id: "pill", in: ns)
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

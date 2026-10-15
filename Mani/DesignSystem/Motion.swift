import SwiftUI

enum Motion {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let snappy = Animation.snappy(duration: 0.28)
    static let reveal = Animation.easeOut(duration: 0.9)
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

/// Fades + lifts content in once when it first appears (staggered by `index`).
struct AppearLift: ViewModifier {
    var index = 0
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear { withAnimation(Motion.spring.delay(Double(index) * 0.05)) { shown = true } }
    }
}

extension View {
    func appearLift(_ index: Int = 0) -> some View { modifier(AppearLift(index: index)) }
}

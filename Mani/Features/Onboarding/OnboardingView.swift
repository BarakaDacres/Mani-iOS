import SwiftUI
import IncomeKit

/// Three quick steps: welcome → year type → week start. Streams are seeded and editable later.
struct OnboardingView: View {
    @AppStorage(Pref.hasOnboarded) private var hasOnboarded = false
    @AppStorage(Pref.yearType) private var yearTypeRaw = YearType.australianFY.rawValue
    @AppStorage(Pref.firstWeekday) private var firstWeekday = 2
    @State private var step = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Group {
                switch step {
                case 0:
                    page(icon: "dollarsign.circle", title: "Welcome to Mani",
                         text: "Track every dollar you earn, from support work to side hustles, in one calm place.")
                case 1:
                    page(icon: "calendar", title: "How do you report?",
                         text: "Pick the year your totals follow. You can change this later in Settings.") {
                        GlassSegmented(options: YearType.allCases,
                                       selection: Binding(get: { YearType(rawValue: yearTypeRaw) ?? .australianFY },
                                                          set: { yearTypeRaw = $0.rawValue })) {
                            $0 == .calendar ? "Calendar year" : "Australian FY"
                        }
                    }
                default:
                    page(icon: "calendar.day.timeline.left", title: "Your week starts on…",
                         text: "Used for the calendar and weekly charts.") {
                        GlassSegmented(options: [2, 1, 7], selection: $firstWeekday) {
                            Calendar.current.weekdaySymbols[$0 - 1]
                        }
                    }
                }
            }
            .id(step)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    Capsule().fill(i == step ? Theme.accentTint : Theme.textTertiary)
                        .frame(width: i == step ? 22 : 8, height: 8)
                }
            }
            .animation(Motion.spring, value: step)
            PrimaryGlassButton(title: step < 2 ? "Continue" : "Get started") {
                if step < 2 { withAnimation(Motion.spring) { step += 1 } } else { hasOnboarded = true }
            }
        }
        .padding(Theme.screenPadding)
        .background(ManiBackground())
    }

    private func page<Extra: View>(icon: String, title: String, text: String,
                                   @ViewBuilder extra: () -> Extra = { EmptyView() }) -> some View {
        VStack(spacing: 18) {
            Image(systemName: icon).font(.system(size: 56, weight: .light)).foregroundStyle(Theme.accentTint)
                .symbolEffect(.bounce, value: step)
            Text(title).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text(text).font(.body).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            extra().padding(.top, 8)
        }
    }
}

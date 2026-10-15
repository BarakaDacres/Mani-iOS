import SwiftUI
import SwiftData

@main
struct ManiApp: App {
    let container = StoreFactory.makeContainer()
    @AppStorage(Pref.appearance) private var appearance = Appearance.dark.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(Appearance(rawValue: appearance)?.scheme)
                .tint(Theme.accentTint)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @AppStorage(Pref.hasOnboarded) private var hasOnboarded = false

    var body: some View {
        Group {
            if hasOnboarded { MainTabView() } else { OnboardingView() }
        }
        .animation(Motion.spring, value: hasOnboarded)
        .task { DataService(context: context).seedIfNeeded() }
        .onChange(of: phase) { _, p in
            if p == .background { DataService(context: context).refreshWidget() }
        }
    }
}

import SwiftUI

enum AppTab: String, CaseIterable {
    case home, stats, history, settings
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .home: "house"
        case .stats: "chart.pie"
        case .history: "clock"
        case .settings: "slider.horizontal.3"
        }
    }
}

/// Tabs with a floating Liquid Glass bar and a centre + button (matches the prototype).
/// A custom bar is used because the system TabView can't host a raised centre action.
struct MainTabView: View {
    @State private var tab: AppTab = .home
    @State private var showAdd = false
    @Namespace private var zoom

    var body: some View {
        ZStack {
            switch tab {
            case .home: NavigationStack { HomeView(onAdd: { showAdd = true }) }
            case .stats: NavigationStack { StatsView() }
            case .history: NavigationStack { HistoryView() }
            case .settings: NavigationStack { SettingsView() }
            }
        }
        .safeAreaInset(edge: .bottom) { tabBar }
        .sheet(isPresented: $showAdd) {
            AddIncomeSheet()
                .navigationTransition(.zoom(sourceID: "add", in: zoom))
        }
    }

    private var tabBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 0) {
                item(.home); item(.stats)
                PlusGlassButton { showAdd = true }
                    .matchedTransitionSource(id: "add", in: zoom)
                    .frame(maxWidth: .infinity)
                item(.history); item(.settings)
            }
            .padding(.horizontal, 8).padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.bottom, 4)
    }

    private func item(_ t: AppTab) -> some View {
        let selected = t == tab
        return Button {
            withAnimation(Motion.snappy) { tab = t }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: t.icon).font(.system(size: 19, weight: .medium))
                    .symbolVariant(selected ? .fill : .none)
                    .symbolEffect(.bounce, value: selected)
                Text(t.title).font(.caption2.weight(selected ? .semibold : .regular))
            }
            .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: tab)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

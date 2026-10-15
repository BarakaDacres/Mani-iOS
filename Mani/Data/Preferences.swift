import SwiftUI
import IncomeKit

/// UserDefaults keys (shared with @AppStorage).
enum Pref {
    static let yearType = "yearType"            // YearType raw
    static let firstWeekday = "firstWeekday"    // 1…7, default 2 (Monday)
    static let taxRate = "taxRatePercent"       // Double, default 0 (off)
    static let hourlyRate = "hourlyRateCents"   // Int, default for hours × rate helper
    static let iCloudSync = "iCloudSync"        // Bool, applied on next launch
    static let appearance = "appearance"        // system | dark | light, default dark
    static let hasOnboarded = "hasOnboarded"
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, dark, light
    var id: String { rawValue }
    var scheme: ColorScheme? { switch self { case .system: nil; case .dark: .dark; case .light: .light } }
    var title: String { rawValue.capitalized }
}

extension ReportingCalendar {
    /// Reporting calendar from the user's current preferences.
    static var current: ReportingCalendar {
        let d = UserDefaults.standard
        let yt = YearType(rawValue: d.string(forKey: Pref.yearType) ?? "") ?? .australianFY
        let fw = d.object(forKey: Pref.firstWeekday) as? Int ?? 2
        return ReportingCalendar(yearType: yt, firstWeekday: fw)
    }
}

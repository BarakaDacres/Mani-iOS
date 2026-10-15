# Mani: income tracker for iOS

A native SwiftUI app for iOS 26, with Liquid Glass and a burgundy theme. It's rebuilt from the Lovable prototype screenshots (no Lovable code existed). Data is stored on the device with SwiftData. iCloud sync through CloudKit is optional, and there's no backend.

**Tabs:** Home · Stats · **+** · History · Settings

- **Home:** month/year totals (they roll when they change), today's income, and a swipeable calendar with daily totals. Tap a day to see or add its entries.
- **Add Income:** big amount, stream chips, date, optional start and end times (overnight is fine), an hours × rate helper, client (prefilled from the stream's default), note, and optional weekly/fortnightly/monthly repeats.
- **Stats:** reporting-year total, the selected month/year, an income-sources donut, a Daily/Weekly/Monthly/Yearly trend chart with a stream filter and scrubbing, and an optional tax set-aside estimate.
- **History:** grouped by day with UPCOMING/TODAY/PAST badges, a stream filter, search, tap to edit, swipe or trash to delete with Undo, and CSV export.
- **Settings:** Income Streams (rename, colour, icon, default client, reorder, archive/restore), calendar year vs Australian FY, week start day, tax rate, default hourly rate, iCloud sync, CSV export, delete all, and appearance (Dark by default, or Light/System).
- **Widget:** small and medium sizes showing this month, today, the FY total and upcoming entries.

Totals **include upcoming entries**. Deleting a stream **archives** it, so its history is kept.

## Setup on your Mac

1. Install Xcode 26 (App Store) and Homebrew, then XcodeGen:
   ```sh
   brew install xcodegen
   ```
2. In this folder:
   ```sh
   cp Config/Local.xcconfig.example Config/Local.xcconfig   # add your Apple Team ID
   xcodegen generate
   open Mani.xcodeproj
   ```
3. In Xcode, open **Signing & Capabilities** for the **Mani** and **ManiWidget** targets, choose your team, and let Xcode register:
   - App Group `group.com.barakadacres.mani` (both targets)
   - iCloud → CloudKit container `iCloud.com.barakadacres.mani` (Mani only)
   - Push Notifications / Background Modes → Remote notifications (Mani only, needed by CloudKit)

   If you change the bundle IDs, update `APP_GROUP` and `ICLOUD_CONTAINER` in `Config/Base.xcconfig`.
   Without a paid developer account, remove the iCloud and Push capabilities. The app then runs local-only, and the iCloud toggle has no effect.
4. Pick an iPhone simulator or your phone and press **Run** (⌘R). Run the tests with ⌘U.

The logic package can also be tested on its own: `cd IncomeKit && swift test`.

### iCloud sync
Turn it on under Settings → Data → iCloud sync, then restart the app. Before you ship to TestFlight, deploy the CloudKit schema to Production in the CloudKit Console.

## Project layout

```
project.yml          XcodeGen spec (iOS 26, Swift 6, default MainActor isolation)
Config/              xcconfig (App Group / iCloud IDs, your Team ID in Local.xcconfig)
IncomeKit/           Pure Swift package: money, reporting years, aggregation, recurrence, tax, CSV (+ tests)
Mani/App             App entry, root, glass tab bar
Mani/DesignSystem    Burgundy tokens (dark + light), glass controls, motion, components
Mani/Data            SwiftData models, preferences, store + DataService
Mani/Features        Home, AddIncome, History, Stats, Settings, Onboarding
ManiWidget/          WidgetKit extension (reads a JSON snapshot from the App Group)
Shared/              Widget snapshot shared by app and widget
ManiTests/           SwiftData service tests
```

## Known gaps / next steps
- The app hasn't been compiled in Xcode yet (it was written without a Mac). Expect a few small fixes on the first build. IncomeKit's 13 tests pass.
- The app icon is a placeholder (a burgundy "M"). Replace `Mani/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024).
- Repeats are created up front as concrete entries (2–52 of them) rather than as an open-ended rule.
- No CSV import yet, no reminders/notifications yet, and no iPad layout (iPhone only).

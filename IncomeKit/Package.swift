// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IncomeKit",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [
        .library(name: "IncomeKit", targets: ["IncomeKit"]),
    ],
    targets: [
        // Pure Foundation: value types, reporting periods, aggregation, recurrence, tax, CSV.
        // No SwiftUI/SwiftData so it builds and tests on Linux as well as macOS.
        .target(name: "IncomeKit"),
        .testTarget(name: "IncomeKitTests", dependencies: ["IncomeKit"]),
    ]
)

// swift-tools-version: 6.2

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "swift-observation",
    // Apple's `Observation`, which this package re-exports outside Embedded Swift,
    // starts at these releases.
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "SwiftObservation", targets: ["SwiftObservation"]),
    ],
    traits: [
        .trait(
            name: "EmbeddedObservation",
            description: "Use this package's own implementation instead of Apple's Observation on every platform, as Embedded Swift always does. For testing it on a host."
        ),
    ],
    dependencies: [
        // The range JavaScriptKit's macros accept too, so the two resolve together.
        .package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"604.0.0"),
    ],
    targets: [
        .macro(
            name: "SwiftObservationMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "SwiftObservation",
            dependencies: ["SwiftObservationMacros"],
            swiftSettings: [
                .define("SWIFT_OBSERVATION_EMBEDDED", .when(traits: ["EmbeddedObservation"])),
            ]
        ),
        .testTarget(
            name: "SwiftObservationTests",
            dependencies: ["SwiftObservation"],
            swiftSettings: [
                .define("SWIFT_OBSERVATION_EMBEDDED", .when(traits: ["EmbeddedObservation"])),
            ]
        ),
        .testTarget(
            name: "SwiftObservationMacrosTests",
            dependencies: [
                "SwiftObservationMacros",
                .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

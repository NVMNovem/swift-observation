//
//  ObservableMacroTests.swift
//  swift-observation
//
//  Created by Damian Van de Kauter on 11/11/2026.
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import SwiftSyntaxMacroExpansion
import Testing
@testable import SwiftObservationMacros

private let macros: [String: MacroSpec] = [
    "Observable": MacroSpec(type: ObservableMacro.self, conformances: ["Observable"]),
    "ObservationTracked": MacroSpec(type: ObservationTrackedMacro.self),
    "ObservationIgnored": MacroSpec(type: ObservationIgnoredMacro.self),
]

@Suite struct ObservableMacroTests {
    @Test func expandsAStoredPropertyIntoTrackedAccessors() {
        let count = PropertyIdentity.literal(of: "count")

        assertMacroExpansion(
            """
            @Observable
            final class Basket {
                var count: Int = 0
            }
            """,
            expandedSource: """
            final class Basket {
                var count: Int {
                    @storageRestrictions(initializes: _count)
                    init(initialValue) {
                        _count = initialValue
                    }
                    get {
                        access(SwiftObservation.ObservationProperty(\(count)))
                        return _count
                    }
                    set {
                        withMutation(of: SwiftObservation.ObservationProperty(\(count))) {
                            _count = newValue
                        }
                    }
                }

                private var _count: Int = 0

                private let _$observationRegistrar = SwiftObservation.ObservationRegistrar()

                internal nonisolated func access(_ property: SwiftObservation.ObservationProperty) {
                    _$observationRegistrar.access(property)
                }

                internal nonisolated func withMutation<_MutationResult>(
                    of property: SwiftObservation.ObservationProperty,
                    _ mutation: () -> _MutationResult
                ) -> _MutationResult {
                    _$observationRegistrar.withMutation(of: property, mutation)
                }
            }

            extension Basket: SwiftObservation.Observable {
            }
            """,
            macroSpecs: macros,
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test func leavesWhatCannotBeTrackedAlone() {
        assertMacroExpansion(
            """
            @Observable
            final class Shop {
                let name = "frietheus"
                var label: String { name }
                static var shared = 0
                lazy var cache = 0
                @ObservationIgnored var scratch = 0
                var observed = 0 {
                    didSet {}
                }
            }
            """,
            expandedSource: """
            final class Shop {
                let name = "frietheus"
                var label: String { name }
                static var shared = 0
                lazy var cache = 0
                var scratch = 0
                var observed = 0 {
                    didSet {}
                }

                private let _$observationRegistrar = SwiftObservation.ObservationRegistrar()

                internal nonisolated func access(_ property: SwiftObservation.ObservationProperty) {
                    _$observationRegistrar.access(property)
                }

                internal nonisolated func withMutation<_MutationResult>(
                    of property: SwiftObservation.ObservationProperty,
                    _ mutation: () -> _MutationResult
                ) -> _MutationResult {
                    _$observationRegistrar.withMutation(of: property, mutation)
                }
            }

            extension Shop: SwiftObservation.Observable {
            }
            """,
            macroSpecs: macros,
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test func aStructIsRefused() {
        assertMacroExpansion(
            """
            @Observable
            struct Basket {
                var count = 0
            }
            """,
            expandedSource: """
            struct Basket {
                var count = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@Observable' can only be applied to a class", line: 1, column: 1),
            ],
            macroSpecs: macros,
            failureHandler: { Issue.record("\($0.message)") }
        )
    }

    @Test func identitiesAreStableAndDistinct() {
        #expect(PropertyIdentity.of("count") == PropertyIdentity.of("count"))
        #expect(PropertyIdentity.of("count") != PropertyIdentity.of("note"))
        #expect(PropertyIdentity.literal(of: "count").count == 18)
        // FNV-1a's offset basis: the identity of an empty name.
        #expect(PropertyIdentity.of("") == 0xcbf2_9ce4_8422_2325)
    }
}

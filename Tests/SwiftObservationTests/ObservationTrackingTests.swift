//
//  ObservationTrackingTests.swift
//  swift-observation
//
//  Created by Damian Van de Kauter on 11/11/2026.
//

import Testing
import SwiftObservation

/// Behaviour both implementations share.
///
/// Run as is, these test Apple's `Observation` through the re-export. Run with
/// `--traits EmbeddedObservation`, they test this package's own implementation, the
/// one Embedded Swift builds. Passing both ways is what makes the two interchangeable.
@Observable
private final class Basket {
    var count = 0
    var note: String = ""
    let shop = "frietheus"
    @ObservationIgnored var scratch = 0
    var total: Int { count * 2 }
}

/// Counts calls from a `@Sendable` change handler.
private final class Counter: @unchecked Sendable {
    var value = 0
}

/// Lets the change handler read the model, which the test knows is safe: every
/// write happens on the test's own thread.
private struct UncheckedBasket: @unchecked Sendable {
    let basket: Basket
    init(_ basket: Basket) { self.basket = basket }
}

@Suite struct ObservationTrackingTests {
    @Test func aChangeToSomethingReadIsReported() {
        let basket = Basket()
        let changes = Counter()

        let read = withObservationTracking {
            basket.count
        } onChange: {
            changes.value += 1
        }

        #expect(read == 0)
        basket.count = 1
        #expect(changes.value == 1)
        #expect(basket.count == 1)
    }

    @Test func theChangeIsReportedBeforeTheValueIsStored() {
        let basket = Basket()
        let seen = Counter()
        let reader = UncheckedBasket(basket)

        _ = withObservationTracking { basket.count } onChange: {
            seen.value = reader.basket.count
        }
        basket.count = 5

        #expect(seen.value == 0)
    }

    @Test func onlyTheFirstChangeIsReported() {
        let basket = Basket()
        let changes = Counter()

        _ = withObservationTracking {
            (basket.count, basket.note)
        } onChange: {
            changes.value += 1
        }
        basket.count = 1
        basket.note = "no onions"
        basket.count = 2

        #expect(changes.value == 1)
    }

    @Test func aChangeToSomethingNotReadIsNotReported() {
        let basket = Basket()
        let changes = Counter()

        _ = withObservationTracking { basket.count } onChange: {
            changes.value += 1
        }
        basket.note = "extra sauce"

        #expect(changes.value == 0)
    }

    @Test func anIgnoredPropertyIsNotTracked() {
        let basket = Basket()
        let changes = Counter()

        _ = withObservationTracking { basket.scratch } onChange: {
            changes.value += 1
        }
        basket.scratch = 9

        #expect(changes.value == 0)
        #expect(basket.scratch == 9)
    }

    @Test func aComputedPropertyIsTrackedThroughWhatItReads() {
        let basket = Basket()
        let changes = Counter()

        _ = withObservationTracking { basket.total } onChange: {
            changes.value += 1
        }
        basket.count = 3

        #expect(changes.value == 1)
        #expect(basket.total == 6)
    }

    @Test func eachObjectIsTrackedOnItsOwn() {
        let first = Basket()
        let second = Basket()
        let changes = Counter()

        _ = withObservationTracking { first.count } onChange: {
            changes.value += 1
        }
        second.count = 1
        #expect(changes.value == 0)

        first.count = 1
        #expect(changes.value == 1)
    }

    @Test func anInnerTrackingAlsoReportsToTheOuterOne() {
        let basket = Basket()
        let outer = Counter()
        let inner = Counter()

        _ = withObservationTracking {
            withObservationTracking { basket.count } onChange: {
                inner.value += 1
            }
        } onChange: {
            outer.value += 1
        }
        basket.count = 1

        #expect(inner.value == 1)
        #expect(outer.value == 1)
    }

    @Test func readingOutsideATrackingRecordsNothing() {
        let basket = Basket()
        let changes = Counter()

        _ = basket.count
        _ = withObservationTracking { basket.note } onChange: {
            changes.value += 1
        }
        basket.count = 1

        #expect(changes.value == 0)
    }

    @Test func initialValuesAndConstantsAreKept() {
        let basket = Basket()

        #expect(basket.count == 0)
        #expect(basket.note == "")
        #expect(basket.shop == "frietheus")
    }

    #if SWIFT_OBSERVATION_EMBEDDED
    /// Proves the trait run tests this package's implementation and not Apple's,
    /// which has no such type.
    @Test func theOwnImplementationIsTheOneInUse() {
        #expect(ObservationProperty(7).rawValue == 7)
    }
    #endif

    @Test func aModelIsReleasedEvenWhileATrackingWaitsOnIt() {
        weak var released: Basket?
        let changes = Counter()
        do {
            let basket = Basket()
            released = basket
            _ = withObservationTracking { basket.count } onChange: {
                changes.value += 1
            }
        }
        #expect(released == nil)
        #expect(changes.value == 0)
    }
}

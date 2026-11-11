//
//  SwiftObservation.swift
//  swift-observation
//
//  Created by Damian Van de Kauter on 11/11/2026.
//

// Apple's `Observation` wherever it can be built, and this module's own
// implementation of the same API where it cannot: in Embedded Swift.
//
// Model code imports this module instead of `Observation` and is otherwise
// unchanged: `@Observable`, `@ObservationIgnored` and `withObservationTracking`
// mean the same in both. The `EmbeddedObservation` package trait selects this
// module's implementation on any platform, which is how it is tested on a host.
#if !hasFeature(Embedded) && !SWIFT_OBSERVATION_EMBEDDED
@_exported import Observation
#endif

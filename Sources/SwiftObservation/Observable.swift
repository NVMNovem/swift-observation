//
//  Observable.swift
//  swift-observation
//
//  Created by Damian Van de Kauter on 11/11/2026.
//

#if hasFeature(Embedded) || SWIFT_OBSERVATION_EMBEDDED

/// A type whose properties report reads and writes to observation tracking.
///
/// Conformance comes from the ``Observable()`` macro; there is nothing to implement.
///
/// This is the Embedded Swift counterpart of `Observation.Observable`. It is only
/// compiled where Apple's module is not used: see the module overview.
public protocol Observable: AnyObject {}

/// Makes a class observable, as `Observation`'s `@Observable` does.
///
/// ```swift
/// @Observable
/// final class Basket {
///     var lines: [Line] = []
///     var note = ""
/// }
/// ```
///
/// Every stored `var` reports its reads to ``withObservationTracking(_:onChange:)``
/// and its writes to whoever tracked them. Mark a property ``ObservationIgnored()``
/// to leave it out. Constants, computed properties, `lazy` and `static` properties,
/// and properties with their own accessors are left as they are.
///
/// Unlike Apple's macro, this one identifies properties by a number derived from
/// their name rather than by key path, because Embedded Swift has no key paths. The
/// difference is not visible in source.
@attached(member, names: named(_$observationRegistrar), named(access), named(withMutation))
@attached(memberAttribute)
@attached(extension, conformances: Observable)
public macro Observable() = #externalMacro(module: "SwiftObservationMacros", type: "ObservableMacro")

/// Turns a stored property into one that reports its reads and writes.
///
/// Added by ``Observable()`` to each property it tracks. Not written by hand.
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(_))
public macro ObservationTracked() = #externalMacro(module: "SwiftObservationMacros", type: "ObservationTrackedMacro")

/// Leaves a property of an ``Observable()`` class untracked.
///
/// Reads of it are not recorded and writes to it notify nobody.
@attached(accessor, names: named(willSet))
public macro ObservationIgnored() = #externalMacro(module: "SwiftObservationMacros", type: "ObservationIgnoredMacro")

#endif

//
//  ObservationRegistrar.swift
//  swift-observation
//
//  Created by Damian Van de Kauter on 11/11/2026.
//

#if hasFeature(Embedded) || SWIFT_OBSERVATION_EMBEDDED

/// Names one tracked property of one observable class.
///
/// ``Observable()`` derives it from the property's name at compile time, which is
/// what stands in for a key path.
public struct ObservationProperty: Hashable, Sendable {
    public let rawValue: UInt64

    public init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

/// Records reads and announces writes for one observable object.
///
/// ``Observable()`` gives every observable class one and routes its tracked
/// properties through it. Code that writes a property's accessors by hand can use it
/// the same way.
public struct ObservationRegistrar: Sendable {
    private let storage = ObservationStorage()

    public init() {}

    /// Records that `property` was read, for the innermost tracking in progress.
    public func access(_ property: ObservationProperty) {
        ObservationTracking.current?.record(storage, property)
    }

    /// Announces that `property` is about to change.
    ///
    /// Every tracking that read it is told now, before the new value is stored, as
    /// `Observation` does, and then forgets everything it was watching.
    public func willSet(_ property: ObservationProperty) {
        storage.willSet(property)
    }

    /// Announces that `property` has changed. Nothing listens for it yet.
    public func didSet(_ property: ObservationProperty) {}

    /// Runs `mutation` between ``willSet(_:)`` and ``didSet(_:)`` for `property`.
    public func withMutation<Result>(of property: ObservationProperty, _ mutation: () -> Result) -> Result {
        willSet(property)
        defer { didSet(property) }
        return mutation()
    }
}

/// The observers watching one object, by property.
///
/// The storage holds its observers; an observer refers back to the storages it
/// watches without holding them, and a storage that goes away first tells its
/// observers so. A model therefore never outlives its last owner because something
/// once read it.
final class ObservationStorage: @unchecked Sendable {
    private struct Entry {
        let observer: ObservationObserver
        var properties: [ObservationProperty]
    }

    private var entries: [Entry] = []

    deinit {
        for entry in entries {
            entry.observer.forget(self)
        }
    }

    func add(_ observer: ObservationObserver, for properties: [ObservationProperty]) {
        if let index = entries.firstIndex(where: { $0.observer === observer }) {
            for property in properties where !entries[index].properties.contains(property) {
                entries[index].properties.append(property)
            }
        } else {
            entries.append(Entry(observer: observer, properties: properties))
            observer.watch(self)
        }
    }

    func remove(_ observer: ObservationObserver) {
        entries.removeAll { $0.observer === observer }
    }

    func willSet(_ property: ObservationProperty) {
        // Collected first: firing an observer removes it from this list.
        var firing: [ObservationObserver] = []
        for entry in entries where entry.properties.contains(property) {
            firing.append(entry.observer)
        }
        for observer in firing {
            observer.fire()
        }
    }

    var observerCount: Int { entries.count }
}

/// One call to ``withObservationTracking(_:onChange:)`` waiting for a change.
final class ObservationObserver {
    private let onChange: @Sendable () -> Void
    private var storages: [Unmanaged<ObservationStorage>] = []
    private var hasFired = false

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
    }

    func watch(_ storage: ObservationStorage) {
        storages.append(Unmanaged.passUnretained(storage))
    }

    func forget(_ storage: ObservationStorage) {
        let gone = Unmanaged.passUnretained(storage).toOpaque()
        storages.removeAll { $0.toOpaque() == gone }
    }

    /// Reports the change once, and stops watching everything else first, so a
    /// second write in the same turn reports nothing.
    func fire() {
        guard !hasFired else { return }
        hasFired = true
        let watched = storages
        storages = []
        for storage in watched {
            storage.takeUnretainedValue().remove(self)
        }
        onChange()
    }
}

#endif

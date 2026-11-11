//
//  ObservationTracking.swift
//  swift-observation
//
//  Created by Damian Van de Kauter on 11/11/2026.
//

#if hasFeature(Embedded) || SWIFT_OBSERVATION_EMBEDDED

#if !hasFeature(Embedded) && !os(WASI)
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
#endif

/// Runs `apply`, and calls `onChange` once when anything it read from an
/// observable object is about to change.
///
/// This is `Observation.withObservationTracking`. As there, `onChange` runs from the
/// property's `willSet`, before the new value is stored, and only once: track again
/// to hear about the next change.
///
/// A tracking inside another one also reports what it read to the outer one.
public func withObservationTracking<Result>(
    _ apply: () -> Result,
    onChange: @escaping @Sendable () -> Void
) -> Result {
    let outer = ObservationTracking.current
    let accesses = ObservationAccessList()
    ObservationTracking.current = accesses
    let result = apply()
    ObservationTracking.current = outer

    outer?.merge(accesses)
    accesses.install(ObservationObserver(onChange: onChange))
    return result
}

/// What one tracking read, by object.
final class ObservationAccessList {
    private struct Entry {
        let storage: ObservationStorage
        var properties: [ObservationProperty]
    }

    private var entries: [Entry] = []

    func record(_ storage: ObservationStorage, _ property: ObservationProperty) {
        if let index = entries.firstIndex(where: { $0.storage === storage }) {
            if !entries[index].properties.contains(property) {
                entries[index].properties.append(property)
            }
        } else {
            entries.append(Entry(storage: storage, properties: [property]))
        }
    }

    func merge(_ other: ObservationAccessList) {
        for entry in other.entries {
            for property in entry.properties {
                record(entry.storage, property)
            }
        }
    }

    func install(_ observer: ObservationObserver) {
        for entry in entries {
            entry.storage.add(observer, for: entry.properties)
        }
    }
}

/// The tracking in progress on the current thread.
///
/// A browser has one thread, so Embedded Swift and WASI keep it in a plain global.
/// Elsewhere it is thread-local, as `Observation`'s is, because tests run in
/// parallel.
enum ObservationTracking {
    #if hasFeature(Embedded) || os(WASI) || !(canImport(Darwin) || canImport(Glibc) || canImport(Musl))
    nonisolated(unsafe) static var current: ObservationAccessList?
    #else
    private static let key: pthread_key_t = {
        var key = pthread_key_t()
        pthread_key_create(&key, nil)
        return key
    }()

    static var current: ObservationAccessList? {
        get {
            pthread_getspecific(key).map { Unmanaged<ObservationAccessList>.fromOpaque($0).takeUnretainedValue() }
        }
        set {
            // The list is kept alive by the tracking that installed it, which
            // restores the previous value before returning.
            pthread_setspecific(key, newValue.map { Unmanaged.passUnretained($0).toOpaque() })
        }
    }
    #endif
}

#endif

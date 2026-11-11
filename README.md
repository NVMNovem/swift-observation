# swift-observation

[![CI](https://github.com/NVMNovem/swift-observation/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/NVMNovem/swift-observation/actions/workflows/ci.yml)
[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-Apple%20%7C%20Linux%20%7C%20WebAssembly-blue)](#)
[![Embedded Swift](https://img.shields.io/badge/Embedded%20Swift-compatible-8A2BE2)](https://www.swift.org/documentation/embedded/)

`@Observable` and `withObservationTracking` that also build in **Embedded Swift**.

Everywhere Apple's `Observation` module exists, this package simply re-exports it.
In Embedded Swift, where `Observation` is not available, it supplies its own
implementation of the same API. Model code imports `SwiftObservation` instead of
`Observation` and is otherwise unchanged:

```swift
import SwiftObservation

@Observable
final class Basket {
    var lines: [Line] = []
    var note = ""
    @ObservationIgnored var draft = ""
}

let total = withObservationTracking {
    basket.lines.count
} onChange: {
    // Called once, before the next change to `lines` is stored.
}
```

The same model can therefore be shared between a SwiftUI app, which gets Apple's
`Observation`, and a WebAssembly build in Embedded Swift, which gets this one.

## Installation

```swift
.package(url: "https://github.com/NVMNovem/swift-observation.git", from: "0.1.0"),
```

```swift
.product(name: "SwiftObservation", package: "swift-observation"),
```

## What the Embedded implementation supports

| | |
| --- | --- |
| `@Observable` on a class | Yes |
| Stored `var` properties tracked | Yes, including `private` and generic types |
| `@ObservationIgnored` | Yes |
| Computed properties | Tracked through the stored properties they read |
| `withObservationTracking(_:onChange:)` | Yes. `onChange` runs once, from `willSet`, before the value is stored, as in `Observation` |
| Nested tracking | Yes. An inner tracking also reports to the outer one |
| `Observations` async sequence | No |
| `@Observable` on a struct or actor | No, as in `Observation` |
| Properties with their own `willSet`/`didSet`, `lazy`, `static` | Left untracked |

### How it differs inside

Apple's macro identifies a property by key path. Embedded Swift has no key paths, so
this macro gives each tracked property a 64-bit identity derived from its name at
compile time (FNV-1a). The macro refuses a class in which two names would share one.
None of this is visible in source.

Tracking state lives in a plain global in Embedded Swift and on WASI, where there is
one thread, and in thread-local storage elsewhere. The registrar is not internally
locked: as in a browser, writes to a model and the reactions to them are expected on
one thread.

## Testing the Embedded implementation on a host

The `EmbeddedObservation` package trait selects this package's implementation on
every platform. The same tests run against both:

```sh
swift test                                # Apple's Observation, re-exported
swift test --traits EmbeddedObservation   # this package's implementation
```

## Requirements

Swift 6.2 or later. On Apple platforms, the releases that ship `Observation`: macOS 14,
iOS 17, tvOS 17, watchOS 10, visionOS 1.

//
//  SwiftObservationMacros.swift
//  swift-observation
//
//  Created by Damian Van de Kauter on 11/11/2026.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftObservationMacros: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ObservableMacro.self,
        ObservationTrackedMacro.self,
        ObservationIgnoredMacro.self,
    ]
}

//
//  ObservableMacro.swift
//  swift-observation
//
//  Created by Damian Van de Kauter on 11/11/2026.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// `@Observable`: a registrar, the two methods tracked properties call, the
/// `Observable` conformance, and `@ObservationTracked` on each stored property.
public struct ObservableMacro {
    static let moduleName = "SwiftObservation"
    static let registrarName = "_$observationRegistrar"
    static let trackedName = "ObservationTracked"
    static let ignoredName = "ObservationIgnored"
}

extension ObservableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(ClassDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: ObservationDiagnostic.classesOnly))
            return []
        }

        // Two names with the same identity would report each other's changes.
        var seen: [UInt64: String] = [:]
        for property in declaration.memberBlock.members.compactMap({ $0.decl.as(VariableDeclSyntax.self) })
        where property.isTrackable {
            guard let name = property.identifierName else { continue }
            let identity = PropertyIdentity.of(name)
            if let other = seen[identity] {
                context.diagnose(Diagnostic(
                    node: property,
                    message: ObservationDiagnostic.identityCollision(name, other)
                ))
            }
            seen[identity] = name
        }

        return [
            """
            @\(raw: ignoredName) private let \(raw: registrarName) = \(raw: moduleName).ObservationRegistrar()
            """,
            """
            internal nonisolated func access(_ property: \(raw: moduleName).ObservationProperty) {
                \(raw: registrarName).access(property)
            }
            """,
            """
            internal nonisolated func withMutation<_MutationResult>(
                of property: \(raw: moduleName).ObservationProperty,
                _ mutation: () -> _MutationResult
            ) -> _MutationResult {
                \(raw: registrarName).withMutation(of: property, mutation)
            }
            """,
        ]
    }
}

extension ObservableMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard declaration.is(ClassDeclSyntax.self),
              let property = member.as(VariableDeclSyntax.self),
              property.isTrackable,
              !property.hasAttribute(named: trackedName)
        else {
            return []
        }
        return [AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier(trackedName)))]
    }
}

extension ObservableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(ClassDeclSyntax.self), !protocols.isEmpty else { return [] }
        let decl: DeclSyntax = "extension \(type.trimmed): \(raw: moduleName).Observable {}"
        return [decl.cast(ExtensionDeclSyntax.self)]
    }
}

/// `@ObservationTracked`: routes a stored property through the registrar and moves
/// its value into an underscored peer.
public struct ObservationTrackedMacro {}

extension ObservationTrackedMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self),
              property.isTrackable,
              let name = property.identifierName
        else {
            return []
        }
        let identity = PropertyIdentity.literal(of: name)
        let identifier = "\(ObservableMacro.moduleName).ObservationProperty(\(identity))"
        return [
            """
            @storageRestrictions(initializes: _\(raw: name))
            init(initialValue) {
                _\(raw: name) = initialValue
            }
            """,
            """
            get {
                access(\(raw: identifier))
                return _\(raw: name)
            }
            """,
            """
            set {
                withMutation(of: \(raw: identifier)) {
                    _\(raw: name) = newValue
                }
            }
            """,
        ]
    }
}

extension ObservationTrackedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self),
              property.isTrackable,
              let binding = property.bindings.first,
              let name = property.identifierName
        else {
            return []
        }
        var storage = "@\(ObservableMacro.ignoredName) private var _\(name)"
        if let type = binding.typeAnnotation {
            storage += type.trimmedDescription.hasPrefix(":") ? type.trimmedDescription : ": \(type.trimmedDescription)"
        }
        if let initializer = binding.initializer {
            storage += " \(initializer.trimmedDescription)"
        }
        return [DeclSyntax(stringLiteral: storage)]
    }
}

/// `@ObservationIgnored`: a marker. The property stays an ordinary stored property.
public struct ObservationIgnoredMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        []
    }
}

/// The number that stands in for a key path: FNV-1a over the property's name.
///
/// It only has to tell one class's tracked properties apart, and ``ObservableMacro``
/// reports the practically impossible case where two of them share one.
enum PropertyIdentity {
    static func of(_ name: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in name.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        return hash
    }

    static func literal(of name: String) -> String {
        let hex = String(of(name), radix: 16)
        return "0x" + String(repeating: "0", count: 16 - hex.count) + hex
    }
}

enum ObservationDiagnostic: DiagnosticMessage {
    case classesOnly
    case identityCollision(String, String)

    var message: String {
        switch self {
        case .classesOnly:
            "'@Observable' can only be applied to a class"
        case .identityCollision(let name, let other):
            "'\(name)' and '\(other)' cannot both be observed in one class; rename one of them"
        }
    }

    var diagnosticID: MessageID {
        switch self {
        case .classesOnly: MessageID(domain: "SwiftObservation", id: "classesOnly")
        case .identityCollision: MessageID(domain: "SwiftObservation", id: "identityCollision")
        }
    }

    var severity: DiagnosticSeverity { .error }
}

extension VariableDeclSyntax {
    /// A single, stored, mutable, instance property without accessors of its own,
    /// not marked to be left alone.
    var isTrackable: Bool {
        guard bindingSpecifier.tokenKind == .keyword(.var),
              bindings.count == 1,
              let binding = bindings.first,
              binding.pattern.is(IdentifierPatternSyntax.self),
              binding.accessorBlock == nil
        else {
            return false
        }
        let excluded: Set<String> = ["static", "class", "lazy", "override"]
        if modifiers.contains(where: { excluded.contains($0.name.text) }) { return false }
        return !hasAttribute(named: ObservableMacro.ignoredName)
    }

    var identifierName: String? {
        bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmedDescription
    }

    func hasAttribute(named name: String) -> Bool {
        attributes.contains { element in
            guard let attribute = element.as(AttributeSyntax.self) else { return false }
            let written = attribute.attributeName.trimmedDescription
            return written == name || written.hasSuffix(".\(name)")
        }
    }
}

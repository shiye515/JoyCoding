import Foundation

struct KeyboardModifiers: OptionSet, Hashable, Sendable, Codable {
    let rawValue: UInt8
    static let command = Self(rawValue: 1 << 0)
    static let option = Self(rawValue: 1 << 1)
    static let control = Self(rawValue: 1 << 2)
    static let shift = Self(rawValue: 1 << 3)
}

struct KeyboardBinding: Hashable, Sendable, Codable {
    let keyCode: UInt16
    var modifiers: KeyboardModifiers = []
}

enum MappingHoldBehavior: String, Codable, CaseIterable, Sendable {
    case hold
    case repeatPress

    var displayName: String { self == .hold ? "持续按住" : "重复按下" }
}

struct KeyboardButtonMapping: Equatable, Sendable, Codable {
    var binding: KeyboardBinding
    var holdBehavior: MappingHoldBehavior
}

struct MappingSource: Hashable, Sendable {
    let deviceSessionID: UUID
    let buttonID: String
}

enum ControllerProfileID {
    private struct Descriptor: Codable { let name: String; let category: String; let buttonIDs: [String] }
    static func make(name: String, category: String, buttonIDs: [String]) -> String {
        let locale = Locale(identifier: "en_US_POSIX")
        let descriptor = Descriptor(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: locale),
            category: category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: locale),
            buttonIDs: buttonIDs.sorted { $0.unicodeScalars.lexicographicallyPrecedes($1.unicodeScalars) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(descriptor)) ?? Data()
        return "v1:" + data.base64EncodedString()
    }
}

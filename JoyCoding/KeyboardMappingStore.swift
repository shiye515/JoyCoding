import Combine
import Foundation

@MainActor
protocol KeyboardMappingStoring: AnyObject {
    func mapping(profileID: String, buttonID: String) -> KeyboardButtonMapping?
    func save(_ mapping: KeyboardButtonMapping, profileID: String, buttonID: String)
    func remove(profileID: String, buttonID: String)
}

@MainActor
final class UserDefaultsKeyboardMappingStore: ObservableObject, KeyboardMappingStoring {
    static let defaultsKey = "keyboardButtonMappings.v1"
    private struct Envelope: Codable { var schemaVersion = 1; var profiles: [String: [String: KeyboardButtonMapping]] = [:] }
    @Published private(set) var revision = 0
    private var envelope: Envelope
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(Envelope.self, from: data), decoded.schemaVersion == 1 {
            envelope = decoded
        } else { envelope = Envelope() }
    }
    func mapping(profileID: String, buttonID: String) -> KeyboardButtonMapping? { envelope.profiles[profileID]?[buttonID] }
    func save(_ mapping: KeyboardButtonMapping, profileID: String, buttonID: String) {
        envelope.profiles[profileID, default: [:]][buttonID] = mapping; persist()
    }
    func remove(profileID: String, buttonID: String) {
        envelope.profiles[profileID]?[buttonID] = nil
        if envelope.profiles[profileID]?.isEmpty == true { envelope.profiles[profileID] = nil }
        persist()
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(envelope) { defaults.set(data, forKey: Self.defaultsKey) }
        revision &+= 1
    }
}

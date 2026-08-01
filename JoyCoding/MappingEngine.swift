import ApplicationServices
import Foundation

protocol MappingSleeping: Sendable { func sleep(for duration: Duration) async throws }
struct ContinuousMappingSleeper: MappingSleeping { func sleep(for duration: Duration) async throws { try await ContinuousClock().sleep(for: duration) } }

@MainActor
final class MappingEngine {
    private struct Active { let profileID: String; let mapping: KeyboardButtonMapping; let releaseEvents: [KeyboardEvent]; var repeatTask: Task<Void, Never>? }
    private let store: KeyboardMappingStoring
    private let sender: KeyboardEventSending
    private let sleeper: MappingSleeping
    private let accessibilityAllowed: () -> Bool
    private var active: [MappingSource: Active] = [:]
    private var keyReferences: [UInt16: Int] = [:]

    init(store: KeyboardMappingStoring, sender: KeyboardEventSending? = nil, sleeper: MappingSleeping? = nil, accessibilityAllowed: @escaping () -> Bool = { AXIsProcessTrusted() }) {
        self.store = store; self.sender = sender ?? CoreGraphicsKeyboardEventSender(); self.sleeper = sleeper ?? ContinuousMappingSleeper(); self.accessibilityAllowed = accessibilityAllowed
    }

    func pressed(source: MappingSource, profileID: String) {
        guard active[source] == nil, accessibilityAllowed(), let mapping = store.mapping(profileID: profileID, buttonID: source.buttonID) else { return }
        let downEvents = KeyboardEventSequence.downEvents(for: mapping.binding)
        let upEvents = KeyboardEventSequence.upEvents(for: mapping.binding)
        switch mapping.holdBehavior {
        case .hold:
            guard acquire(downEvents, rollbackEvents: upEvents) else { return }
            active[source] = Active(profileID: profileID, mapping: mapping, releaseEvents: upEvents, repeatTask: nil)
        case .repeatPress:
            active[source] = Active(profileID: profileID, mapping: mapping, releaseEvents: [], repeatTask: nil)
            cycle(mapping.binding)
            let sleeper = self.sleeper
            let task = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await sleeper.sleep(for: .milliseconds(200)) } catch { return }
                    guard !Task.isCancelled else { return }
                    await MainActor.run { self?.repeatCycle(source) }
                }
            }
            active[source]?.repeatTask = task
        }
    }
    func released(source: MappingSource) { release(source: source) }
    func release(source: MappingSource) {
        guard let item = active.removeValue(forKey: source) else { return }
        item.repeatTask?.cancel()
        release(item.releaseEvents)
    }
    func releaseAll(deviceSessionID: UUID) { active.keys.filter { $0.deviceSessionID == deviceSessionID }.forEach { release(source: $0) } }
    func releaseAll(profileID: String, buttonID: String) { active.filter { $0.value.profileID == profileID && $0.key.buttonID == buttonID }.map(\.key).forEach { release(source: $0) } }
    func releaseAll() { active.keys.forEach { release(source: $0) } }

    private func repeatCycle(_ source: MappingSource) {
        guard let item = active[source], item.mapping.holdBehavior == .repeatPress else { return }
        cycle(item.mapping.binding)
    }
    private func cycle(_ binding: KeyboardBinding) {
        let downEvents = KeyboardEventSequence.downEvents(for: binding)
        let upEvents = KeyboardEventSequence.upEvents(for: binding)
        guard acquire(downEvents, rollbackEvents: upEvents) else { return }
        release(upEvents)
    }
    private func acquire(_ events: [KeyboardEvent], rollbackEvents: [KeyboardEvent]) -> Bool {
        var acquired: [UInt16] = []
        for event in events {
            let count = keyReferences[event.keyCode, default: 0]
            if count == 0 && !sender.post(event) {
                release(rollbackEvents.filter { acquired.contains($0.keyCode) })
                return false
            }
            keyReferences[event.keyCode] = count + 1
            acquired.append(event.keyCode)
        }
        return true
    }
    private func release(_ events: [KeyboardEvent]) {
        for event in events {
            let count = keyReferences[event.keyCode, default: 0]
            guard count > 0 else { continue }
            if count == 1 {
                keyReferences[event.keyCode] = nil
                _ = sender.post(event)
            } else {
                keyReferences[event.keyCode] = count - 1
            }
        }
    }
}

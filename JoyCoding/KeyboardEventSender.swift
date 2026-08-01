import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics

struct KeyboardEvent: Equatable {
    let keyCode: UInt16
    let isDown: Bool
    let flags: CGEventFlags
}

protocol KeyboardEventSending: AnyObject {
    @discardableResult func post(_ event: KeyboardEvent) -> Bool
}

final class RecordingKeyboardEventSender: KeyboardEventSending {
    private(set) var events: [KeyboardEvent] = []
    var result: (KeyboardEvent) -> Bool

    init(result: @escaping (KeyboardEvent) -> Bool = { _ in true }) {
        self.result = result
    }

    @discardableResult
    func post(_ event: KeyboardEvent) -> Bool {
        events.append(event)
        return result(event)
    }
}

final class CoreGraphicsKeyboardEventSender: KeyboardEventSending {
    typealias EventFactory = (CGEventSource, CGKeyCode, Bool) -> CGEvent?
    typealias EventPoster = (CGEvent) -> Void

    private let source: CGEventSource?
    private let makeEvent: EventFactory
    private let postEvent: EventPoster

    init(
        source: CGEventSource? = CGEventSource(stateID: .hidSystemState),
        makeEvent: @escaping EventFactory = { CGEvent(keyboardEventSource: $0, virtualKey: $1, keyDown: $2) },
        postEvent: @escaping EventPoster = { $0.post(tap: .cghidEventTap) }
    ) {
        self.source = source
        self.makeEvent = makeEvent
        self.postEvent = postEvent
    }

    @discardableResult func post(_ event: KeyboardEvent) -> Bool {
        guard let source,
              let cgEvent = makeEvent(source, CGKeyCode(event.keyCode), event.isDown) else { return false }
        cgEvent.flags = event.flags
        postEvent(cgEvent)
        return true
    }
}

@MainActor
enum KeyboardEventSequence {
    static func downEvents(for binding: KeyboardBinding) -> [KeyboardEvent] {
        if binding.modifiers.isEmpty, let flag = standaloneModifierFlag(for: binding.keyCode) {
            return [KeyboardEvent(keyCode: binding.keyCode, isDown: true, flags: flag)]
        }

        var flags: CGEventFlags = []
        var events: [KeyboardEvent] = []
        for (modifier, keyCode) in KeyboardKeyCatalog.modifierCodes where binding.modifiers.contains(modifier) {
            flags.insert(cgFlag(for: modifier))
            events.append(KeyboardEvent(keyCode: keyCode, isDown: true, flags: flags))
        }
        events.append(KeyboardEvent(keyCode: binding.keyCode, isDown: true, flags: flags))
        return events
    }

    static func upEvents(for binding: KeyboardBinding) -> [KeyboardEvent] {
        if binding.modifiers.isEmpty, standaloneModifierFlag(for: binding.keyCode) != nil {
            return [KeyboardEvent(keyCode: binding.keyCode, isDown: false, flags: [])]
        }

        var flags = cgFlags(for: binding.modifiers)
        var events = [KeyboardEvent(keyCode: binding.keyCode, isDown: false, flags: flags)]
        for (modifier, keyCode) in KeyboardKeyCatalog.modifierCodes.reversed() where binding.modifiers.contains(modifier) {
            flags.remove(cgFlag(for: modifier))
            events.append(KeyboardEvent(keyCode: keyCode, isDown: false, flags: flags))
        }
        return events
    }

    private static func standaloneModifierFlag(for keyCode: UInt16) -> CGEventFlags? {
        guard let modifier = KeyboardKeyCatalog.modifier(for: keyCode) else { return nil }
        return cgFlag(for: modifier)
    }

    private static func cgFlags(for modifiers: KeyboardModifiers) -> CGEventFlags {
        var flags: CGEventFlags = []
        for (modifier, _) in KeyboardKeyCatalog.modifierCodes where modifiers.contains(modifier) {
            flags.insert(cgFlag(for: modifier))
        }
        return flags
    }

    private static func cgFlag(for modifier: KeyboardModifiers) -> CGEventFlags {
        if modifier == .control { return .maskControl }
        if modifier == .option { return .maskAlternate }
        if modifier == .shift { return .maskShift }
        return .maskCommand
    }
}

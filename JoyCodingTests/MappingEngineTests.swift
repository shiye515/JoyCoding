import ApplicationServices
import Carbon.HIToolbox
import XCTest
@testable import JoyCoding

@MainActor
final class KeyboardEventSenderTests: XCTestCase {
    func testCombinationSequenceUsesFixedOrderAndCumulativeFlags() {
        let binding = KeyboardBinding(
            keyCode: UInt16(kVK_ANSI_K),
            modifiers: [.control, .option, .shift, .command]
        )

        XCTAssertEqual(KeyboardEventSequence.downEvents(for: binding), [
            KeyboardEvent(keyCode: UInt16(kVK_Control), isDown: true, flags: [.maskControl]),
            KeyboardEvent(keyCode: UInt16(kVK_Option), isDown: true, flags: [.maskControl, .maskAlternate]),
            KeyboardEvent(keyCode: UInt16(kVK_Shift), isDown: true, flags: [.maskControl, .maskAlternate, .maskShift]),
            KeyboardEvent(keyCode: UInt16(kVK_Command), isDown: true, flags: [.maskControl, .maskAlternate, .maskShift, .maskCommand]),
            KeyboardEvent(keyCode: UInt16(kVK_ANSI_K), isDown: true, flags: [.maskControl, .maskAlternate, .maskShift, .maskCommand])
        ])
        XCTAssertEqual(KeyboardEventSequence.upEvents(for: binding), [
            KeyboardEvent(keyCode: UInt16(kVK_ANSI_K), isDown: false, flags: [.maskControl, .maskAlternate, .maskShift, .maskCommand]),
            KeyboardEvent(keyCode: UInt16(kVK_Command), isDown: false, flags: [.maskControl, .maskAlternate, .maskShift]),
            KeyboardEvent(keyCode: UInt16(kVK_Shift), isDown: false, flags: [.maskControl, .maskAlternate]),
            KeyboardEvent(keyCode: UInt16(kVK_Option), isDown: false, flags: [.maskControl]),
            KeyboardEvent(keyCode: UInt16(kVK_Control), isDown: false, flags: [])
        ])
    }

    func testMainAndStandaloneModifierSequences() {
        let main = KeyboardBinding(keyCode: UInt16(kVK_Space))
        XCTAssertEqual(KeyboardEventSequence.downEvents(for: main), [KeyboardEvent(keyCode: UInt16(kVK_Space), isDown: true, flags: [])])
        XCTAssertEqual(KeyboardEventSequence.upEvents(for: main), [KeyboardEvent(keyCode: UInt16(kVK_Space), isDown: false, flags: [])])

        let modifier = KeyboardBinding(keyCode: UInt16(kVK_RightCommand))
        XCTAssertEqual(KeyboardEventSequence.downEvents(for: modifier), [KeyboardEvent(keyCode: UInt16(kVK_RightCommand), isDown: true, flags: .maskCommand)])
        XCTAssertEqual(KeyboardEventSequence.upEvents(for: modifier), [KeyboardEvent(keyCode: UInt16(kVK_RightCommand), isDown: false, flags: [])])
    }

    func testRecordingSenderAndCoreGraphicsCreationFailures() throws {
        let event = KeyboardEvent(keyCode: UInt16(kVK_ANSI_A), isDown: true, flags: [])
        let recording = RecordingKeyboardEventSender(result: { _ in false })
        XCTAssertFalse(recording.post(event))
        XCTAssertEqual(recording.events, [event])

        XCTAssertFalse(CoreGraphicsKeyboardEventSender(source: nil).post(event))
        let source = try XCTUnwrap(CGEventSource(stateID: .hidSystemState))
        let sender = CoreGraphicsKeyboardEventSender(source: source, makeEvent: { _, _, _ in nil })
        XCTAssertFalse(sender.post(event))
    }
}

@MainActor
final class MappingEngineTests: XCTestCase {
    private actor ManualSleeper: MappingSleeping {
        private var waits: [(Duration, CheckedContinuation<Void, Never>)] = []

        func sleep(for duration: Duration) async throws {
            try Task.checkCancellation()
            await withCheckedContinuation { continuation in
                waits.append((duration, continuation))
            }
            try Task.checkCancellation()
        }

        func nextDuration() -> Duration? { waits.first?.0 }

        func advance() {
            guard !waits.isEmpty else { return }
            waits.removeFirst().1.resume()
        }
    }

    func testHoldPostsDownThenUp() {
        let (store, _) = makeStore()
        store.save(mapping(keyCode: kVK_ANSI_A), profileID: "p", buttonID: "a")
        let sender = RecordingKeyboardEventSender()
        let engine = MappingEngine(store: store, sender: sender, accessibilityAllowed: { true })
        let source = MappingSource(deviceSessionID: UUID(), buttonID: "a")

        engine.pressed(source: source, profileID: "p")
        engine.released(source: source)

        XCTAssertEqual(sender.events.map(\.isDown), [true, false])
        XCTAssertEqual(sender.events.map(\.keyCode), [UInt16(kVK_ANSI_A), UInt16(kVK_ANSI_A)])
    }

    func testPermissionDeniedAndUnmappedSourcesPostNothing() {
        let (store, _) = makeStore()
        store.save(mapping(keyCode: kVK_ANSI_A), profileID: "p", buttonID: "a")
        let sender = RecordingKeyboardEventSender()
        let denied = MappingEngine(store: store, sender: sender, accessibilityAllowed: { false })
        denied.pressed(source: MappingSource(deviceSessionID: UUID(), buttonID: "a"), profileID: "p")

        let allowed = MappingEngine(store: store, sender: sender, accessibilityAllowed: { true })
        allowed.pressed(source: MappingSource(deviceSessionID: UUID(), buttonID: "missing"), profileID: "p")
        XCTAssertTrue(sender.events.isEmpty)
    }

    func testMultipleSourcesReferenceCountAndSnapshot() {
        let (store, _) = makeStore()
        store.save(mapping(keyCode: kVK_ANSI_A), profileID: "p", buttonID: "a")
        let sender = RecordingKeyboardEventSender()
        let engine = MappingEngine(store: store, sender: sender, accessibilityAllowed: { true })
        let first = MappingSource(deviceSessionID: UUID(), buttonID: "a")
        let second = MappingSource(deviceSessionID: UUID(), buttonID: "a")

        engine.pressed(source: first, profileID: "p")
        engine.pressed(source: second, profileID: "p")
        store.save(mapping(keyCode: kVK_ANSI_B), profileID: "p", buttonID: "a")
        engine.released(source: first)
        XCTAssertEqual(sender.events.map(\.isDown), [true])
        engine.released(source: second)
        XCTAssertEqual(sender.events.map(\.isDown), [true, false])
        XCTAssertEqual(sender.events.map(\.keyCode), [UInt16(kVK_ANSI_A), UInt16(kVK_ANSI_A)])

        engine.pressed(source: first, profileID: "p")
        engine.released(source: first)
        XCTAssertEqual(sender.events.suffix(2).map(\.keyCode), [UInt16(kVK_ANSI_B), UInt16(kVK_ANSI_B)])
    }

    func testFailureRollsBackPartialCombination() {
        let (store, _) = makeStore()
        store.save(
            KeyboardButtonMapping(binding: KeyboardBinding(keyCode: UInt16(kVK_ANSI_K), modifiers: .command), holdBehavior: .hold),
            profileID: "p",
            buttonID: "a"
        )
        var shouldFail = true
        let sender = RecordingKeyboardEventSender { event in
            if shouldFail, event.keyCode == UInt16(kVK_ANSI_K), event.isDown { return false }
            return true
        }
        let engine = MappingEngine(store: store, sender: sender, accessibilityAllowed: { true })
        let source = MappingSource(deviceSessionID: UUID(), buttonID: "a")

        engine.pressed(source: source, profileID: "p")
        XCTAssertEqual(sender.events.map(\.keyCode), [UInt16(kVK_Command), UInt16(kVK_ANSI_K), UInt16(kVK_Command)])
        XCTAssertEqual(sender.events.map(\.isDown), [true, true, false])

        shouldFail = false
        engine.pressed(source: source, profileID: "p")
        engine.released(source: source)
        XCTAssertEqual(sender.events.suffix(4).map(\.isDown), [true, true, false, false])
    }

    func testRepeatUsesTwoHundredMillisecondsAndStopsAfterRelease() async {
        let (store, _) = makeStore()
        store.save(mapping(keyCode: kVK_ANSI_A, behavior: .repeatPress), profileID: "p", buttonID: "a")
        let sender = RecordingKeyboardEventSender()
        let sleeper = ManualSleeper()
        let engine = MappingEngine(store: store, sender: sender, sleeper: sleeper, accessibilityAllowed: { true })
        let source = MappingSource(deviceSessionID: UUID(), buttonID: "a")

        engine.pressed(source: source, profileID: "p")
        engine.pressed(source: source, profileID: "p")
        XCTAssertEqual(sender.events.count, 2)
        await waitUntil { await sleeper.nextDuration() != nil }
        let duration = await sleeper.nextDuration()
        XCTAssertEqual(duration, .milliseconds(200))

        await sleeper.advance()
        await waitUntil { sender.events.count == 4 }
        await waitUntil { await sleeper.nextDuration() != nil }
        engine.released(source: source)
        await sleeper.advance()
        for _ in 0..<5 { await Task.yield() }
        XCTAssertEqual(sender.events.count, 4)
    }

    func testReleaseAllFiltersAndIsIdempotent() {
        let (store, _) = makeStore()
        store.save(mapping(keyCode: kVK_ANSI_A), profileID: "p1", buttonID: "a")
        store.save(mapping(keyCode: kVK_ANSI_B), profileID: "p2", buttonID: "b")
        let sender = RecordingKeyboardEventSender()
        let engine = MappingEngine(store: store, sender: sender, accessibilityAllowed: { true })
        let firstID = UUID()
        let first = MappingSource(deviceSessionID: firstID, buttonID: "a")
        let second = MappingSource(deviceSessionID: UUID(), buttonID: "b")
        engine.pressed(source: first, profileID: "p1")
        engine.pressed(source: second, profileID: "p2")

        engine.releaseAll(deviceSessionID: firstID)
        engine.releaseAll(deviceSessionID: firstID)
        XCTAssertEqual(sender.events.filter { !$0.isDown }.map(\.keyCode), [UInt16(kVK_ANSI_A)])
        engine.releaseAll(profileID: "p2", buttonID: "b")
        engine.releaseAll()
        XCTAssertEqual(sender.events.filter { !$0.isDown }.map(\.keyCode), [UInt16(kVK_ANSI_A), UInt16(kVK_ANSI_B)])
    }

    private func makeStore() -> (UserDefaultsKeyboardMappingStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "MappingEngineTests.\(UUID().uuidString)")!
        return (UserDefaultsKeyboardMappingStore(defaults: defaults), defaults)
    }

    private func mapping(keyCode: Int, behavior: MappingHoldBehavior = .hold) -> KeyboardButtonMapping {
        KeyboardButtonMapping(binding: KeyboardBinding(keyCode: UInt16(keyCode)), holdBehavior: behavior)
    }

    private func waitUntil(_ condition: @escaping @MainActor () async -> Bool) async {
        for _ in 0..<100 {
            if await condition() { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for asynchronous mapping state")
    }
}

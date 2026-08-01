import AppKit
import Carbon.HIToolbox
import XCTest
@testable import JoyCoding

@MainActor
final class KeyboardMappingTests: XCTestCase {
    func testProfileIDIsStableForWhitespaceCaseAndButtonOrder() {
        let first = ControllerProfileID.make(name: " Xbox ", category: "GAMEPAD", buttonIDs: ["b", "a"])
        let second = ControllerProfileID.make(name: "xbox", category: "gamepad", buttonIDs: ["a", "b"])
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, ControllerProfileID.make(name: "Xbox 2", category: "gamepad", buttonIDs: ["a", "b"]))
        XCTAssertNotEqual(first, ControllerProfileID.make(name: "Xbox", category: "wheel", buttonIDs: ["a", "b"]))
        XCTAssertNotEqual(first, ControllerProfileID.make(name: "Xbox", category: "gamepad", buttonIDs: ["a", "c"]))
    }
    func testStorePersistsAndRemovesMapping() {
        let suite = UserDefaults(suiteName: "KeyboardMappingTests.\(UUID().uuidString)")!
        let store = UserDefaultsKeyboardMappingStore(defaults: suite)
        let mapping = KeyboardButtonMapping(binding: KeyboardBinding(keyCode: 0), holdBehavior: .hold)
        store.save(mapping, profileID: "profile", buttonID: "a")
        XCTAssertEqual(store.mapping(profileID: "profile", buttonID: "a"), mapping)
        store.remove(profileID: "profile", buttonID: "a")
        XCTAssertNil(store.mapping(profileID: "profile", buttonID: "a"))
    }
    func testModifierThenMainKeyProducesCombination() {
        var state = KeyboardCaptureState(); state.start()
        XCTAssertNil(state.flagsChanged(code: 55, flags: .command))
        XCTAssertEqual(state.keyDown(code: 40, flags: .command, isRepeat: false), KeyboardBinding(keyCode: 40, modifiers: .command))
    }

    func testMultipleModifiersArePreservedWithMainKey() {
        var state = KeyboardCaptureState()
        state.start()
        XCTAssertNil(state.flagsChanged(code: UInt16(kVK_Control), flags: .control))
        XCTAssertNil(state.flagsChanged(code: UInt16(kVK_Option), flags: [.control, .option]))
        XCTAssertNil(state.flagsChanged(code: UInt16(kVK_Shift), flags: [.control, .option, .shift]))
        XCTAssertNil(state.flagsChanged(code: UInt16(kVK_Command), flags: [.control, .option, .shift, .command]))
        XCTAssertEqual(
            state.keyDown(code: UInt16(kVK_ANSI_K), flags: [.control, .option, .shift, .command], isRepeat: false),
            KeyboardBinding(keyCode: UInt16(kVK_ANSI_K), modifiers: [.control, .option, .shift, .command])
        )
    }
    func testSingleModifierCompletesOnRelease() {
        var state = KeyboardCaptureState(); state.start()
        XCTAssertNil(state.flagsChanged(code: 56, flags: .shift))
        XCTAssertEqual(state.flagsChanged(code: 56, flags: []), KeyboardBinding(keyCode: 56))

        state.start()
        XCTAssertNil(state.flagsChanged(code: UInt16(kVK_RightOption), flags: .option))
        XCTAssertEqual(state.flagsChanged(code: UInt16(kVK_RightOption), flags: []), KeyboardBinding(keyCode: UInt16(kVK_RightOption)))
    }
    func testMappingCodableAndFallbackName() throws {
        let mapping = KeyboardButtonMapping(binding: KeyboardBinding(keyCode: 999, modifiers: [.command, .shift]), holdBehavior: .repeatPress)
        let decoded = try JSONDecoder().decode(KeyboardButtonMapping.self, from: JSONEncoder().encode(mapping))
        XCTAssertEqual(decoded, mapping)
        XCTAssertEqual(KeyboardKeyCatalog.displayName(for: KeyboardBinding(keyCode: UInt16(kVK_ANSI_K), modifiers: [.control, .option, .shift, .command])), "⌃+⌥+⇧+⌘+K")
        XCTAssertEqual(KeyboardKeyCatalog.displayName(for: KeyboardBinding(keyCode: UInt16(kVK_RightOption))), "右⌥")
        XCTAssertEqual(KeyboardKeyCatalog.displayName(for: KeyboardBinding(keyCode: 999)), "Key 999")
    }

    func testCaptureAcceptsEscapeAndIgnoresAutomaticRepeat() {
        var state = KeyboardCaptureState()
        state.start()
        XCTAssertNil(state.keyDown(code: UInt16(kVK_ANSI_K), flags: [], isRepeat: true))
        XCTAssertEqual(state.keyDown(code: UInt16(kVK_Escape), flags: [], isRepeat: false), KeyboardBinding(keyCode: UInt16(kVK_Escape)))
    }

    func testStartingAndCancellingCaptureDoesNotMutateExistingDraft() {
        let draft = KeyboardBinding(keyCode: UInt16(kVK_ANSI_A), modifiers: .command)
        var state = KeyboardCaptureState()
        state.start()
        _ = state.flagsChanged(code: UInt16(kVK_Command), flags: .command)
        state.start()
        XCTAssertEqual(draft, KeyboardBinding(keyCode: UInt16(kVK_ANSI_A), modifiers: .command))
        XCTAssertTrue(state.seenModifierCodes.isEmpty)
        XCTAssertNil(state.error)
    }
    func testMultipleModifiersWithoutMainKeyKeepsCaptureActive() {
        var state = KeyboardCaptureState(); state.start()
        _ = state.flagsChanged(code: 55, flags: .command)
        _ = state.flagsChanged(code: 56, flags: [.command, .shift])
        _ = state.flagsChanged(code: 56, flags: .command)
        XCTAssertNil(state.flagsChanged(code: 55, flags: []))
        XCTAssertEqual(state.error, "组合键需要一个非修饰主键")
    }
    func testStoreKeepsProfilesSeparateAndRecoversFromBadData() {
        let suite = UserDefaults(suiteName: "KeyboardMappingTests.\(UUID().uuidString)")!
        let mapping = KeyboardButtonMapping(binding: KeyboardBinding(keyCode: 0), holdBehavior: .hold)
        let store = UserDefaultsKeyboardMappingStore(defaults: suite)
        store.save(mapping, profileID: "one", buttonID: "a")
        XCTAssertNil(store.mapping(profileID: "two", buttonID: "a"))
        suite.set(Data("bad".utf8), forKey: UserDefaultsKeyboardMappingStore.defaultsKey)
        XCTAssertNil(UserDefaultsKeyboardMappingStore(defaults: suite).mapping(profileID: "one", buttonID: "a"))
    }

    func testStoreOverwritesReconnectsAndRewritesUnsupportedVersionAfterMutation() throws {
        let suite = UserDefaults(suiteName: "KeyboardMappingTests.\(UUID().uuidString)")!
        let first = KeyboardButtonMapping(binding: KeyboardBinding(keyCode: UInt16(kVK_ANSI_A)), holdBehavior: .hold)
        let replacement = KeyboardButtonMapping(binding: KeyboardBinding(keyCode: UInt16(kVK_ANSI_B)), holdBehavior: .repeatPress)
        let store = UserDefaultsKeyboardMappingStore(defaults: suite)
        store.save(first, profileID: "profile", buttonID: "a")
        store.save(replacement, profileID: "profile", buttonID: "a")
        XCTAssertEqual(UserDefaultsKeyboardMappingStore(defaults: suite).mapping(profileID: "profile", buttonID: "a"), replacement)

        let unsupported = try JSONSerialization.data(withJSONObject: ["schemaVersion": 99, "profiles": [:]])
        suite.set(unsupported, forKey: UserDefaultsKeyboardMappingStore.defaultsKey)
        let unsupportedStore = UserDefaultsKeyboardMappingStore(defaults: suite)
        XCTAssertNil(unsupportedStore.mapping(profileID: "profile", buttonID: "a"))
        XCTAssertEqual(suite.data(forKey: UserDefaultsKeyboardMappingStore.defaultsKey), unsupported)

        unsupportedStore.save(first, profileID: "profile", buttonID: "a")
        let rewrittenData = try XCTUnwrap(suite.data(forKey: UserDefaultsKeyboardMappingStore.defaultsKey))
        let rewritten = try XCTUnwrap(JSONSerialization.jsonObject(with: rewrittenData) as? [String: Any])
        XCTAssertEqual(rewritten["schemaVersion"] as? Int, 1)
        XCTAssertEqual(UserDefaultsKeyboardMappingStore(defaults: suite).mapping(profileID: "profile", buttonID: "a"), first)
    }
}

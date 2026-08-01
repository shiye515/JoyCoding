import Carbon.HIToolbox
import XCTest
@testable import JoyCoding

@MainActor
final class ControllerMappingIntegrationTests: XCTestCase {
    func testUnmappedAndRepeatedStateCallbacksDoNotEmitExtraEvents() {
        let context = makeContext()
        context.service.setPressed(true, button: .a, deviceID: context.device.id)
        context.service.setPressed(true, button: .a, deviceID: context.device.id)
        context.service.setPressed(false, button: .a, deviceID: context.device.id)
        XCTAssertTrue(context.sender.events.isEmpty)

        context.store.save(mapping(kVK_ANSI_A), profileID: context.device.profileID, buttonID: ControllerButton.a.id)
        context.service.setPressed(true, button: .a, deviceID: context.device.id)
        context.service.setPressed(true, button: .a, deviceID: context.device.id)
        context.service.setPressed(false, button: .a, deviceID: context.device.id)
        context.service.setPressed(false, button: .a, deviceID: context.device.id)
        XCTAssertEqual(context.sender.events.map(\.isDown), [true, false])
    }

    func testSavedMappingChangesOnlyAfterNextPress() {
        let context = makeContext()
        context.store.save(mapping(kVK_ANSI_A), profileID: context.device.profileID, buttonID: ControllerButton.a.id)
        context.service.setPressed(true, button: .a, deviceID: context.device.id)

        context.store.save(mapping(kVK_ANSI_B), profileID: context.device.profileID, buttonID: ControllerButton.a.id)
        context.service.setPressed(false, button: .a, deviceID: context.device.id)
        XCTAssertEqual(context.sender.events.map(\.keyCode), [UInt16(kVK_ANSI_A), UInt16(kVK_ANSI_A)])

        context.service.setPressed(true, button: .a, deviceID: context.device.id)
        context.service.setPressed(false, button: .a, deviceID: context.device.id)
        XCTAssertEqual(context.sender.events.suffix(2).map(\.keyCode), [UInt16(kVK_ANSI_B), UInt16(kVK_ANSI_B)])
    }

    func testDisconnectAndClearReleaseActiveMappings() {
        let disconnected = makeContext()
        disconnected.store.save(mapping(kVK_ANSI_A), profileID: disconnected.device.profileID, buttonID: ControllerButton.a.id)
        disconnected.service.setPressed(true, button: .a, deviceID: disconnected.device.id)
        disconnected.service.disconnectDevice(disconnected.device.id)
        XCTAssertEqual(disconnected.sender.events.map(\.isDown), [true, false])
        XCTAssertTrue(disconnected.service.state.devices.isEmpty)

        let cleared = makeContext()
        cleared.store.save(mapping(kVK_ANSI_B), profileID: cleared.device.profileID, buttonID: ControllerButton.a.id)
        cleared.service.setPressed(true, button: .a, deviceID: cleared.device.id)
        cleared.service.clearMapping(profileID: cleared.device.profileID, buttonID: ControllerButton.a.id)
        XCTAssertEqual(cleared.sender.events.map(\.isDown), [true, false])
        XCTAssertNil(cleared.store.mapping(profileID: cleared.device.profileID, buttonID: ControllerButton.a.id))
    }

    func testStopIsIdempotentAndReleasesActiveMapping() {
        let context = makeContext()
        context.store.save(mapping(kVK_ANSI_A), profileID: context.device.profileID, buttonID: ControllerButton.a.id)
        context.service.start()
        context.service.setPressed(true, button: .a, deviceID: context.device.id)
        context.service.stop()
        context.service.stop()
        XCTAssertEqual(context.sender.events.map(\.isDown), [true, false])
    }

    private func makeContext() -> (
        service: ControllerService,
        device: ControllerDevice,
        store: UserDefaultsKeyboardMappingStore,
        sender: RecordingKeyboardEventSender
    ) {
        let device = ControllerDevice(id: UUID(), name: "Test Controller", category: "Gamepad", buttons: [.a])
        var state = ControllerState()
        state.add(device)
        let defaults = UserDefaults(suiteName: "ControllerMappingIntegrationTests.\(UUID().uuidString)")!
        let store = UserDefaultsKeyboardMappingStore(defaults: defaults)
        let sender = RecordingKeyboardEventSender()
        let engine = MappingEngine(store: store, sender: sender, accessibilityAllowed: { true })
        let service = ControllerService(state: state, mappingStore: store, mappingEngine: engine, autoStart: false)
        return (service, device, store, sender)
    }

    private func mapping(_ keyCode: Int) -> KeyboardButtonMapping {
        KeyboardButtonMapping(binding: KeyboardBinding(keyCode: UInt16(keyCode)), holdBehavior: .hold)
    }
}

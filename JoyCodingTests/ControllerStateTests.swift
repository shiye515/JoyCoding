import XCTest
@testable import JoyCoding

final class ControllerStateTests: XCTestCase {
    func testFirstDeviceIsSelectedAndDuplicateIsIgnored() {
        let device = makeDevice(name: "First")
        var state = ControllerState()

        state.add(device)
        state.add(device)

        XCTAssertEqual(state.devices, [device])
        XCTAssertEqual(state.selectedDeviceID, device.id)
    }

    func testManualSelectionSurvivesUnrelatedDisconnect() {
        let first = makeDevice(name: "First")
        let second = makeDevice(name: "Second")
        var state = ControllerState()
        state.add(first)
        state.add(second)
        state.select(second.id)

        state.remove(first.id)

        XCTAssertEqual(state.selectedDeviceID, second.id)
        XCTAssertEqual(state.devices, [second])
    }

    func testSelectedDisconnectChoosesFirstRemainingDevice() {
        let first = makeDevice(name: "First")
        let second = makeDevice(name: "Second")
        var state = ControllerState()
        state.add(first)
        state.add(second)

        state.remove(first.id)

        XCTAssertEqual(state.selectedDeviceID, second.id)
    }

    func testLastDisconnectClearsSelection() {
        let device = makeDevice(name: "Only")
        var state = ControllerState()
        state.add(device)

        state.remove(device.id)

        XCTAssertTrue(state.devices.isEmpty)
        XCTAssertNil(state.selectedDeviceID)
    }

    func testUnknownSelectionIsIgnored() {
        let device = makeDevice(name: "Known")
        var state = ControllerState()
        state.add(device)

        state.select(UUID())

        XCTAssertEqual(state.selectedDeviceID, device.id)
    }

    func testMultipleButtonsAndDevicesKeepIndependentPressedState() {
        let first = makeDevice(name: "First", buttons: [.a, .b])
        let second = makeDevice(name: "Second", buttons: [.a, .b])
        var state = ControllerState()
        state.add(first)
        state.add(second)

        state.setPressed(true, buttonID: ControllerButton.a.id, deviceID: first.id)
        state.setPressed(true, buttonID: ControllerButton.b.id, deviceID: first.id)
        state.setPressed(true, buttonID: ControllerButton.a.id, deviceID: second.id)
        state.setPressed(true, buttonID: ControllerButton.a.id, deviceID: second.id)

        XCTAssertTrue(state.isPressed(ControllerButton.a.id, on: first.id))
        XCTAssertTrue(state.isPressed(ControllerButton.b.id, on: first.id))
        XCTAssertTrue(state.isPressed(ControllerButton.a.id, on: second.id))
        XCTAssertFalse(state.isPressed(ControllerButton.b.id, on: second.id))

        state.setPressed(false, buttonID: ControllerButton.a.id, deviceID: first.id)

        XCTAssertFalse(state.isPressed(ControllerButton.a.id, on: first.id))
        XCTAssertTrue(state.isPressed(ControllerButton.b.id, on: first.id))
        XCTAssertTrue(state.isPressed(ControllerButton.a.id, on: second.id))
    }

    func testDisconnectClearsPressedState() {
        let device = makeDevice(name: "Controller")
        var state = ControllerState()
        state.add(device)
        state.setPressed(true, buttonID: ControllerButton.a.id, deviceID: device.id)

        state.remove(device.id)

        XCTAssertFalse(state.isPressed(ControllerButton.a.id, on: device.id))
    }

    func testUnknownButtonEventIsIgnored() {
        let device = makeDevice(name: "Controller", buttons: [.a])
        var state = ControllerState()
        state.add(device)

        state.setPressed(true, buttonID: ControllerButton.b.id, deviceID: device.id)

        XCTAssertFalse(state.isPressed(ControllerButton.b.id, on: device.id))
    }

    private func makeDevice(
        name: String,
        buttons: [ControllerButton] = [.a]
    ) -> ControllerDevice {
        ControllerDevice(id: UUID(), name: name, category: "Test", buttons: buttons)
    }
}

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
        XCTAssertEqual(state.selectedButtonID, ControllerButton.a.id)
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
        XCTAssertEqual(state.selectedButtonID, ControllerButton.a.id)
    }

    func testSelectedDisconnectChoosesFirstRemainingDevice() {
        let first = makeDevice(name: "First")
        let second = makeDevice(name: "Second")
        var state = ControllerState()
        state.add(first)
        state.add(second)

        state.remove(first.id)

        XCTAssertEqual(state.selectedDeviceID, second.id)
        XCTAssertEqual(state.selectedButtonID, ControllerButton.a.id)
    }

    func testLastDisconnectClearsSelection() {
        let device = makeDevice(name: "Only")
        var state = ControllerState()
        state.add(device)

        state.remove(device.id)

        XCTAssertTrue(state.devices.isEmpty)
        XCTAssertNil(state.selectedDeviceID)
        XCTAssertNil(state.selectedButtonID)
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

        _ = state.setPressed(true, buttonID: ControllerButton.a.id, deviceID: first.id)
        _ = state.setPressed(true, buttonID: ControllerButton.b.id, deviceID: first.id)
        _ = state.setPressed(true, buttonID: ControllerButton.a.id, deviceID: second.id)
        _ = state.setPressed(true, buttonID: ControllerButton.a.id, deviceID: second.id)

        XCTAssertTrue(state.isPressed(ControllerButton.a.id, on: first.id))
        XCTAssertTrue(state.isPressed(ControllerButton.b.id, on: first.id))
        XCTAssertTrue(state.isPressed(ControllerButton.a.id, on: second.id))
        XCTAssertFalse(state.isPressed(ControllerButton.b.id, on: second.id))

        _ = state.setPressed(false, buttonID: ControllerButton.a.id, deviceID: first.id)

        XCTAssertFalse(state.isPressed(ControllerButton.a.id, on: first.id))
        XCTAssertTrue(state.isPressed(ControllerButton.b.id, on: first.id))
        XCTAssertTrue(state.isPressed(ControllerButton.a.id, on: second.id))
    }

    func testDisconnectClearsPressedState() {
        let device = makeDevice(name: "Controller")
        var state = ControllerState()
        state.add(device)
        _ = state.setPressed(true, buttonID: ControllerButton.a.id, deviceID: device.id)

        state.remove(device.id)

        XCTAssertFalse(state.isPressed(ControllerButton.a.id, on: device.id))
    }

    func testUnknownButtonEventIsIgnored() {
        let device = makeDevice(name: "Controller", buttons: [.a])
        var state = ControllerState()
        state.add(device)

        _ = state.setPressed(true, buttonID: ControllerButton.b.id, deviceID: device.id)

        XCTAssertFalse(state.isPressed(ControllerButton.b.id, on: device.id))
    }

    func testSelectingButtonUpdatesOnlyTheSelectedButton() {
        let device = makeDevice(name: "Controller", buttons: [.a, .b])
        var state = ControllerState()
        state.add(device)

        state.selectButton(ControllerButton.b.id)

        XCTAssertEqual(state.selectedDeviceID, device.id)
        XCTAssertEqual(state.selectedButtonID, ControllerButton.b.id)
        XCTAssertEqual(state.selectedButton, .b)
    }

    func testSwitchingDeviceSelectsItsFirstButton() {
        let first = makeDevice(name: "First", buttons: [.a, .b])
        let second = makeDevice(name: "Second", buttons: [.x, .y])
        var state = ControllerState()
        state.add(first)
        state.add(second)
        state.selectButton(ControllerButton.b.id)

        state.select(second.id)

        XCTAssertEqual(state.selectedDeviceID, second.id)
        XCTAssertEqual(state.selectedButtonID, ControllerButton.x.id)
        XCTAssertEqual(state.selectedButton, .x)
    }

    func testPressedStateDoesNotChangeSelectedButton() {
        let device = makeDevice(name: "Controller", buttons: [.a, .b])
        var state = ControllerState()
        state.add(device)
        state.selectButton(ControllerButton.b.id)

        _ = state.setPressed(true, buttonID: ControllerButton.a.id, deviceID: device.id)
        _ = state.setPressed(false, buttonID: ControllerButton.a.id, deviceID: device.id)

        XCTAssertEqual(state.selectedButtonID, ControllerButton.b.id)
        XCTAssertEqual(state.selectedButton, .b)
    }

    func testSelectingUnknownButtonIsIgnored() {
        let device = makeDevice(name: "Controller", buttons: [.a])
        var state = ControllerState()
        state.add(device)

        state.selectButton(ControllerButton.b.id)

        XCTAssertEqual(state.selectedButtonID, ControllerButton.a.id)
    }

    private func makeDevice(
        name: String,
        buttons: [ControllerButton] = [.a]
    ) -> ControllerDevice {
        ControllerDevice(id: UUID(), name: name, category: "Test", buttons: buttons)
    }
}

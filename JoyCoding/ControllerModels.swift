import Foundation

struct ControllerButton: Identifiable, Hashable, Comparable, Sendable {
    typealias ID = String

    let id: ID
    let name: String
    let order: Int

    static func < (lhs: ControllerButton, rhs: ControllerButton) -> Bool {
        if lhs.order == rhs.order {
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        return lhs.order < rhs.order
    }

    static let a = ControllerButton(id: "button-a", name: "A", order: 10)
    static let b = ControllerButton(id: "button-b", name: "B", order: 11)
    static let x = ControllerButton(id: "button-x", name: "X", order: 12)
    static let y = ControllerButton(id: "button-y", name: "Y", order: 13)
    static let leftShoulder = ControllerButton(id: "left-shoulder", name: "左肩键", order: 20)
    static let rightShoulder = ControllerButton(id: "right-shoulder", name: "右肩键", order: 21)
    static let leftTrigger = ControllerButton(id: "left-trigger", name: "左扳机", order: 22)
    static let rightTrigger = ControllerButton(id: "right-trigger", name: "右扳机", order: 23)
    static let dpadUp = ControllerButton(id: "dpad-up", name: "方向键 上", order: 30)
    static let dpadDown = ControllerButton(id: "dpad-down", name: "方向键 下", order: 31)
    static let dpadLeft = ControllerButton(id: "dpad-left", name: "方向键 左", order: 32)
    static let dpadRight = ControllerButton(id: "dpad-right", name: "方向键 右", order: 33)
    static let menu = ControllerButton(id: "menu", name: "菜单", order: 40)
    static let options = ControllerButton(id: "options", name: "选项", order: 41)
    static let home = ControllerButton(id: "home", name: "主页", order: 42)
    static let leftThumbstick = ControllerButton(id: "left-thumbstick", name: "左摇杆按压", order: 50)
    static let rightThumbstick = ControllerButton(id: "right-thumbstick", name: "右摇杆按压", order: 51)

    static func physical(name: String, order: Int) -> ControllerButton {
        let identifier = name.unicodeScalars
            .map { String(format: "%04X", $0.value) }
            .joined(separator: "-")
        return ControllerButton(id: "physical-\(identifier)", name: name, order: order)
    }
}

struct ControllerDevice: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let category: String
    let buttons: [ControllerButton]
}

struct ControllerState: Equatable, Sendable {
    private(set) var devices: [ControllerDevice] = []
    private(set) var selectedDeviceID: ControllerDevice.ID?
    private(set) var selectedButtonID: ControllerButton.ID?
    private(set) var pressedButtonsByDevice: [ControllerDevice.ID: Set<ControllerButton.ID>] = [:]

    var selectedDevice: ControllerDevice? {
        devices.first { $0.id == selectedDeviceID }
    }

    var selectedButton: ControllerButton? {
        selectedDevice?.buttons.first { $0.id == selectedButtonID }
    }

    mutating func add(_ device: ControllerDevice) {
        guard !devices.contains(where: { $0.id == device.id }) else { return }
        devices.append(device)
        pressedButtonsByDevice[device.id] = []
        if selectedDeviceID == nil {
            selectedDeviceID = device.id
            selectedButtonID = device.buttons.sorted().first?.id
        }
    }

    mutating func select(_ id: ControllerDevice.ID) {
        guard devices.contains(where: { $0.id == id }) else { return }
        selectedDeviceID = id
        selectedButtonID = selectedDevice?.buttons.sorted().first?.id
    }

    mutating func selectButton(_ id: ControllerButton.ID) {
        guard selectedDevice?.buttons.contains(where: { $0.id == id }) == true else { return }
        selectedButtonID = id
    }

    mutating func remove(_ id: ControllerDevice.ID) {
        let wasSelected = selectedDeviceID == id
        devices.removeAll { $0.id == id }
        pressedButtonsByDevice.removeValue(forKey: id)
        if wasSelected {
            selectedDeviceID = devices.first?.id
            selectedButtonID = selectedDevice?.buttons.sorted().first?.id
        }
    }

    mutating func setPressed(
        _ pressed: Bool,
        buttonID: ControllerButton.ID,
        deviceID: ControllerDevice.ID
    ) {
        guard let device = devices.first(where: { $0.id == deviceID }),
              device.buttons.contains(where: { $0.id == buttonID }) else { return }

        var pressedButtons = pressedButtonsByDevice[deviceID, default: []]
        let changed: Bool
        if pressed {
            changed = pressedButtons.insert(buttonID).inserted
        } else {
            changed = pressedButtons.remove(buttonID) != nil
        }
        if changed {
            pressedButtonsByDevice[deviceID] = pressedButtons
        }
    }

    func isPressed(_ buttonID: ControllerButton.ID, on deviceID: ControllerDevice.ID) -> Bool {
        pressedButtonsByDevice[deviceID]?.contains(buttonID) == true
    }
}

extension ControllerState {
    static var preview: ControllerState {
        let firstID = UUID()
        let secondID = UUID()
        var state = ControllerState()
        state.add(ControllerDevice(
            id: firstID,
            name: "Xbox Wireless Controller",
            category: "Xbox One",
            buttons: [.a, .b, .x, .y, .leftShoulder, .rightShoulder, .leftTrigger, .rightTrigger, .dpadUp, .dpadDown, .dpadLeft, .dpadRight, .menu, .options, .leftThumbstick, .rightThumbstick]
        ))
        state.add(ControllerDevice(
            id: secondID,
            name: "DualSense Wireless Controller",
            category: "DualSense",
            buttons: [.a, .b, .x, .y]
        ))
        state.setPressed(true, buttonID: ControllerButton.a.id, deviceID: firstID)
        state.setPressed(true, buttonID: ControllerButton.leftShoulder.id, deviceID: firstID)
        return state
    }
}

import Combine
import GameController
import AppKit

@MainActor
final class ControllerService: ObservableObject {
    @Published private(set) var state: ControllerState

    private var controllers: [ObjectIdentifier: GCController] = [:]
    private var deviceIDs: [ObjectIdentifier: ControllerDevice.ID] = [:]
    private var observers: [NSObjectProtocol] = []
    private var hasStarted = false
    let mappingStore: UserDefaultsKeyboardMappingStore
    private let mappingEngine: MappingEngine

    convenience init(autoStart: Bool = true) {
        self.init(state: ControllerState(), mappingStore: UserDefaultsKeyboardMappingStore(), autoStart: autoStart)
    }

    init(
        state: ControllerState,
        mappingStore: UserDefaultsKeyboardMappingStore,
        mappingEngine: MappingEngine? = nil,
        autoStart: Bool = true
    ) {
        self.state = state
        self.mappingStore = mappingStore
        self.mappingEngine = mappingEngine ?? MappingEngine(store: mappingStore)
        if autoStart {
            start()
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        controllers.values.forEach(Self.clearHandlers)
        GCController.stopWirelessControllerDiscovery()
        let engine = mappingEngine
        Task { @MainActor in engine.releaseAll() }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        GCController.shouldMonitorBackgroundEvents = true

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            MainActor.assumeIsolated {
                self?.register(controller)
            }
        })
        observers.append(center.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        })
        observers.append(center.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            MainActor.assumeIsolated {
                self?.unregister(controller)
            }
        })

        GCController.controllers().forEach(register)
        GCController.startWirelessControllerDiscovery()
    }

    func stop() {
        guard hasStarted else { return }
        hasStarted = false
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        controllers.values.forEach(Self.clearHandlers)
        controllers.removeAll()
        deviceIDs.removeAll()
        mappingEngine.releaseAll()
        GCController.stopWirelessControllerDiscovery()
        GCController.shouldMonitorBackgroundEvents = false
    }

    func clearMapping(profileID: String, buttonID: String) {
        mappingStore.remove(profileID: profileID, buttonID: buttonID)
        mappingEngine.releaseAll(profileID: profileID, buttonID: buttonID)
    }

    func selectDevice(_ id: ControllerDevice.ID) {
        state.select(id)
    }

    func selectButton(_ id: ControllerButton.ID) {
        state.selectButton(id)
    }

    private func register(_ controller: GCController) {
        let objectID = ObjectIdentifier(controller)
        guard controllers[objectID] == nil else { return }

        let deviceID = UUID()
        let buttons = installHandlers(for: controller, deviceID: deviceID)
        let name = controller.vendorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = (name?.isEmpty == false ? name : nil) ?? controller.productCategory
        let device = ControllerDevice(
            id: deviceID,
            name: resolvedName,
            category: controller.productCategory,
            buttons: buttons.sorted()
        )

        controllers[objectID] = controller
        deviceIDs[objectID] = deviceID
        state.add(device)
    }

    private func unregister(_ controller: GCController) {
        let objectID = ObjectIdentifier(controller)
        guard let deviceID = deviceIDs.removeValue(forKey: objectID) else { return }
        controllers.removeValue(forKey: objectID)
        Self.clearHandlers(controller)
        disconnectDevice(deviceID)
    }

    func disconnectDevice(_ deviceID: ControllerDevice.ID) {
        mappingEngine.releaseAll(deviceSessionID: deviceID)
        state.remove(deviceID)
    }

    private func installHandlers(
        for controller: GCController,
        deviceID: ControllerDevice.ID
    ) -> [ControllerButton] {
        if let gamepad = controller.extendedGamepad {
            return installExtendedGamepadHandlers(gamepad, deviceID: deviceID)
        }
        return installPhysicalProfileHandlers(controller.physicalInputProfile, deviceID: deviceID)
    }

    private func installExtendedGamepadHandlers(
        _ gamepad: GCExtendedGamepad,
        deviceID: ControllerDevice.ID
    ) -> [ControllerButton] {
        var descriptors: [ControllerButton] = []

        func bind(_ input: GCControllerButtonInput?, to descriptor: ControllerButton) {
            guard let input else { return }
            descriptors.append(descriptor)
            input.pressedChangedHandler = { [weak self] _, _, pressed in
                Task { @MainActor [weak self] in
                    self?.setPressed(pressed, button: descriptor, deviceID: deviceID)
                }
            }
        }

        bind(gamepad.buttonA, to: .a)
        bind(gamepad.buttonB, to: .b)
        bind(gamepad.buttonX, to: .x)
        bind(gamepad.buttonY, to: .y)
        bind(gamepad.leftShoulder, to: .leftShoulder)
        bind(gamepad.rightShoulder, to: .rightShoulder)
        bind(gamepad.leftTrigger, to: .leftTrigger)
        bind(gamepad.rightTrigger, to: .rightTrigger)
        bind(gamepad.dpad.up, to: .dpadUp)
        bind(gamepad.dpad.down, to: .dpadDown)
        bind(gamepad.dpad.left, to: .dpadLeft)
        bind(gamepad.dpad.right, to: .dpadRight)
        bind(gamepad.buttonMenu, to: .menu)
        bind(gamepad.buttonOptions, to: .options)
        bind(gamepad.buttonHome, to: .home)
        bind(gamepad.leftThumbstickButton, to: .leftThumbstick)
        bind(gamepad.rightThumbstickButton, to: .rightThumbstick)
        return descriptors
    }

    private func installPhysicalProfileHandlers(
        _ profile: GCPhysicalInputProfile,
        deviceID: ControllerDevice.ID
    ) -> [ControllerButton] {
        profile.buttons.keys.sorted().enumerated().map { index, name in
            let descriptor = ControllerButton.physical(name: name, order: 100 + index)
            profile.buttons[name]?.pressedChangedHandler = { [weak self] _, _, pressed in
                Task { @MainActor [weak self] in
                    self?.setPressed(pressed, button: descriptor, deviceID: deviceID)
                }
            }
            return descriptor
        }
    }

    func setPressed(
        _ pressed: Bool,
        button: ControllerButton,
        deviceID: ControllerDevice.ID
    ) {
        guard state.setPressed(pressed, buttonID: button.id, deviceID: deviceID),
              let device = state.devices.first(where: { $0.id == deviceID }) else { return }
        let source = MappingSource(deviceSessionID: deviceID, buttonID: button.id)
        if pressed { mappingEngine.pressed(source: source, profileID: device.profileID) }
        else { mappingEngine.released(source: source) }
    }

    private nonisolated static func clearHandlers(_ controller: GCController) {
        let profile = controller.physicalInputProfile
        profile.buttons.values.forEach { $0.pressedChangedHandler = nil }
        profile.dpads.values.forEach { dpad in
            dpad.valueChangedHandler = nil
            dpad.up.pressedChangedHandler = nil
            dpad.down.pressedChangedHandler = nil
            dpad.left.pressedChangedHandler = nil
            dpad.right.pressedChangedHandler = nil
        }
        profile.axes.values.forEach { $0.valueChangedHandler = nil }
    }
}

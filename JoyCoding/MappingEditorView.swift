import SwiftUI

struct MappingEditorView: View {
    let device: ControllerDevice
    let button: ControllerButton
    @ObservedObject var store: UserDefaultsKeyboardMappingStore
    let clear: (String, String) -> Void
    @EnvironmentObject private var permissions: PermissionsManager
    @State private var binding: KeyboardBinding?
    @State private var behavior: MappingHoldBehavior = .hold
    @State private var isCapturing = false
    @State private var captureError: String?
    private let skipInitialLoad: Bool

    init(
        device: ControllerDevice,
        button: ControllerButton,
        store: UserDefaultsKeyboardMappingStore,
        clear: @escaping (String, String) -> Void,
        initialBinding: KeyboardBinding? = nil,
        initialBehavior: MappingHoldBehavior = .hold,
        initialIsCapturing: Bool = false,
        initialCaptureError: String? = nil,
        skipInitialLoad: Bool = false
    ) {
        self.device = device
        self.button = button
        self.store = store
        self.clear = clear
        self.skipInitialLoad = skipInitialLoad
        _binding = State(initialValue: initialBinding)
        _behavior = State(initialValue: initialBehavior)
        _isCapturing = State(initialValue: initialIsCapturing)
        _captureError = State(initialValue: initialCaptureError)
    }

    private var saved: KeyboardButtonMapping? { store.mapping(profileID: device.profileID, buttonID: button.id) }
    private var draft: KeyboardButtonMapping? { binding.map { KeyboardButtonMapping(binding: $0, holdBehavior: behavior) } }
    private var dirty: Bool { draft != saved }
    var body: some View {
        GroupBox("键盘映射") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledContent("映射到") {
                    if let binding {
                        Text(KeyboardKeyCatalog.displayName(for: binding))
                    } else {
                        Text("未录入").foregroundStyle(.secondary)
                    }
                }
                HStack { Button(isCapturing ? "正在录入…" : "录入按键") { isCapturing.toggle() }; if isCapturing { Button("停止") { isCapturing = false } } }
                KeyboardCaptureView(isCapturing: $isCapturing, onBinding: { binding = $0 }, onError: { captureError = $0 }).frame(width: 1, height: 1)
                if let captureError { Text(captureError).foregroundStyle(.red).font(.caption) }
                Picker("按住行为", selection: $behavior) { ForEach(MappingHoldBehavior.allCases, id: \.self) { Text($0.displayName).tag($0) } }.pickerStyle(.segmented)
                if permissions.accessibility != .granted { Button("映射已保存但不会执行：打开辅助功能设置") { permissions.openAccessibilitySettings() }.font(.caption) }
                HStack { Button("清除映射", role: .destructive) { clear(device.profileID, button.id); binding = nil }.disabled(saved == nil); Spacer(); if dirty { Text("未保存").font(.caption).foregroundStyle(.orange) }; Button("保存") { if let draft { store.save(draft, profileID: device.profileID, buttonID: button.id) } }.buttonStyle(.borderedProminent).disabled(draft == nil || !dirty) }
            }.padding(.vertical, 4)
        }
        .onAppear { if !skipInitialLoad { load() } }.onChange(of: button.id) { _, _ in load() }.onChange(of: device.id) { _, _ in load() }
    }
    private func load() { binding = saved?.binding; behavior = saved?.holdBehavior ?? .hold; isCapturing = false; captureError = nil }
}

#Preview("Unmapped") {
    let device = ControllerDevice(id: UUID(), name: "Xbox Controller", category: "Gamepad", buttons: [.a])
    let store = UserDefaultsKeyboardMappingStore(defaults: UserDefaults(suiteName: "Preview.Unmapped")!)
    MappingEditorView(device: device, button: .a, store: store, clear: { _, _ in })
        .environmentObject(PermissionsManager(client: PermissionClient(
            accessibilityState: { .granted }, inputMonitoringState: { .granted },
            requestAccessibility: {}, requestInputMonitoring: {},
            openAccessibilitySettings: {}, openInputMonitoringSettings: {}
        )))
        .padding()
        .frame(width: 560)
}

#Preview("Mapped") {
    let device = ControllerDevice(id: UUID(), name: "Xbox Controller", category: "Gamepad", buttons: [.a])
    let store = UserDefaultsKeyboardMappingStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    store.save(
        KeyboardButtonMapping(binding: KeyboardBinding(keyCode: 40, modifiers: .command), holdBehavior: .hold),
        profileID: device.profileID,
        buttonID: ControllerButton.a.id
    )
    return MappingEditorView(device: device, button: .a, store: store, clear: { _, _ in })
        .environmentObject(PermissionsManager(client: PermissionClient(
            accessibilityState: { .granted }, inputMonitoringState: { .granted },
            requestAccessibility: {}, requestInputMonitoring: {},
            openAccessibilitySettings: {}, openInputMonitoringSettings: {}
        )))
        .padding()
        .frame(width: 560)
}

#Preview("Capturing, dirty, error, denied") {
    let device = ControllerDevice(id: UUID(), name: "Xbox Controller", category: "Gamepad", buttons: [.a])
    let store = UserDefaultsKeyboardMappingStore(defaults: UserDefaults(suiteName: "Preview.Capture")!)
    MappingEditorView(
        device: device,
        button: .a,
        store: store,
        clear: { _, _ in },
        initialBinding: KeyboardBinding(keyCode: 40, modifiers: .command),
        initialBehavior: .repeatPress,
        initialIsCapturing: true,
        initialCaptureError: "组合键需要一个非修饰主键",
        skipInitialLoad: true
    )
    .environmentObject(PermissionsManager(client: PermissionClient(
        accessibilityState: { .denied }, inputMonitoringState: { .granted },
        requestAccessibility: {}, requestInputMonitoring: {},
        openAccessibilitySettings: {}, openInputMonitoringSettings: {}
    )))
    .padding()
    .frame(width: 560)
}

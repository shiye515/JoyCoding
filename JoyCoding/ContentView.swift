import SwiftUI

struct ContentView: View {
    @ObservedObject var controllerService: ControllerService
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var permissionsManager: PermissionsManager

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 380)
        } detail: {
            mappingDetail
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $appState.isPermissionsPresented) {
            PermissionsOnboardingView {
                appState.finishPermissionsOnboarding()
            } onSkip: {
                appState.finishPermissionsOnboarding()
            }
            .environmentObject(permissionsManager)
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if controllerService.state.devices.isEmpty {
            ContentUnavailableView(
                "等待连接手柄",
                systemImage: "gamecontroller",
                description: Text("请通过 USB 或蓝牙连接手柄。")
            )
            .padding()
        } else {
            VStack(spacing: 0) {
                devicePicker
                Divider()
                buttonList
            }
            .navigationTitle("设备与按键")
        }
    }

    private var devicePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前设备")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Picker("当前设备", selection: selectedDeviceBinding) {
                ForEach(controllerService.state.devices) { device in
                    Text(device.name)
                        .tag(Optional(device.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }

    @ViewBuilder
    private var buttonList: some View {
        if let device = controllerService.state.selectedDevice {
            if device.buttons.isEmpty {
                ContentUnavailableView(
                    "未发现可识别按键",
                    systemImage: "questionmark.square.dashed",
                    description: Text("该设备没有通过 GameController 提供标准按钮。")
                )
                .padding()
            } else {
                List(selection: selectedButtonBinding) {
                    Section("按键") {
                        ForEach(device.buttons.sorted()) { button in
                            ButtonListRow(
                                button: button,
                                isPressed: controllerService.state.isPressed(
                                    button.id,
                                    on: device.id
                                )
                            )
                            .tag(Optional(button.id))
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        } else {
            ContentUnavailableView(
                "选择一个设备",
                systemImage: "gamecontroller",
                description: Text("连接或选择手柄后将在这里显示按键。")
            )
            .padding()
        }
    }

    @ViewBuilder
    private var mappingDetail: some View {
        if let button = controllerService.state.selectedButton,
           let device = controllerService.state.selectedDevice {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("按键映射")
                            .font(.title2.weight(.bold))
                        Text(device.name)
                            .foregroundStyle(.secondary)
                    }

                    GroupBox("当前按键") {
                        HStack(spacing: 12) {
                            Image(systemName: controllerService.state.isPressed(button.id, on: device.id) ? "circle.inset.filled" : "circle")
                                .font(.title2)
                                .foregroundStyle(controllerService.state.isPressed(button.id, on: device.id) ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(button.name)
                                    .font(.title3.weight(.semibold))
                                Text(controllerService.state.isPressed(button.id, on: device.id) ? "正在按下" : "当前松开")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }

                    GroupBox("键盘映射") {
                        LabeledContent("映射到") {
                            Text(button.name)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Text("这是映射设置的界面占位。后续版本会在这里选择键盘按键；当前不会保存配置或发送键盘事件。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(28)
                .frame(maxWidth: 640, alignment: .leading)
            }
        } else {
            ContentUnavailableView(
                "选择一个按键",
                systemImage: "keyboard",
                description: Text("从左侧按键列表选择后，可在这里查看映射设置。")
            )
        }
    }

    private var selectedDeviceBinding: Binding<ControllerDevice.ID?> {
        Binding(
            get: { controllerService.state.selectedDeviceID },
            set: { id in
                if let id {
                    controllerService.selectDevice(id)
                }
            }
        )
    }

    private var selectedButtonBinding: Binding<ControllerButton.ID?> {
        Binding(
            get: { controllerService.state.selectedButtonID },
            set: { id in
                if let id {
                    controllerService.selectButton(id)
                }
            }
        )
    }
}

private struct ButtonListRow: View {
    let button: ControllerButton
    let isPressed: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isPressed ? "circle.inset.filled" : "circle")
                .foregroundStyle(isPressed ? Color.accentColor : Color.secondary)
                .animation(.easeOut(duration: 0.08), value: isPressed)
            Text(button.name)
            Spacer()
            Text(isPressed ? "按下" : "松开")
                .font(.caption.weight(isPressed ? .semibold : .regular))
                .foregroundStyle(isPressed ? Color.accentColor : Color.secondary)
        }
        .accessibilityValue(isPressed ? "按下" : "松开")
    }
}

#Preview("Connected controllers") {
    let service = ControllerService(state: .preview, autoStart: false)
    ContentView(controllerService: service)
        .environmentObject(AppState(defaults: .standard, autoPresent: false))
        .environmentObject(PermissionsManager())
        .frame(width: 900, height: 640)
}

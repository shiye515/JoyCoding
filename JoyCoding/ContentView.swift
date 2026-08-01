import SwiftUI

struct ContentView: View {
    @ObservedObject var controllerService: ControllerService
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var permissionsManager: PermissionsManager

    var body: some View {
        VStack(spacing: 0) {
            deviceSection
            Divider()
            buttonSection
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

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("已连接的设备", systemImage: "gamecontroller")
                    .font(.headline)
                Spacer()
                Text("\(controllerService.state.devices.count) 台")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if controllerService.state.devices.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "cable.connector.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("还没有连接游戏手柄")
                            .font(.subheadline.weight(.medium))
                        Text("请通过 USB 或蓝牙连接手柄，设备会自动出现在这里。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                .padding(.horizontal, 4)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(controllerService.state.devices) { device in
                            DeviceCard(
                                device: device,
                                isSelected: device.id == controllerService.state.selectedDeviceID
                            ) {
                                controllerService.selectDevice(device.id)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(20)
        .frame(minHeight: 142, alignment: .top)
    }

    @ViewBuilder
    private var buttonSection: some View {
        if let device = controllerService.state.selectedDevice {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("按键")
                            .font(.title3.weight(.semibold))
                        Text(device.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("按下手柄按键进行测试", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if device.buttons.isEmpty {
                    ContentUnavailableView(
                        "未发现可识别按键",
                        systemImage: "questionmark.square.dashed",
                        description: Text("该设备没有通过 GameController 提供标准按钮。")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(device.buttons.sorted()) { button in
                                ButtonStateCard(
                                    button: button,
                                    isPressed: controllerService.state.isPressed(
                                        button.id,
                                        on: device.id
                                    )
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ContentUnavailableView(
                "等待连接手柄",
                systemImage: "gamecontroller",
                description: Text("连接后，可在这里实时查看每个按键的状态。")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct DeviceCard: View {
    let device: ControllerDevice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(device.category)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 210, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(device.name)\(isSelected ? "，已选择" : "")")
    }
}

private struct ButtonStateCard: View {
    let button: ControllerButton
    let isPressed: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isPressed ? "circle.inset.filled" : "circle")
                .font(.title3)
            Text(button.name)
                .font(.body.weight(isPressed ? .semibold : .regular))
            Spacer()
            Text(isPressed ? "按下" : "松开")
                .font(.caption.weight(.medium))
                .foregroundStyle(isPressed ? Color.white.opacity(0.9) : Color.secondary)
        }
        .foregroundStyle(isPressed ? Color.white : Color.primary)
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isPressed ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isPressed ? Color.accentColor : Color.secondary.opacity(0.16))
        }
        .animation(.easeOut(duration: 0.08), value: isPressed)
        .accessibilityValue(isPressed ? "按下" : "松开")
    }
}

#Preview("Connected controllers") {
    let service = ControllerService(state: .preview, autoStart: false)
    ContentView(controllerService: service)
        .environmentObject(AppState(defaults: .standard, autoPresent: false))
        .environmentObject(PermissionsManager())
        .frame(width: 820, height: 640)
}

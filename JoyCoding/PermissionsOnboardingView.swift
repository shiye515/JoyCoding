import SwiftUI

struct PermissionsOnboardingView: View {
    @EnvironmentObject private var permissions: PermissionsManager

    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var step: PermissionsOnboardingStep = .welcome

    var body: some View {
        VStack(spacing: 20) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            footer
        }
        .padding(24)
        .frame(width: 500, height: 520)
        .interactiveDismissDisabled()
        .onAppear { permissions.startPolling() }
        .onDisappear { permissions.stopPolling() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: headerIcon)
                .font(.system(size: 42))
                .foregroundStyle(Color.accentColor)
            Text(headerTitle)
                .font(.title2.bold())
            HStack(spacing: 6) {
                ForEach(PermissionsOnboardingStep.allCases, id: \.rawValue) { item in
                    Circle()
                        .fill(item == step ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 7, height: 7)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            VStack(alignment: .leading, spacing: 16) {
                Text("欢迎使用 JoyCoding")
                    .font(.title3.weight(.semibold))
                Text("JoyCoding 将逐步获得完整手柄读取和后续发送键盘按键所需的权限。系统授权只会在你点击按钮后请求。")
                    .foregroundStyle(.secondary)
                permissionSummary(
                    icon: "waveform.path",
                    title: "输入监控",
                    detail: "用于未来支持原始 HID 和部分特殊手柄按键；标准 GameController 手柄无需此权限也能显示。"
                )
                permissionSummary(
                    icon: "accessibility",
                    title: "辅助功能",
                    detail: "用于后续把手柄操作转换为系统级键盘事件；当前按键测试不会发送键盘事件。"
                )
            }
        case .inputMonitoring:
            permissionStep(
                title: "允许输入监控",
                explanation: "输入监控将用于未来读取标准 GameController 未暴露的原始 HID 与特殊按键。你可以暂时跳过，标准手柄按键测试仍然可用。",
                state: permissions.inputMonitoring,
                requestTitle: "请求输入监控权限",
                request: permissions.requestInputMonitoring,
                openSettings: permissions.openInputMonitoringSettings
            )
        case .accessibility:
            permissionStep(
                title: "允许辅助功能",
                explanation: "辅助功能允许 JoyCoding 在后续映射阶段代表你发送键盘事件。此初始化版本不会发送任何键盘事件。",
                state: permissions.accessibility,
                requestTitle: "请求辅助功能权限",
                request: permissions.requestAccessibility,
                openSettings: permissions.openAccessibilitySettings
            )
        case .done:
            VStack(alignment: .leading, spacing: 16) {
                Label("设置已完成", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green)
                permissionResult(title: "输入监控", state: permissions.inputMonitoring)
                permissionResult(title: "辅助功能", state: permissions.accessibility)
                Text("未授予的权限不会阻塞标准手柄按键测试。以后可从菜单栏的“权限设置…”再次打开本向导。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func permissionSummary(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func permissionStep(
        title: String,
        explanation: String,
        state: PermissionState,
        requestTitle: String,
        request: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title).font(.title3.weight(.semibold))
                Spacer()
                PermissionStatusBadge(state: state)
            }
            Text(explanation)
                .foregroundStyle(.secondary)
            if state != .granted {
                Button(requestTitle, action: request)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("打开系统设置", action: openSettings)
            }
        }
    }

    private func permissionResult(title: String, state: PermissionState) -> some View {
        HStack {
            Text(title)
            Spacer()
            PermissionStatusBadge(state: state)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private var footer: some View {
        HStack {
            if step != .done {
                Button("暂时跳过") { onSkip() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let previous = step.previous, step != .done {
                Button("返回") { step = previous }
            }
            if step == .done {
                Button("开始使用", action: onComplete)
                    .buttonStyle(.borderedProminent)
            } else if let next = step.next {
                Button("继续") { step = next }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var headerTitle: String {
        switch step {
        case .welcome: "首次设置"
        case .inputMonitoring: "输入监控"
        case .accessibility: "辅助功能"
        case .done: "准备就绪"
        }
    }

    private var headerIcon: String {
        switch step {
        case .welcome: "gamecontroller.fill"
        case .inputMonitoring: "waveform.path"
        case .accessibility: "accessibility"
        case .done: "checkmark.circle.fill"
        }
    }
}

private struct PermissionStatusBadge: View {
    let state: PermissionState

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var title: String {
        switch state {
        case .granted: "已授权"
        case .denied: "已拒绝"
        case .notDetermined: "待设置"
        }
    }

    private var icon: String {
        switch state {
        case .granted: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .notDetermined: "questionmark.circle"
        }
    }

    private var color: Color {
        switch state {
        case .granted: .green
        case .denied: .red
        case .notDetermined: .orange
        }
    }
}

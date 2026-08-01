import AppKit
import ApplicationServices
import Combine
import Foundation
import IOKit.hid

enum PermissionState: Equatable, Sendable {
    case granted
    case denied
    case notDetermined
}

struct PermissionClient {
    var accessibilityState: () -> PermissionState
    var inputMonitoringState: () -> PermissionState
    var requestAccessibility: () -> Void
    var requestInputMonitoring: () -> Void
    var openAccessibilitySettings: () -> Void
    var openInputMonitoringSettings: () -> Void

    static let live = PermissionClient(
        accessibilityState: {
            AXIsProcessTrusted() ? .granted : .notDetermined
        },
        inputMonitoringState: {
            switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
            case kIOHIDAccessTypeGranted: .granted
            case kIOHIDAccessTypeDenied: .denied
            default: .notDetermined
            }
        },
        requestAccessibility: {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        },
        requestInputMonitoring: {
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        },
        openAccessibilitySettings: {
            PermissionClient.openSettings("com.apple.preference.security?Privacy_Accessibility")
        },
        openInputMonitoringSettings: {
            PermissionClient.openSettings("com.apple.preference.security?Privacy_ListenEvent")
        }
    )

    private static func openSettings(_ path: String) {
        guard let url = URL(string: "x-apple.systempreferences:\(path)") else { return }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var accessibility: PermissionState = .notDetermined
    @Published private(set) var inputMonitoring: PermissionState = .notDetermined

    private let client: PermissionClient
    private var pollTimer: Timer?
    private var pollingClients = 0

    var isPolling: Bool { pollTimer != nil }
    var activePollingClientCount: Int { pollingClients }

    convenience init() {
        self.init(client: .live)
    }

    init(client: PermissionClient) {
        self.client = client
        refresh()
    }

    deinit {
        pollTimer?.invalidate()
    }

    func refresh() {
        accessibility = client.accessibilityState()
        inputMonitoring = client.inputMonitoringState()
    }

    func startPolling() {
        pollingClients += 1
        guard pollTimer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stopPolling() {
        pollingClients = max(0, pollingClients - 1)
        guard pollingClients == 0 else { return }
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func requestAccessibility() {
        client.requestAccessibility()
        client.openAccessibilitySettings()
    }

    func requestInputMonitoring() {
        client.requestInputMonitoring()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [client] in
            client.openInputMonitoringSettings()
        }
    }

    func openAccessibilitySettings() {
        client.openAccessibilitySettings()
    }

    func openInputMonitoringSettings() {
        client.openInputMonitoringSettings()
    }
}

enum PermissionsOnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case inputMonitoring
    case accessibility
    case done

    var next: PermissionsOnboardingStep? {
        PermissionsOnboardingStep(rawValue: rawValue + 1)
    }

    var previous: PermissionsOnboardingStep? {
        guard rawValue > 0 else { return nil }
        return PermissionsOnboardingStep(rawValue: rawValue - 1)
    }
}

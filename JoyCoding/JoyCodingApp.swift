import AppKit
import SwiftUI

@main
struct JoyCodingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var mappingStore: UserDefaultsKeyboardMappingStore
    @StateObject private var controllerService: ControllerService
    @StateObject private var permissionsManager = PermissionsManager()

    init() {
        let store = UserDefaultsKeyboardMappingStore()
        _mappingStore = StateObject(wrappedValue: store)
        _controllerService = StateObject(wrappedValue: ControllerService(state: ControllerState(), mappingStore: store))
    }

    var body: some Scene {
        Window("JoyCoding", id: AppWindowID.main) {
            ContentView(controllerService: controllerService)
                .environmentObject(appState)
                .environmentObject(permissionsManager)
                .frame(minWidth: 680, minHeight: 520)
        }
        .defaultSize(width: 820, height: 640)
        .windowResizability(.contentMinSize)

        MenuBarExtra("JoyCoding", systemImage: "gamecontroller.fill") {
            MenuBarContent()
                .environmentObject(appState)
        }
    }
}

enum AppWindowID {
    static let main = "main"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Button("打开 JoyCoding") {
            openMainWindow()
        }

        Button("权限设置…") {
            appState.presentPermissions()
            openMainWindow()
        }

        Divider()

        Button("退出 JoyCoding") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func openMainWindow() {
        openWindow(id: AppWindowID.main)
        NSApp.activate(ignoringOtherApps: true)
    }
}

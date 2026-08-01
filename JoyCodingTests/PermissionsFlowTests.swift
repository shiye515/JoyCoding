import XCTest
@testable import JoyCoding

final class PermissionsFlowTests: XCTestCase {
    func testOnboardingStepOrder() {
        XCTAssertEqual(PermissionsOnboardingStep.welcome.next, .inputMonitoring)
        XCTAssertEqual(PermissionsOnboardingStep.inputMonitoring.next, .accessibility)
        XCTAssertEqual(PermissionsOnboardingStep.accessibility.next, .done)
        XCTAssertNil(PermissionsOnboardingStep.done.next)
        XCTAssertNil(PermissionsOnboardingStep.welcome.previous)
        XCTAssertEqual(PermissionsOnboardingStep.accessibility.previous, .inputMonitoring)
    }

    func testAppStateAutoPresentsOnlyBeforeOnboardingWasHandled() {
        let defaults = makeDefaults()
        let firstLaunch = AppState(defaults: defaults)
        XCTAssertTrue(firstLaunch.isPermissionsPresented)

        firstLaunch.finishPermissionsOnboarding()
        XCTAssertFalse(firstLaunch.isPermissionsPresented)

        let laterLaunch = AppState(defaults: defaults)
        XCTAssertFalse(laterLaunch.isPermissionsPresented)
    }

    func testPermissionsCanBePresentedAgainWithoutDuplicatingState() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: AppState.onboardingPresentedKey)
        let state = AppState(defaults: defaults)

        state.presentPermissions()
        state.presentPermissions()

        XCTAssertTrue(state.isPermissionsPresented)
    }

    func testManagerDoesNotRequestPermissionsDuringInitializationOrRefresh() {
        let spy = PermissionSpy()
        let manager = PermissionsManager(client: spy.client)

        manager.refresh()

        XCTAssertEqual(spy.accessibilityRequests, 0)
        XCTAssertEqual(spy.inputMonitoringRequests, 0)
        XCTAssertEqual(spy.settingsOpens, 0)
    }

    func testPermissionRequestOnlyRunsAfterExplicitAction() {
        let spy = PermissionSpy()
        let manager = PermissionsManager(client: spy.client)

        manager.requestAccessibility()

        XCTAssertEqual(spy.accessibilityRequests, 1)
        XCTAssertEqual(spy.inputMonitoringRequests, 0)
        XCTAssertEqual(spy.settingsOpens, 1)
    }

    func testPollingIsReferenceCountedAndStopsAfterLastClient() {
        let spy = PermissionSpy()
        let manager = PermissionsManager(client: spy.client)

        manager.startPolling()
        manager.startPolling()
        XCTAssertTrue(manager.isPolling)
        XCTAssertEqual(manager.activePollingClientCount, 2)

        manager.stopPolling()
        XCTAssertTrue(manager.isPolling)
        XCTAssertEqual(manager.activePollingClientCount, 1)

        manager.stopPolling()
        XCTAssertFalse(manager.isPolling)
        XCTAssertEqual(manager.activePollingClientCount, 0)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "JoyCodingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class PermissionSpy {
    var accessibilityRequests = 0
    var inputMonitoringRequests = 0
    var settingsOpens = 0

    var client: PermissionClient {
        PermissionClient(
            accessibilityState: { .notDetermined },
            inputMonitoringState: { .notDetermined },
            requestAccessibility: { [weak self] in self?.accessibilityRequests += 1 },
            requestInputMonitoring: { [weak self] in self?.inputMonitoringRequests += 1 },
            openAccessibilitySettings: { [weak self] in self?.settingsOpens += 1 },
            openInputMonitoringSettings: { [weak self] in self?.settingsOpens += 1 }
        )
    }
}

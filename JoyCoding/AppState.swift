import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    static let onboardingPresentedKey = "hasPresentedPermissionsOnboarding"

    @Published var isPermissionsPresented: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, autoPresent: Bool = true) {
        self.defaults = defaults
        isPermissionsPresented = autoPresent && !defaults.bool(forKey: Self.onboardingPresentedKey)
    }

    func presentPermissions() {
        isPermissionsPresented = true
    }

    func finishPermissionsOnboarding() {
        defaults.set(true, forKey: Self.onboardingPresentedKey)
        isPermissionsPresented = false
    }
}

import UIKit

final class AppRouter {
    static let screenshotScreen: String? = UserDefaults.standard.string(forKey: "screenshot")

    static func rootViewController() -> UIViewController {
        // Minimal scaffold: route to home. Onboarding decision can be added later.
        let onboardingDone = UserDefaults.standard.bool(forKey: "onboardingComplete")
        if onboardingDone {
            return HomeViewController()
        }
        // For scaffold, show home.
        return HomeViewController()
    }
}

import UIKit

enum Haptics {
    static func light() {
        guard SettingsStore.shared.haptics else { return }
        if #available(iOS 10.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
}

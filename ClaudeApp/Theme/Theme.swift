import UIKit

public enum ThemeMode {
    case light
    case dark
    case system
}

public struct Theme {
    public typealias Mode = ThemeMode
    public let background: UIColor
    public let surface: UIColor
    public let sidebarBackground: UIColor
    public let textPrimary: UIColor
    public let textSecondary: UIColor
    public let accent: UIColor
    public let userBubble: UIColor
    public let border: UIColor

    public static let didChange = Notification.Name("Theme.didChange")

    private static var currentMode: ThemeMode = .system

    public static var current: Theme {
        switch currentMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            if isSystemDark {
                return .dark
            }
            return .light
        }
    }

    public static func setMode(_ mode: ThemeMode) {
        currentMode = mode
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    private static var isSystemDark: Bool {
        if #available(iOS 13.0, *) {
            let style = UIApplication.shared.keyWindow?.traitCollection.userInterfaceStyle ?? .unspecified
            return style == .dark
        }
        return false
    }

    public static let light = Theme(
        background: UIColor(hex: "#F5F4EE"),
        surface: UIColor(hex: "#FFFFFF"),
        sidebarBackground: UIColor(hex: "#F0EEE6"),
        textPrimary: UIColor(hex: "#141413"),
        textSecondary: UIColor(hex: "#6B6A65"),
        accent: UIColor(hex: "#D97757"),
        userBubble: UIColor(hex: "#EFEDE5"),
        border: UIColor(hex: "#E5E3DC")
    )

    public static let dark = Theme(
        background: UIColor(hex: "#262624"),
        surface: UIColor(hex: "#30302E"),
        sidebarBackground: UIColor(hex: "#1F1E1D"),
        textPrimary: UIColor(hex: "#FAF9F5"),
        textSecondary: UIColor(hex: "#A8A7A2"),
        accent: UIColor(hex: "#D97757"),
        userBubble: UIColor(hex: "#141413"),
        border: UIColor(hex: "#3A3A38")
    )
}

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var rgb: UInt32 = 0
        Scanner(string: s).scanHexInt32(&rgb)
        let r, g, b, a: CGFloat
        switch s.count {
        case 6:
            r = CGFloat((rgb >> 16) & 0xFF) / 255.0
            g = CGFloat((rgb >> 8) & 0xFF) / 255.0
            b = CGFloat(rgb & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = CGFloat((rgb >> 24) & 0xFF) / 255.0
            g = CGFloat((rgb >> 16) & 0xFF) / 255.0
            b = CGFloat((rgb >> 8) & 0xFF) / 255.0
            a = CGFloat(rgb & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

import UIKit

public enum ThemeMode: String {
    case light
    case dark
    case system
}

/// アプリ全体の配色。iOS 12 にはシステムのダークモードがないため、アプリ内で切り替える。
/// 画面は `Theme.didChange` を監視して `Theme.current` から色を再適用すること。
public struct Theme {
    public typealias Mode = ThemeMode

    public let isDark: Bool
    /// メイン背景 (チャット/ホーム)
    public let background: UIColor
    /// カード・シート・入力欄などの面
    public let surface: UIColor
    /// サイドバー(ドロワー)背景
    public let sidebarBackground: UIColor
    /// サイドバーの選択行
    public let sidebarSelected: UIColor
    public let textPrimary: UIColor
    public let textSecondary: UIColor
    public let textTertiary: UIColor
    /// Claude クレイ (オレンジ)
    public let accent: UIColor
    /// アクセント上の文字色
    public let onAccent: UIColor
    /// ユーザーメッセージのバブル
    public let userBubble: UIColor
    /// 入力欄(コンポーザー)背景
    public let composerBackground: UIColor
    public let border: UIColor
    public let separator: UIColor
    /// コードブロック背景
    public let codeBackground: UIColor
    /// インラインコード背景
    public let inlineCodeBackground: UIColor
    /// 思考(thinking)表示の背景
    public let thinkingBackground: UIColor
    /// 送信ボタン (有効時)
    public let sendButton: UIColor
    public let sendButtonDisabled: UIColor
    public let destructive: UIColor
    public let success: UIColor
    /// モーダル背後の暗幕
    public let dimming: UIColor

    public static let didChange = Notification.Name("Theme.didChange")

    private static var currentMode: ThemeMode = {
        let raw = UserDefaults.standard.string(forKey: "themeMode") ?? "system"
        return ThemeMode(rawValue: raw) ?? .system
    }()

    public static var mode: ThemeMode { return currentMode }

    public static var current: Theme {
        if let forced = forcedDark { return forced ? .dark : .light }
        switch currentMode {
        case .light: return .light
        case .dark: return .dark
        case .system: return isSystemDark ? .dark : .light
        }
    }

    /// スクリーンショットモード等で強制する場合に使用 (nil = 設定に従う)
    public static var forcedDark: Bool?

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

    public var statusBarStyle: UIStatusBarStyle { return isDark ? .lightContent : .default }
    public var keyboardAppearance: UIKeyboardAppearance { return isDark ? .dark : .light }

    public static let light = Theme(
        isDark: false,
        background: UIColor(hex: "#FAF9F5"),
        surface: UIColor(hex: "#FFFFFF"),
        sidebarBackground: UIColor(hex: "#F0EFEC"),
        sidebarSelected: UIColor(hex: "#E7E6E1"),
        textPrimary: UIColor(hex: "#141413"),
        textSecondary: UIColor(hex: "#616161"),
        textTertiary: UIColor(hex: "#949494"),
        accent: UIColor(hex: "#D97757"),
        onAccent: UIColor(hex: "#FFFFFF"),
        userBubble: UIColor(hex: "#F0EFEC"),
        composerBackground: UIColor(hex: "#FFFFFF"),
        border: UIColor(hex: "#E7E6E1"),
        separator: UIColor(hex: "#E7E6E1"),
        codeBackground: UIColor(hex: "#F5F5F5"),
        inlineCodeBackground: UIColor(hex: "#F0EFEC"),
        thinkingBackground: UIColor(hex: "#F3F3F0"),
        sendButton: UIColor(hex: "#C6613F"),
        sendButtonDisabled: UIColor(hex: "#E7C2B4"),
        destructive: UIColor(hex: "#D93025"),
        success: UIColor(hex: "#1D873B"),
        dimming: UIColor(white: 0, alpha: 0.35)
    )

    public static let dark = Theme(
        isDark: true,
        background: UIColor(hex: "#262624"),
        surface: UIColor(hex: "#30302E"),
        sidebarBackground: UIColor(hex: "#1F1E1D"),
        sidebarSelected: UIColor(hex: "#141413"),
        textPrimary: UIColor(hex: "#FAF9F5"),
        textSecondary: UIColor(hex: "#ABABAB"),
        textTertiary: UIColor(hex: "#7B7974"),
        accent: UIColor(hex: "#D97757"),
        onAccent: UIColor(hex: "#FFFFFF"),
        userBubble: UIColor(hex: "#141413"),
        composerBackground: UIColor(hex: "#30302E"),
        border: UIColor(hex: "#424242"),
        separator: UIColor(hex: "#3A3A38"),
        codeBackground: UIColor(hex: "#1F1E1D"),
        inlineCodeBackground: UIColor(hex: "#141413"),
        thinkingBackground: UIColor(hex: "#30302E"),
        sendButton: UIColor(hex: "#C6613F"),
        sendButtonDisabled: UIColor(hex: "#5A3F35"),
        destructive: UIColor(hex: "#DC362E"),
        success: UIColor(hex: "#6DD58C"),
        dimming: UIColor(white: 0, alpha: 0.55)
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

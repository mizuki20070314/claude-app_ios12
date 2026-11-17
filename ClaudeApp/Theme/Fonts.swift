import UIKit

/// フォント定義。iOS 12 には同梱フォントを使わず、システム搭載フォントで近い雰囲気を再現する。
enum Fonts {
    static let serifName = "Georgia"
    static let monoName = "Menlo"

    /// 見出し・挨拶・アシスタント本文向けのセリフ体
    static func serif(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let name: String
        switch weight {
        case .semibold, .bold, .heavy, .black: name = "Georgia-Bold"
        default: name = serifName
        }
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }

    /// UI 全般のサンセリフ体 (システムフォント)
    static func sans(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    /// コード用等幅フォント
    static func mono(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let name = (weight == .bold || weight == .semibold) ? "Menlo-Bold" : monoName
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }
}

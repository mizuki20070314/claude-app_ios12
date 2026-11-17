import UIKit

/// Visual style for Markdown rendering. Colors are injected (no Theme dependency).
struct MarkdownStyle {
    var baseFont: UIFont
    var textColor: UIColor
    var secondaryTextColor: UIColor
    var linkColor: UIColor
    var codeFont: UIFont
    var inlineCodeTextColor: UIColor
    var inlineCodeBackground: UIColor
    var codeBlockBackground: UIColor
    var codeBlockTextColor: UIColor
    var quoteBarColor: UIColor
    var lineSpacing: CGFloat
    var paragraphSpacing: CGFloat

    func headingFont(level: Int) -> UIFont {
        let size: CGFloat
        switch level {
        case 1: size = 22
        case 2: size = 20
        case 3: size = 18
        default: size = baseFont.pointSize
        }
        return UIFont.systemFont(ofSize: size, weight: .semibold)
    }

    static func standard(textColor: UIColor,
                         secondary: UIColor,
                         accent: UIColor,
                         codeBackground: UIColor,
                         isDark: Bool) -> MarkdownStyle {
        let baseFont = UIFont.systemFont(ofSize: 16)
        let codeFont = UIFont(name: "Menlo", size: 14) ?? UIFont.systemFont(ofSize: 14)
        let inlineCodeText: UIColor = isDark
            ? UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
            : UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        return MarkdownStyle(
            baseFont: baseFont,
            textColor: textColor,
            secondaryTextColor: secondary,
            linkColor: accent,
            codeFont: codeFont,
            inlineCodeTextColor: inlineCodeText,
            inlineCodeBackground: codeBackground,
            codeBlockBackground: codeBackground,
            codeBlockTextColor: textColor,
            quoteBarColor: secondary,
            lineSpacing: 4,
            paragraphSpacing: 8
        )
    }
}

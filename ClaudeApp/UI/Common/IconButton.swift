import UIKit

final class IconButton: UIButton {
    var icon: IconName
    private let iconSize: CGFloat

    init(icon: IconName, size: CGFloat = 22, tint: UIColor? = nil) {
        self.icon = icon
        self.iconSize = size
        super.init(frame: .zero)
        if let tint = tint { self.tintColor = tint }
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 44).isActive = true
        heightAnchor.constraint(equalToConstant: 44).isActive = true
        contentHorizontalAlignment = .center
        contentVerticalAlignment = .center
        refreshColor()
    }

    required init?(coder: NSCoder) {
        self.icon = .more
        self.iconSize = 22
        super.init(coder: coder)
    }

    func refreshColor() {
        let color = tintColor ?? Theme.current.textPrimary
        setImage(Icons.image(icon, size: iconSize, color: color), for: .normal)
        setImage(Icons.image(icon, size: iconSize, color: color), for: .highlighted)
    }
}

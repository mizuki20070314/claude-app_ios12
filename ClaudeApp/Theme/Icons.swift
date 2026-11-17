import UIKit

public enum IconName {
    case menu, newChat, plus, send, stop, mic, search, close, chevronRight, chevronDown, chevronLeft, copy, retry, thumbsUp, thumbsDown, star, starFill, settings, trash, pencil, share, chat, project, artifact, image, camera, file, globe, thinking, check, more, sparkle, sidebar, back, info, key, moon, sun, logout, folder, code, eye
}

private enum IconRenderMode { case fill, stroke }

public enum Icons {
    private static var cache: [String: UIImage] = [:]
    private static let lock = NSLock()

    public static func image(_ name: IconName, size: CGFloat = 20, color: UIColor) -> UIImage {
        let key = "\(name)-\(size)-\(color.description)"
        lock.lock()
        if let cached = cache[key] { lock.unlock(); return cached }
        lock.unlock()
        let img = render(name, size: size, color: color)
        lock.lock()
        cache[key] = img
        lock.unlock()
        return img
    }

    private static func render(_ name: IconName, size: CGFloat, color: UIColor) -> UIImage {
        let (path, mode, customWidth) = buildPath(name, size: size)
        let scale = UIScreen.main.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        let img = renderer.image { ctx in
            color.setFill()
            color.setStroke()
            switch mode {
            case .fill:
                path.fill()
            case .stroke:
                if customWidth > 0 {
                    path.lineWidth = max(1.0, customWidth)
                } else {
                    path.lineWidth = max(1.0, size * 0.08)
                }
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
        }
        return img.withRenderingMode(.alwaysOriginal)
    }

    private static func buildPath(_ name: IconName, size: CGFloat) -> (UIBezierPath, IconRenderMode, CGFloat) {
        let k = size / 24.0
        let path = UIBezierPath()
        var mode: IconRenderMode = .stroke
        var customWidth: CGFloat = 0
        switch name {
        case .menu:
            for y in [6, 12, 18] as [CGFloat] {
                path.move(to: CGPoint(x: 4, y: y))
                path.addLine(to: CGPoint(x: 20, y: y))
            }
        case .newChat:
            // pencil
            path.move(to: CGPoint(x: 4, y: 20))
            path.addLine(to: CGPoint(x: 6, y: 14))
            path.addLine(to: CGPoint(x: 16, y: 4))
            path.addLine(to: CGPoint(x: 20, y: 8))
            path.addLine(to: CGPoint(x: 10, y: 18))
            path.close()
            mode = .fill
        case .plus:
            path.move(to: CGPoint(x: 12, y: 4)); path.addLine(to: CGPoint(x: 12, y: 20))
            path.move(to: CGPoint(x: 4, y: 12)); path.addLine(to: CGPoint(x: 20, y: 12))
        case .send:
            path.move(to: CGPoint(x: 12, y: 4))
            path.addLine(to: CGPoint(x: 20, y: 14))
            path.addLine(to: CGPoint(x: 16, y: 14))
            path.addLine(to: CGPoint(x: 16, y: 20))
            path.addLine(to: CGPoint(x: 8, y: 20))
            path.addLine(to: CGPoint(x: 8, y: 14))
            path.addLine(to: CGPoint(x: 4, y: 14))
            path.close()
            mode = .fill
        case .stop:
            path.append(UIBezierPath(roundedRect: CGRect(x: 6, y: 6, width: 12, height: 12), cornerRadius: 3))
            mode = .fill
        case .mic:
            path.append(UIBezierPath(roundedRect: CGRect(x: 9, y: 3, width: 6, height: 11), cornerRadius: 3))
            path.move(to: CGPoint(x: 6, y: 11))
            path.addQuadCurve(to: CGPoint(x: 18, y: 11), controlPoint: CGPoint(x: 12, y: 18))
            path.move(to: CGPoint(x: 12, y: 17)); path.addLine(to: CGPoint(x: 12, y: 21))
            path.move(to: CGPoint(x: 9, y: 21)); path.addLine(to: CGPoint(x: 15, y: 21))
        case .search:
            path.append(UIBezierPath(ovalIn: CGRect(x: 4, y: 4, width: 12, height: 12)))
            path.move(to: CGPoint(x: 14, y: 14)); path.addLine(to: CGPoint(x: 20, y: 20))
        case .close:
            path.move(to: CGPoint(x: 6, y: 6)); path.addLine(to: CGPoint(x: 18, y: 18))
            path.move(to: CGPoint(x: 18, y: 6)); path.addLine(to: CGPoint(x: 6, y: 18))
        case .chevronRight:
            path.move(to: CGPoint(x: 9, y: 6)); path.addLine(to: CGPoint(x: 15, y: 12)); path.addLine(to: CGPoint(x: 9, y: 18))
        case .chevronDown:
            path.move(to: CGPoint(x: 6, y: 9)); path.addLine(to: CGPoint(x: 12, y: 15)); path.addLine(to: CGPoint(x: 18, y: 9))
        case .chevronLeft, .back:
            path.move(to: CGPoint(x: 15, y: 6)); path.addLine(to: CGPoint(x: 9, y: 12)); path.addLine(to: CGPoint(x: 15, y: 18))
        case .copy:
            path.append(UIBezierPath(roundedRect: CGRect(x: 8, y: 4, width: 12, height: 14), cornerRadius: 2))
            path.append(UIBezierPath(roundedRect: CGRect(x: 4, y: 8, width: 12, height: 14), cornerRadius: 2))
        case .retry:
            path.addArc(withCenter: CGPoint(x: 12, y: 12), radius: 8, startAngle: -.pi / 2, endAngle: .pi, clockwise: true)
            path.move(to: CGPoint(x: 4, y: 12)); path.addLine(to: CGPoint(x: 4, y: 16)); path.addLine(to: CGPoint(x: 8, y: 16))
        case .thumbsUp, .thumbsDown:
            // cuff: rounded rectangle on the left
            path.append(UIBezierPath(roundedRect: CGRect(x: 3, y: 10, width: 4, height: 11), cornerRadius: 1.5))
            // hand shape
            path.move(to: CGPoint(x: 7, y: 10))
            path.addQuadCurve(to: CGPoint(x: 12, y: 3), controlPoint: CGPoint(x: 7, y: 3))
            path.addQuadCurve(to: CGPoint(x: 19, y: 10), controlPoint: CGPoint(x: 17, y: 3))
            path.addLine(to: CGPoint(x: 19, y: 19))
            path.addLine(to: CGPoint(x: 17, y: 21))
            path.addLine(to: CGPoint(x: 7, y: 21))
            if name == .thumbsDown {
                var t = CGAffineTransform(translationX: 12, y: 12)
                t = t.rotated(by: .pi)
                t = t.translatedBy(x: -12, y: -12)
                path.apply(t)
            }
            mode = .stroke
            customWidth = 1.6 * k
        case .star, .starFill:
            let cx: CGFloat = 12, cy: CGFloat = 12, outer: CGFloat = 10, inner: CGFloat = 4
            var first = true
            for i in 0..<10 {
                let r = (i % 2 == 0) ? outer : inner
                let angle = (CGFloat(i) / 10.0) * 2 * .pi - .pi / 2
                let pt = CGPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r)
                if first { path.move(to: pt); first = false } else { path.addLine(to: pt) }
            }
            path.close()
            mode = .fill
        case .settings:
            // gear: 8 teeth around outer ring with center hole
            let center = CGPoint(x: 12, y: 12)
            let outerR: CGFloat = 10
            let innerR: CGFloat = 6
            let holeR: CGFloat = 3.5
            let toothW: CGFloat = 3.2
            // teeth
            for i in 0..<8 {
                let angle = CGFloat(i) / 8.0 * 2 * .pi
                let tx = center.x + cos(angle) * (outerR - 0.5)
                let ty = center.y + sin(angle) * (outerR - 0.5)
                let rect = CGRect(x: tx - toothW/2, y: ty - toothW/2, width: toothW, height: toothW)
                // rotate tooth rect
                var t = CGAffineTransform(translationX: tx, y: ty).rotated(by: angle).translatedBy(x: -tx, y: -ty)
                let tooth = UIBezierPath(roundedRect: rect, cornerRadius: 0.8)
                tooth.apply(t)
                path.append(tooth)
            }
            // outer ring
            path.append(UIBezierPath(ovalIn: CGRect(x: center.x - outerR + 1.5, y: center.y - outerR + 1.5, width: (outerR-1.5)*2, height: (outerR-1.5)*2)))
            // hole (even-odd)
            path.append(UIBezierPath(ovalIn: CGRect(x: center.x - holeR, y: center.y - holeR, width: holeR*2, height: holeR*2)))
            path.usesEvenOddFillRule = true
            mode = .fill
        case .trash:
            path.move(to: CGPoint(x: 4, y: 6)); path.addLine(to: CGPoint(x: 20, y: 6))
            path.move(to: CGPoint(x: 9, y: 6)); path.addLine(to: CGPoint(x: 9, y: 4)); path.addLine(to: CGPoint(x: 15, y: 4)); path.addLine(to: CGPoint(x: 15, y: 6))
            path.move(to: CGPoint(x: 6, y: 6)); path.addLine(to: CGPoint(x: 7, y: 20)); path.addLine(to: CGPoint(x: 17, y: 20)); path.addLine(to: CGPoint(x: 18, y: 6))
        case .pencil:
            path.move(to: CGPoint(x: 4, y: 20)); path.addLine(to: CGPoint(x: 6, y: 14)); path.addLine(to: CGPoint(x: 16, y: 4)); path.addLine(to: CGPoint(x: 20, y: 8)); path.addLine(to: CGPoint(x: 10, y: 18)); path.close()
            mode = .fill
        case .share:
            path.move(to: CGPoint(x: 6, y: 12)); path.addLine(to: CGPoint(x: 6, y: 20)); path.addLine(to: CGPoint(x: 18, y: 20)); path.addLine(to: CGPoint(x: 18, y: 12))
            path.move(to: CGPoint(x: 12, y: 4)); path.addLine(to: CGPoint(x: 12, y: 14))
            path.move(to: CGPoint(x: 9, y: 7)); path.addLine(to: CGPoint(x: 12, y: 4)); path.addLine(to: CGPoint(x: 15, y: 7))
        case .chat:
            path.append(UIBezierPath(roundedRect: CGRect(x: 3, y: 4, width: 18, height: 14), cornerRadius: 4))
            path.move(to: CGPoint(x: 8, y: 18)); path.addLine(to: CGPoint(x: 6, y: 22)); path.addLine(to: CGPoint(x: 12, y: 18))
        case .project:
            path.move(to: CGPoint(x: 3, y: 8)); path.addLine(to: CGPoint(x: 3, y: 18)); path.addLine(to: CGPoint(x: 21, y: 18)); path.addLine(to: CGPoint(x: 21, y: 10)); path.addLine(to: CGPoint(x: 11, y: 10)); path.addLine(to: CGPoint(x: 9, y: 8)); path.close()
            mode = .fill
        case .artifact:
            path.move(to: CGPoint(x: 8, y: 6)); path.addLine(to: CGPoint(x: 4, y: 12)); path.addLine(to: CGPoint(x: 8, y: 18))
            path.move(to: CGPoint(x: 16, y: 6)); path.addLine(to: CGPoint(x: 20, y: 12)); path.addLine(to: CGPoint(x: 16, y: 18))
        case .image:
            path.append(UIBezierPath(roundedRect: CGRect(x: 3, y: 5, width: 18, height: 14), cornerRadius: 2))
            path.move(to: CGPoint(x: 6, y: 16)); path.addLine(to: CGPoint(x: 10, y: 11)); path.addLine(to: CGPoint(x: 13, y: 14)); path.addLine(to: CGPoint(x: 16, y: 10)); path.addLine(to: CGPoint(x: 19, y: 16))
            path.append(UIBezierPath(ovalIn: CGRect(x: 7, y: 7, width: 3, height: 3)))
        case .camera:
            path.append(UIBezierPath(roundedRect: CGRect(x: 3, y: 7, width: 18, height: 12), cornerRadius: 3))
            path.append(UIBezierPath(ovalIn: CGRect(x: 9, y: 10, width: 6, height: 6)))
            path.move(to: CGPoint(x: 9, y: 7)); path.addLine(to: CGPoint(x: 10, y: 4)); path.addLine(to: CGPoint(x: 14, y: 4)); path.addLine(to: CGPoint(x: 15, y: 7))
        case .file:
            path.move(to: CGPoint(x: 6, y: 3)); path.addLine(to: CGPoint(x: 14, y: 3)); path.addLine(to: CGPoint(x: 18, y: 7)); path.addLine(to: CGPoint(x: 18, y: 21)); path.addLine(to: CGPoint(x: 6, y: 21)); path.close()
            path.move(to: CGPoint(x: 14, y: 3)); path.addLine(to: CGPoint(x: 14, y: 7)); path.addLine(to: CGPoint(x: 18, y: 7))
        case .globe:
            path.append(UIBezierPath(ovalIn: CGRect(x: 3, y: 3, width: 18, height: 18)))
            path.move(to: CGPoint(x: 12, y: 3))
            path.addCurve(to: CGPoint(x: 12, y: 21), controlPoint1: CGPoint(x: 4, y: 8), controlPoint2: CGPoint(x: 4, y: 16))
            path.move(to: CGPoint(x: 12, y: 3))
            path.addCurve(to: CGPoint(x: 12, y: 21), controlPoint1: CGPoint(x: 20, y: 8), controlPoint2: CGPoint(x: 20, y: 16))
            path.move(to: CGPoint(x: 3, y: 12)); path.addLine(to: CGPoint(x: 21, y: 12))
        case .thinking:
            path.append(UIBezierPath(ovalIn: CGRect(x: 3, y: 3, width: 18, height: 18)))
            path.move(to: CGPoint(x: 12, y: 12)); path.addLine(to: CGPoint(x: 12, y: 7))
            path.move(to: CGPoint(x: 12, y: 12)); path.addLine(to: CGPoint(x: 16, y: 12))
        case .check:
            path.move(to: CGPoint(x: 5, y: 12)); path.addLine(to: CGPoint(x: 10, y: 17)); path.addLine(to: CGPoint(x: 19, y: 7))
        case .more:
            for x in [6, 12, 18] as [CGFloat] {
                path.append(UIBezierPath(ovalIn: CGRect(x: x - 2, y: 10, width: 4, height: 4)))
            }
            mode = .fill
        case .sparkle:
            path.move(to: CGPoint(x: 12, y: 2)); path.addLine(to: CGPoint(x: 14, y: 10)); path.addLine(to: CGPoint(x: 22, y: 12)); path.addLine(to: CGPoint(x: 14, y: 14)); path.addLine(to: CGPoint(x: 12, y: 22)); path.addLine(to: CGPoint(x: 10, y: 14)); path.addLine(to: CGPoint(x: 2, y: 12)); path.addLine(to: CGPoint(x: 10, y: 10)); path.close()
            mode = .fill
        case .sidebar:
            path.append(UIBezierPath(roundedRect: CGRect(x: 3, y: 4, width: 18, height: 16), cornerRadius: 2))
            path.move(to: CGPoint(x: 9, y: 4)); path.addLine(to: CGPoint(x: 9, y: 20))
        case .info:
            path.append(UIBezierPath(ovalIn: CGRect(x: 3, y: 3, width: 18, height: 18)))
            path.move(to: CGPoint(x: 12, y: 10)); path.addLine(to: CGPoint(x: 12, y: 17))
            path.append(UIBezierPath(ovalIn: CGRect(x: 10.5, y: 6, width: 3, height: 3)))
        case .key:
            path.append(UIBezierPath(ovalIn: CGRect(x: 3, y: 8, width: 8, height: 8)))
            path.move(to: CGPoint(x: 9, y: 12)); path.addLine(to: CGPoint(x: 21, y: 12))
            path.move(to: CGPoint(x: 17, y: 12)); path.addLine(to: CGPoint(x: 17, y: 16))
            path.move(to: CGPoint(x: 20, y: 12)); path.addLine(to: CGPoint(x: 20, y: 15))
        case .moon:
            path.move(to: CGPoint(x: 18, y: 4))
            path.addCurve(to: CGPoint(x: 18, y: 20), controlPoint1: CGPoint(x: 8, y: 8), controlPoint2: CGPoint(x: 8, y: 16))
            path.addCurve(to: CGPoint(x: 18, y: 4), controlPoint1: CGPoint(x: 14, y: 6), controlPoint2: CGPoint(x: 14, y: 18))
            path.close()
            mode = .fill
        case .sun:
            path.append(UIBezierPath(ovalIn: CGRect(x: 9, y: 9, width: 6, height: 6)))
            for i in 0..<8 {
                let a = CGFloat(i) / 8.0 * 2 * .pi
                let x1 = 12 + cos(a) * 5, y1 = 12 + sin(a) * 5
                let x2 = 12 + cos(a) * 9, y2 = 12 + sin(a) * 9
                path.move(to: CGPoint(x: x1, y: y1)); path.addLine(to: CGPoint(x: x2, y: y2))
            }
        case .logout:
            path.move(to: CGPoint(x: 6, y: 4)); path.addLine(to: CGPoint(x: 6, y: 20)); path.addLine(to: CGPoint(x: 14, y: 20)); path.addLine(to: CGPoint(x: 14, y: 4)); path.close()
            path.move(to: CGPoint(x: 12, y: 12)); path.addLine(to: CGPoint(x: 21, y: 12))
            path.move(to: CGPoint(x: 18, y: 9)); path.addLine(to: CGPoint(x: 21, y: 12)); path.addLine(to: CGPoint(x: 18, y: 15))
        case .folder:
            path.move(to: CGPoint(x: 3, y: 8)); path.addLine(to: CGPoint(x: 9, y: 8)); path.addLine(to: CGPoint(x: 11, y: 6)); path.addLine(to: CGPoint(x: 21, y: 6)); path.addLine(to: CGPoint(x: 21, y: 18)); path.addLine(to: CGPoint(x: 3, y: 18)); path.close()
            mode = .fill
        case .code:
            path.move(to: CGPoint(x: 8, y: 6)); path.addLine(to: CGPoint(x: 4, y: 12)); path.addLine(to: CGPoint(x: 8, y: 18))
            path.move(to: CGPoint(x: 16, y: 6)); path.addLine(to: CGPoint(x: 20, y: 12)); path.addLine(to: CGPoint(x: 16, y: 18))
        case .eye:
            path.move(to: CGPoint(x: 2, y: 12))
            path.addQuadCurve(to: CGPoint(x: 22, y: 12), controlPoint: CGPoint(x: 12, y: 4))
            path.addQuadCurve(to: CGPoint(x: 2, y: 12), controlPoint: CGPoint(x: 12, y: 20))
            path.append(UIBezierPath(ovalIn: CGRect(x: 9, y: 9, width: 6, height: 6)))
        default:
            path.append(UIBezierPath(ovalIn: CGRect(x: 4, y: 4, width: 16, height: 16)))
        }
        path.apply(CGAffineTransform(scaleX: k, y: k))
        return (path, mode, customWidth)
    }
}

// MARK: - SparkView

public final class SparkView: UIView {
    public var color: UIColor = Theme.current.accent {
        didSet { setNeedsDisplay() }
    }

    public override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
    }

    public override func draw(_ rect: CGRect) {
        guard let _ = UIGraphicsGetCurrentContext() else { return }
        let cx = rect.midX
        let cy = rect.midY
        let outer = min(rect.width, rect.height) * 0.48
        let inner = outer * 0.12
        let rays = 12
        for i in 0..<rays {
            let angle = (CGFloat(i) / CGFloat(rays)) * 2 * .pi
            let tipX = cx + cos(angle) * outer
            let tipY = cy + sin(angle) * outer
            let halfWidth = outer * 0.09
            let b1x = cx + cos(angle + .pi / 2) * halfWidth
            let b1y = cy + sin(angle + .pi / 2) * halfWidth
            let b2x = cx + cos(angle - .pi / 2) * halfWidth
            let b2y = cy + sin(angle - .pi / 2) * halfWidth
            let p = UIBezierPath()
            p.move(to: CGPoint(x: b1x, y: b1y))
            p.addLine(to: CGPoint(x: tipX, y: tipY))
            p.addLine(to: CGPoint(x: b2x, y: b2y))
            p.close()
            color.setFill()
            p.fill()
        }
        let centerRect = CGRect(x: cx - inner, y: cy - inner, width: inner * 2, height: inner * 2)
        UIBezierPath(ovalIn: centerRect).fill()
    }

    private var pulsing = false

    public func startPulsing() {
        stopPulsing()
        pulsing = true
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.85
        scale.toValue = 1.15
        scale.duration = 1.2
        scale.autoreverses = true
        scale.repeatCount = .infinity
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.6
        opacity.toValue = 1.0
        opacity.duration = 1.2
        opacity.autoreverses = true
        opacity.repeatCount = .infinity
        opacity.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = Double.pi * 2
        rotation.duration = 8.0
        rotation.repeatCount = .infinity
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)

        layer.add(scale, forKey: "spark.scale")
        layer.add(opacity, forKey: "spark.opacity")
        layer.add(rotation, forKey: "spark.rotation")
    }

    public func stopPulsing() {
        pulsing = false
        layer.removeAnimation(forKey: "spark.scale")
        layer.removeAnimation(forKey: "spark.opacity")
        layer.removeAnimation(forKey: "spark.rotation")
    }
}

import Foundation
import UIKit

enum ImageUtil {
    static func resizeAndJPEG(_ image: UIImage, maxSide: CGFloat = 1568, quality: CGFloat = 0.8) -> (Data, String)? {
        let size = image.size
        let maxDim = max(size.width, size.height)
        let scale: CGFloat = (maxDim > maxSide) ? (maxSide / maxDim) : 1.0
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let img = resized, let data = img.jpegData(compressionQuality: quality) else { return nil }
        return (data, "image/jpeg")
    }
}

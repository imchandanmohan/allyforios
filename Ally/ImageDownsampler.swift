import UIKit
import ImageIO
import MobileCoreServices

enum ImageDownsampler {
    private static let cache = NSCache<NSString, UIImage>()

    static func downsample(url: URL, to pointSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let key = "\(url.lastPathComponent)|\(Int(pointSize.width))x\(Int(pointSize.height))@\(Int(scale))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(url as CFURL, options) else { return nil }

        let maxDimension = max(pointSize.width, pointSize.height) * scale
        let dopt = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ] as CFDictionary

        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, dopt) else { return nil }
        let img = UIImage(cgImage: cg)
        cache.setObject(img, forKey: key)
        return img
    }
}

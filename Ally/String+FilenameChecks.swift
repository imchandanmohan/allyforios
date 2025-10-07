import Foundation

extension String {
    /// Lowercased file extension taken safely from a filename or path.
    private var lcExt: String {
        URL(fileURLWithPath: self).pathExtension.lowercased()
    }

    /// True if the string looks like an image filename.
    var isImageFilename: Bool {
        switch lcExt {
        case "png", "jpg", "jpeg", "heic", "heif", "gif", "webp": return true
        default: return false
        }
    }

    /// True if the string looks like a video filename. (kept for any old references)
    var isVideoFilename: Bool {
        switch lcExt {
        case "mov", "mp4", "m4v", "hevc", "avi", "mkv": return true
        default: return false
        }
    }
}

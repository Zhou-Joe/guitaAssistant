import UIKit

/// 图片编码工具：把 UIImage 转为 base64 data URI，用于多模态 AI 调用。
enum ImageEncoder {

    /// 把 UIImage 编码为 JPEG base64 data URI。
    /// - Parameters:
    ///   - image: 原图。
    ///   - maxDimension: 最长边像素上限（超出则等比缩小），默认 2048。
    ///   - quality: JPEG 压缩质量，默认 0.8。
    /// - Returns: `data:image/jpeg;base64,...` 形式的 URI；编码失败返回 nil。
    static func jpegDataURI(_ image: UIImage,
                            maxDimension: CGFloat = 2048,
                            quality: CGFloat = 0.8) -> String? {
        let scaled = downscaleIfNeeded(image, maxDimension: maxDimension)
        guard let data = scaled.jpegData(compressionQuality: quality) else { return nil }
        let base64 = data.base64EncodedString()
        return "data:image/jpeg;base64,\(base64)"
    }

    /// 等比缩小到最长边不超过 maxDimension（已小于则原样返回）。
    private static func downscaleIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1   // 按像素尺寸渲染，避免 @2x 放大
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

import ImageIO
import UIKit

public extension UIImage {
    class func image(from color: UIColor?) -> UIImage? {
        let rect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()

        context?.setFillColor(color?.cgColor ?? UIColor.clear.cgColor)
        context?.fill(rect)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }
}

public extension UIImage {
    func dataWithRemovedMetadata() -> Data? {
        guard
            let data = self.jpegData(compressionQuality: 1),
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let type = CGImageSourceGetType(source)
        else {
            return nil
        }

        let count = CGImageSourceGetCount(source)
        assert(count == 1, "There are more than one image!")
        let overwrittenProperties = [
            kCGImagePropertyExifDictionary as String: kCFNull,
            kCGImagePropertyOrientation as String: kCFNull,
        ] as CFDictionary
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, type, count, nil)
        else { return nil }
        CGImageDestinationAddImageFromSource(destination, source, 0, overwrittenProperties)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}

public extension UIImage {
    func resizeWithWidth(width: CGFloat) -> UIImage? {
        let imageView = UIImageView(frame: CGRect(
            origin: .zero,
            size: CGSize(
                width: width,
                height: CGFloat(ceil(
                    width / size.width * size
                        .height
                ))
            )
        ))
        imageView.contentMode = .scaleAspectFit
        imageView.image = self
        UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        imageView.layer.render(in: context)
        guard let result = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        UIGraphicsEndImageContext()
        return result
    }

    func resized(withPercentage percentage: CGFloat) -> UIImage? {
        let canvasSize = CGSize(
            width: size.width * percentage,
            height: size.height * percentage
        )
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    func resized(with imageData: Data, to sizeKB: Double = 350.0) -> UIImage? {
        var resizingImage = self
        var imageSizeKB = Double(imageData.count) / 1024.0
        while imageSizeKB > sizeKB {
            guard
                let resizedImage = resizingImage.resized(withPercentage: 0.5),
                let imageData = resizedImage.pngData() else { return nil }
            resizingImage = resizedImage
            imageSizeKB = Double(imageData.count) / 1024.0
        }

        return resizingImage
    }
}

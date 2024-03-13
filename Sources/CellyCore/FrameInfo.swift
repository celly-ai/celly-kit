import CoreGraphics
import Foundation
import UIKit

public struct FrameInfo: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case image
        case number
    }

    public let image: CGImage
    public let number: Int
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.number, forKey: .number)
        // Start: Image coding policy
        if
            let imageCodingPolicy = encoder
                .userInfo[ImageCodingPolicy.codingKey] as? ImageCodingPolicy
        {
            switch imageCodingPolicy {
            case let .jpeg(quality):
                guard
                    let base64Image = UIImage(cgImage: self.image)
                        .jpegData(compressionQuality: quality)?
                        .base64EncodedString()
                else {
                    throw CellyError(message: "Unable to encode image!")
                }
                try container.encode(base64Image, forKey: .image)
            case .png:
                guard
                    let base64Image = UIImage(cgImage: self.image)
                        .pngData()?
                        .base64EncodedString()
                else {
                    throw CellyError(message: "Unable to encode image!")
                }
                try container.encode(base64Image, forKey: .image)
            }
        }
        else {
            throw CellyError(message: "Image coding policy is not defined!")
        }
        // End
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.number = try container.decode(Int.self, forKey: .number)
        let base64EncodedString = try container.decode(String.self, forKey: .image)
        guard
            let jpegData = Data(base64Encoded: base64EncodedString),
            let cgImage = UIImage(data: jpegData)?.cgImage
        else {
            throw CellyError(message: "Unable to decode image!")
        }
        self.image = cgImage
    }

    public init(
        image: CGImage,
        number: Int
    ) {
        self.image = image
        self.number = number
    }

    public static func == (lhs: FrameInfo, rhs: FrameInfo) -> Bool {
        guard lhs.number == rhs.number else {
            return false
        }
        let lhsBaseImageData = UIImage(cgImage: lhs.image).pngData()
        let rhsBaseImageData = UIImage(cgImage: rhs.image).pngData()
        return lhsBaseImageData == rhsBaseImageData
    }
}

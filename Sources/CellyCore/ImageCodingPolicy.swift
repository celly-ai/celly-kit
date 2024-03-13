import CoreGraphics
import Foundation

public enum ImageCodingPolicy {
    case jpeg(quality: CGFloat)
    case png

    public static var codingKey: CodingUserInfoKey {
        CodingUserInfoKey(rawValue: "imageCodingPolicyKey")!
    }
}

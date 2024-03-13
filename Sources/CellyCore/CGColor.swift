import CoreGraphics
import Foundation

public extension CGColor {
    class func color(hex: String) -> CGColor {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }

        guard
            cString.count == 6,
            let rgbValue = Scanner(string: cString).scanInt32(representation: .hexadecimal)
        else {
            return CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        }

        return CGColor(
            srgbRed: CGFloat((rgbValue & 0xff0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00ff00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000ff) / 255.0,
            alpha: 1.0
        )
    }
}

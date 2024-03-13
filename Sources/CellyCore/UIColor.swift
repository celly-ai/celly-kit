import Foundation
#if canImport(UIKit)
    import UIKit

    public extension UIColor {
        func modified(by percent: CGFloat) -> UIColor? {
            var red: CGFloat = 0.0
            var green: CGFloat = 0.0
            var blue: CGFloat = 0.0
            var alpha: CGFloat = 0.0

            guard self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
                return nil
            }

            // Returns the color comprised by percentage r g b values of the original color.
            let colorToReturn = UIColor(
                displayP3Red: min(red + percent / 100.0, 1.0),
                green: min(green + percent / 100.0, 1.0),
                blue: min(blue + percent / 100.0, 1.0),
                alpha: 1.0
            )

            return colorToReturn
        }

        convenience init(red: Int, green: Int, blue: Int) {
            assert(red >= 0 && red <= 255, "Invalid red component")
            assert(green >= 0 && green <= 255, "Invalid green component")
            assert(blue >= 0 && blue <= 255, "Invalid blue component")

            self.init(
                red: CGFloat(red) / 255.0,
                green: CGFloat(green) / 255.0,
                blue: CGFloat(blue) / 255.0,
                alpha: 1.0
            )
        }

        convenience init(rgb: Int) {
            self.init(
                red: (rgb >> 16) & 0xff,
                green: (rgb >> 8) & 0xff,
                blue: rgb & 0xff
            )
        }

        convenience init(hex: String) {
            var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            if cString.hasPrefix("#") {
                cString.remove(at: cString.startIndex)
            }

            if cString.count != 6 {
                self.init()
            }

            var rgbValue: UInt64 = 0
            Scanner(string: cString).scanHexInt64(&rgbValue)

            self.init(
                red: CGFloat((rgbValue & 0xff0000) >> 16) / 255.0,
                green: CGFloat((rgbValue & 0x00ff00) >> 8) / 255.0,
                blue: CGFloat(rgbValue & 0x0000ff) / 255.0,
                alpha: CGFloat(1.0)
            )
        }
    }
#endif

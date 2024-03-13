import CoreGraphics
import Foundation

extension CGSize {
    public func compare(_ size: CGSize, accuracy: CGFloat) -> Bool {
        (self.width - size.width) <= accuracy && (self.height - size.height) <= accuracy
    }
}

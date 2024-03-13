import UIKit

public extension UIButton {
    func setBackground(color: UIColor?, for state: UIControl.State) {
        self.setBackgroundImage(UIImage.image(from: color), for: state)
    }
}

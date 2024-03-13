import UIKit

open class CellyViewController: UIViewController {
    open func shakeGestureEnabled() -> Bool {
        false
    }

    // MARK: Shake Gesture

    open func shakeGesture() {}

    override open func becomeFirstResponder() -> Bool {
        true
    }

    override open func motionEnded(_ motion: UIEvent.EventSubtype, with _: UIEvent?) {
        if motion == .motionShake, self.shakeGestureEnabled() {
            self.shakeGesture()
        }
    }
}

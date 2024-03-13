import Foundation
import UIKit

public extension UIApplication {
    var currentWindow: UIWindow? {
        self.currentWindows?.first(where: \.isKeyWindow)
    }

    var currentWindows: [UIWindow]? {
        // Get connected scenes
        UIApplication.shared.connectedScenes
            // Keep only active scenes, onscreen and visible to the user
            .filter { $0.activationState == .foregroundActive }
            // Keep only the first `UIWindowScene`
            .first(where: { $0 is UIWindowScene })
            // Get its associated windows
            .flatMap { $0 as? UIWindowScene }?.windows
    }
}

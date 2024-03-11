import AVFoundation
import Foundation
import UIKit

public extension AVCaptureVideoOrientation {
    init(orientation: UIInterfaceOrientation) {
        self = { () -> AVCaptureVideoOrientation in
            switch orientation {
            case .landscapeLeft:
                return .landscapeLeft
            case .landscapeRight:
                return .landscapeRight
            case .portraitUpsideDown:
                return .portraitUpsideDown
            default:
                return .portrait
            }
        }()
    }
}

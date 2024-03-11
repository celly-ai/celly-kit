import CoreGraphics
import CoreVideo
import Foundation

public protocol CameraFeedManagerDelegate: AnyObject {
    func didVideoOutput(cgImage: CGImage?, error: Error?)

    func presentCameraPermissionsDeniedAlert()

    func presentVideoConfigurationErrorAlert()

    func sessionRunTimeErrorOccured()

    func sessionWasInterrupted(canResumeManually resumeManually: Bool)

    func sessionInterruptionEnded()
}

public extension CameraFeedManagerDelegate {
    func presentCameraPermissionsDeniedAlert() {}

    func presentVideoConfigurationErrorAlert() {}

    func sessionRunTimeErrorOccured() {}

    func sessionWasInterrupted(canResumeManually _: Bool) {}

    func sessionInterruptionEnded() {}
}

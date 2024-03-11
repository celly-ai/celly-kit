import AVFoundation
import CellyCore
import Combine
import CoreGraphics
import CoreVideo
import Foundation

public typealias CameraFeedManagerPhotoCompletion = (Result<CGImage?, Error>) -> Void

public typealias CameraFeedRecordCompletion = (Result<String, Error>?) -> Void

public enum RecordMode { case on; case off(String) }

public struct CameraFeedManagerCalibrationInfo: CustomStringConvertible {
    public  init(grayWorldDeviceWhiteBalanceGains: AVCaptureDevice.WhiteBalanceGains, exposureISO: Float, exposureDuration: CMTime, exposureMode: AVCaptureDevice.ExposureMode) {
        self.grayWorldDeviceWhiteBalanceGains = grayWorldDeviceWhiteBalanceGains
        self.exposureISO = exposureISO
        self.exposureDuration = exposureDuration
        self.exposureMode = exposureMode
    }
    
    public let grayWorldDeviceWhiteBalanceGains: AVCaptureDevice.WhiteBalanceGains
    public let exposureISO: Float
    public let exposureDuration: CMTime
    public let exposureMode: AVCaptureDevice.ExposureMode

    public var description: String {
        [
            String(
                format: "grayWorldDeviceWhiteBalanceGains: %@",
                String(describing: self.grayWorldDeviceWhiteBalanceGains)
            ),
            String(format: "exposureISO: %0.0lf", self.exposureISO),
            String(format: "exposureDuration: %@", String(describing: self.exposureDuration)),
            String(format: "exposureMode: %@", { () -> String in
                switch self.exposureMode {
                case .autoExpose: return "autoExpose"
                case .continuousAutoExposure: return "continuousAutoExposure"
                case .custom: return "custom"
                case .locked: return "locked"
                @unknown default: return "unknown"
                }
            }()),
        ].joined(separator: "\n. ")
    }
}

public struct CameraFeedManagerConfigurationInfo {
    public let configuration: CameraFeedManagerConfiguration
    public let date: Date
    public weak var captureDevice: AVCaptureDevice?
}

public struct CameraFeedManagerConfiguration {
    public init(codecType: String, bitrate: Int, fps: CMTime, resolution: CGSize, exposureMode: AVCaptureDevice.ExposureMode? = nil, exposurePointOfInterest: CGPoint? = nil, iso: Float? = nil, shutter: CMTime? = nil, whiteBalanceMode: AVCaptureDevice.WhiteBalanceMode? = nil, whiteBalanceGrains: AVCaptureDevice.WhiteBalanceGains? = nil, whiteBalanceGrayWorld: Bool? = nil, focusPoint: CGPoint? = nil, focusMode: AVCaptureDevice.FocusMode? = nil, zoom: CGFloat? = nil) {
        self.codecType = codecType
        self.bitrate = bitrate
        self.fps = fps
        self.resolution = resolution
        self.exposureMode = exposureMode
        self.exposurePointOfInterest = exposurePointOfInterest
        self.iso = iso
        self.shutter = shutter
        self.whiteBalanceMode = whiteBalanceMode
        self.whiteBalanceGrains = whiteBalanceGrains
        self.whiteBalanceGrayWorld = whiteBalanceGrayWorld
        self.focusPoint = focusPoint
        self.focusMode = focusMode
        self.zoom = zoom
    }
    
    public let codecType: String
    public let bitrate: Int

    public let fps: CMTime
    public let resolution: CGSize

    public var exposureMode: AVCaptureDevice.ExposureMode?
    public var exposurePointOfInterest: CGPoint?
    public var iso: Float?
    public var shutter: CMTime?

    public var whiteBalanceMode: AVCaptureDevice.WhiteBalanceMode?
    public var whiteBalanceGrains: AVCaptureDevice.WhiteBalanceGains?
    public var whiteBalanceGrayWorld: Bool?

    public var focusPoint: CGPoint?
    public var focusMode: AVCaptureDevice.FocusMode?

    public let zoom: CGFloat?
}

public protocol CameraFeedManager: AnyObject {
    var fps: Int? { get }
    var frame: Int { get }
    var calibrationInfo: CameraFeedManagerCalibrationInfo? { get }
    var configurationInfo: CameraFeedManagerConfigurationInfo? { get }
    var delegates: WeakSet<CameraFeedManagerDelegate> { get }

    func configure(
        configuration: CameraFeedManagerConfiguration
    ) -> Future<CameraFeedManagerConfigurationInfo?, Error>

    func photo(sound: Bool, _ completion: @escaping CameraFeedManagerPhotoCompletion)
    func start() throws
    func record(_ mode: RecordMode, _ completion: CameraFeedRecordCompletion?) throws
    func pause() throws
    func resume(_ completion: @escaping (Bool) -> Void) throws
    func stop(_ completion: (() -> Void)?) throws
    func zoom(level: CGFloat) throws
    func focus(point: CGPoint) throws
    func exposure(point: CGPoint) throws
}

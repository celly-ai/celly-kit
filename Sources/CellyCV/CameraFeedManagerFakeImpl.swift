import AVFoundation
import CellyCore
import Combine
import Foundation
import Photos
import ReplayKit
import CellyUtils

public class CameraFeedManagerFakeImpl: NSObject, CameraFeedManager {
    public private(set) var fps: Int?
    public private(set) var frame: Int
    public var delegates: WeakSet<CameraFeedManagerDelegate>
    public var calibrationInfo: CameraFeedManagerCalibrationInfo? { .init(
        grayWorldDeviceWhiteBalanceGains: .init(redGain: 0, greenGain: 0, blueGain: 0),
        exposureISO: 0,
        exposureDuration: .indefinite,
        exposureMode: .locked
    )
    }

    public var configurationInfo: CameraFeedManagerConfigurationInfo? { nil }

    // Services
    private let screenRecorder: RPScreenRecorder
    private let photoLibraryWrapper: PhotoLibraryWrapper
    private var isRecording: Bool

    // Configuration
    private var configuration: Configuration?; public struct Configuration {
        let videoURL: URL
        let playerView: PlayerView?
        let fps: Int?
        let frame: Int?
        public init(
            videoURL: URL,
            playerView: PlayerView?,
            fps: Int?,
            frame: Int?
        ) {
            self.videoURL = videoURL
            self.playerView = playerView
            self.fps = fps
            self.frame = frame
        }
    }

    // Asset Reader
    private var assetReader: AVAssetReader?
    private var isReading: Bool
    private var nominalFrameRate: Float
    private var transformDegrees: UInt8
    private let queue: DispatchQueue
    private var lastFrameDispatchDate: Date
    private var completion: ((Result<Void, Error>) -> Void)?
    private var isReachedBlackFrame: Bool

    // MARK: Timer

    fileprivate var timer: Timer?
    fileprivate var frameCounterPerSecond: Atomic<Int>

    // MARK: Rendering

    fileprivate var renderingImage: Atomic<CGImage?>
    fileprivate var rendetingTimeObserverToken: Any?
    fileprivate var renderingTimer: Timer?

    public init(
        screenRecorder: RPScreenRecorder,
        photoLibraryWrapper: PhotoLibraryWrapper
    ) {
        self.queue = DispatchQueue(
            label: "com.cellyai.fakecamera",
            qos: .userInteractive,
            attributes: [.concurrent]
        )
        self.lastFrameDispatchDate = .distantPast
        self.nominalFrameRate = 0
        self.transformDegrees = 0
        self.isReading = false
        self.frameCounterPerSecond = Atomic<Int>(0)
        self.renderingImage = Atomic<CGImage?>(nil)
        self.screenRecorder = screenRecorder
        self.photoLibraryWrapper = photoLibraryWrapper
        self.isRecording = false
        self.isReachedBlackFrame = false
        self.frame = 0
        self.delegates = .init()
        super.init()
    }

    deinit {
        self.renderingTimer?.invalidate()
        self.timer?.invalidate()
    }

    public func configure(
        configuration: Configuration,
        _ completion: ((Result<Void, Error>) -> Void)?
    ) throws {
        self.configuration = configuration
        self.completion = completion
    }

    public func start() throws {
        guard !self.isReading else {
            return
        }
        guard let configuration = self.configuration else {
            return
        }
        self.frameCounterPerSecond.mutate { value in
            value = 0
        }
        self.nominalFrameRate = 0
        self.transformDegrees = 0
        self.timer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(self.fireTimer),
            userInfo: nil,
            repeats: true
        )
        self.isReading = true
        self.renderingImage = Atomic<CGImage?>(nil)
        let avAsset = AVAsset(url: configuration.videoURL)
        try self.setupAssetReader(avAsset: avAsset)
        self.readAssetReader()
    }

    public func record(_ mode: RecordMode, _ completion: CameraFeedRecordCompletion?) throws {
        switch mode {
        case .on:
            #if SCREENRECORDING
                self.isReading = false
                self.screenRecorder.startRecording { error in
                    self.isReading = true
                    if let error = error {
                        completion?(
                            .failure(
                                CellyError(
                                    message: "Error on screen record start: \(error.localizedDescription)"
                                )
                            )
                        )
                        return
                    }
                }
            #endif
            self.isRecording = true
        case let .off(albumName):
            guard self.isRecording else {
                completion?(nil)
                return
            }
            #if SCREENRECORDING
                self.screenRecorder.stopRecording { [weak self] preview, error in
                    if let error = error {
                        completion?(
                            .failure(
                                CellyError(
                                    message: "Error on screen record stop: \(error.localizedDescription)"
                                )
                            )
                        )
                        return
                    }
                    if let unwrappedPreview = preview {
                        unwrappedPreview.previewControllerDelegate = self
                        let rootVC = UIApplication.shared.windows.filter(\.isKeyWindow).first?
                            .rootViewController
                        rootVC?.present(
                            unwrappedPreview,
                            animated: true,
                            completion: nil
                        )
                    }
                }
            #endif
            if let videoURL = self.configuration?.videoURL {
                self.photoLibraryWrapper.save(
                    outputURL: videoURL,
                    name: albumName, completion
                )
            }
            self.isRecording = false
        }
    }

    public func pause() throws {
        self.queue.async { [weak self] in
            self?.isReading = false
        }
    }

    public func stop(_ completion: (() -> Void)?) throws {
        self.timer?.invalidate()
        self.timer = nil
        self.queue.async { [weak self] in
            self?.isReading = false
            self?.nominalFrameRate = 0
            self?.isReachedBlackFrame = false
            self?.frame = 0
            self?.transformDegrees = 0
            self?.frameCounterPerSecond = Atomic<Int>(0)
            self?.assetReader?.cancelReading()
            completion?()
        }
    }

    public func resume(_: @escaping (Bool) -> Void) throws {
        self.isReading = true
        self.queue.async {
            self.readFrames()
        }
    }

    public func zoom(level _: CGFloat) throws {}

    public func focus(point _: CGPoint) throws {}

    public func exposure(point _: CGPoint) throws {}

    public func set(focusMode _: AVCaptureDevice.FocusMode) throws {}

    public func set(exposureMode _: AVCaptureDevice.ExposureMode) throws {}

    public func shutter(duration _: CMTime) throws {}

    public func iso(level _: Float) throws {}

    public func resolution(_: CGSize) throws {}

    public func fps(_: CMTime) throws {}

    public func set(whiteBalanceMode _: AVCaptureDevice.WhiteBalanceMode) throws {}

    public func graycard() throws {}

    public func set(temperature _: Float, tint _: Float) throws {}

    public func temperature(temperature _: Float, tint _: Float) throws -> AVCaptureDevice
        .WhiteBalanceGains? { .none }

    public func photo(sound _: Bool, _ completion: @escaping CameraFeedManagerPhotoCompletion) {
        completion(.success(self.renderingImage.value))
    }

    public func configure(configuration: CameraFeedManagerConfiguration)
        -> Future<CameraFeedManagerConfigurationInfo?, Error>
    {
        Future { future in
            future(.success(CameraFeedManagerConfigurationInfo(
                configuration: configuration,
                date: Date(),
                captureDevice: nil
            )))
        }
    }

    // MARK:

    @objc
    private func fireTimer() {
        if self.frameCounterPerSecond.value > 1 {
            self.fps = self.frameCounterPerSecond.value
        }
        self.frameCounterPerSecond.mutate { value in
            value = 0
        }
    }

    // Iterative

    private func setupAssetReader(avAsset: AVAsset) throws {
        if let assetReader = self.assetReader {
            assetReader.cancelReading()
        }
        guard let assetTrack = avAsset.tracks.first else {
            throw CellyError(message: "Unable to get asset track")
        }

        let minFrameDuration = assetTrack.minFrameDuration
        self.nominalFrameRate = assetTrack.nominalFrameRate
        let radians = atan2(
            assetTrack.preferredTransform.b,
            assetTrack.preferredTransform.a
        )
        self.transformDegrees = UInt8((radians * 180.0) / .pi)

        let outputSettings =
            [String(kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_32BGRA)]
        let assetReaderOutput = AVAssetReaderTrackOutput(
            track: assetTrack,
            outputSettings: outputSettings
        )
        assetReaderOutput.alwaysCopiesSampleData = false
        assetReaderOutput.supportsRandomAccess = true

        self.assetReader = try AVAssetReader(asset: avAsset)
        self.assetReader?.add(assetReaderOutput)
        DispatchQueue.main.async {
            self.renderingTimer?.invalidate()
            self.renderingTimer = Timer.scheduledTimer(
                withTimeInterval: CMTimeGetSeconds(minFrameDuration),
                repeats: true,
                block: { [weak self] _ in
                    if let cgImage = self?.renderingImage.value {
                        DispatchQueue.main.async {
                            self?.configuration?.playerView?.draw(cgImage: cgImage)
                        }
                    }
                }
            )
        }
    }

    private func readAssetReader() {
        self.assetReader?.startReading()
        self.queue.async {
            self.readFrames()
        }
    }

    private func readFrames() {
        let videoFPS = self.configuration?.fps ?? Int(self.nominalFrameRate)
        let beetweenFrameInterval = TimeInterval(1.0 / Float(videoFPS))
        var sample: CMSampleBuffer?
        while true {
            // Step 0: Reading buffer only if ready
            guard self.isReading else {
                return
            }

            let intervalSinceLastFrame = Date().timeIntervalSince(self.lastFrameDispatchDate)
            if
                intervalSinceLastFrame >= beetweenFrameInterval,
                let output = self.assetReader?.outputs.first
            {
                sample = output.copyNextSampleBuffer()
                self.frame += 1
                self.frameCounterPerSecond.mutate { value in
                    value += 1
                }
            }
            else {
                continue
            }
            self.lastFrameDispatchDate = Date()

            // Start: Skipping all frames until desired one reached
            if let frame = self.configuration?.frame, self.frame < frame {
                continue
            }
            // End

            // Extracing buffer
            guard var imageBuffer = sample?.imageBuffer else {
                break
            }

            let cgImage: CGImage = Log.signpost("Fake Camera Preprocessing") {
                // Rotating of buffer if need
                if self.transformDegrees != 0, self.transformDegrees % 90 == 0 {
                    imageBuffer = imageBuffer
                        .rotate90PixelBuffer(factor: UInt(self.transformDegrees)) ?? imageBuffer
                }

                var cgImage: CGImage!
                do {
                    cgImage = try imageBuffer.cgimage()
                }
                catch {
                    assertionFailure(error.localizedDescription)
                }
                return cgImage
            }
            // Guard check if image is black
            guard !cgImage.isBlack() else {
                guard !self.isReachedBlackFrame else {
                    Log.log(.error, "camera-feed-manager | already-reached-black-frame")
                    continue
                }
                self.isReachedBlackFrame = true
                continue
            }

            // Saving image buffer for possible render
            self.renderingImage.mutate { value in
                value = cgImage.copy()
            }

            // Outputting buffer to delegate (counter)
            autoreleasepool {
                self.delegates.makeIterator().forEach {
                    $0.didVideoOutput(cgImage: cgImage, error: nil)
                }
            }
        }
        try? self.stop { [weak self] in
            self?.completion?(.success(()))
        }
    }
}

extension CameraFeedManagerFakeImpl: RPPreviewViewControllerDelegate {
    public func previewControllerDidFinish(
        _ previewController: RPPreviewViewController
    ) {
        previewController.dismiss(animated: true, completion: nil)
    }
}

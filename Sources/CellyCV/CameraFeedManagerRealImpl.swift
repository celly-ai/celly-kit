import AudioToolbox
import AVFoundation
import CellyCore
import Combine
import ImageIO
import UIKit
import CellyUtils

public final class CameraFeedManagerRealImpl: NSObject, CameraFeedManager {
    public enum Status {
        case undefined
        case authorized
        case configured
        case failed
        case permissionDenied
    }

    public var frame: Int { self.frameCounter.value }

    public var calibrationInfo: CameraFeedManagerCalibrationInfo? {
        guard let captureDevice = self.captureDevice else {
            return nil
        }
        return .init(
            grayWorldDeviceWhiteBalanceGains: captureDevice.grayWorldDeviceWhiteBalanceGains,
            exposureISO: captureDevice.iso,
            exposureDuration: captureDevice.exposureDuration,
            exposureMode: captureDevice.exposureMode
        )
    }

    public var configurationInfo: CameraFeedManagerConfigurationInfo?

    public private(set) var fps: Int?
    private var frameCounter: Atomic<Int>

    public var delegates: WeakSet<CameraFeedManagerDelegate>

    fileprivate var photoRequest: (sound: Bool, completion: CameraFeedManagerPhotoCompletion?)?

    // MARK: Services

    fileprivate let photoLibraryWrapper: PhotoLibraryWrapper

    // MARK: Session

    fileprivate let session: AVCaptureSession
    fileprivate let sessionQueue: DispatchQueue
    fileprivate var videoDataOutput: AVCaptureVideoDataOutput
    fileprivate var imageDataOutput: AVCapturePhotoOutput
    public var captureDevice: AVCaptureDevice?
    fileprivate var configuration: Atomic<CameraFeedManagerConfiguration?>
    fileprivate var status: Atomic<Status>
    fileprivate var isSessionRunning = false

    // MARK: Recording

    fileprivate var isRecording: Bool
    fileprivate var videoWriter: AVAssetWriter?
    fileprivate var videoWriterInput: AVAssetWriterInput?
    fileprivate var sessionAtSourceTime: Atomic<CMTime?>

    // MARK: Timer

    fileprivate var timer: Timer?
    fileprivate var countedFrames: Atomic<Int>

    // MARK: Initializer

    public init(
        photoLibraryWrapper: PhotoLibraryWrapper
    ) {
        self.countedFrames = Atomic<Int>(0)
        self.session = AVCaptureSession()
        self.sessionQueue = DispatchQueue(
            label: "sessionQueue",
            attributes: [],
            autoreleaseFrequency: .workItem
        )
        self.videoDataOutput = AVCaptureVideoDataOutput()
        self.imageDataOutput = AVCapturePhotoOutput()
        self.isRecording = false
        self.status = Atomic(.undefined)
        self.configuration = Atomic(nil)
        self.sessionAtSourceTime = Atomic(nil)
        self.photoLibraryWrapper = photoLibraryWrapper
        self.frameCounter = Atomic<Int>(0)
        self.delegates = .init()
        super.init()
        self.timer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(self.fireTimer),
            userInfo: nil,
            repeats: true
        )
    }

    public func configure(
        configuration: CameraFeedManagerConfiguration,
        _ completion: @escaping (Error?) -> Void
    ) {
        guard self.configuration.value == nil else {
            completion(nil)
            return
        }
        // Authorizate and update status
        self.authorizate { status in
            self.sessionQueue.async { [weak self] in
                guard let self = self else { return }
                self.status.mutate { value in
                    value = status.camera
                }

                // Configure and update status
                do {
                    guard status.camera == Status.authorized else {
                        throw CellyError(message: "Camera authorization failed")
                    }

                    try self.configureSession(configuration: configuration)
                    self.status.mutate { value in
                        value = .configured
                    }
                    if !self.isSessionRunning {
                        self.startSession()
                    }
                    completion(nil)
                }
                catch {
                    self.status.mutate { value in
                        value = .failed
                    }
                    completion(error)
                }
            }
        }
        self.configuration.mutate { $0 = configuration }
    }

    public func configure(
        configuration: CameraFeedManagerConfiguration
    ) -> Future<CameraFeedManagerConfigurationInfo?, Error> {
        Future { future in
            // Authorizate and update status
            do {
                try self.stop {
                    self.authorizate { status in
                        self.sessionQueue.async { [weak self] in
                            guard let self = self else { return }
                            self.status.mutate { $0 = status.camera }

                            // Configure and update status
                            do {
                                guard status.camera == Status.authorized else {
                                    throw CellyError(message: "Camera authorization failed")
                                }

                                try self.configureSession(configuration: configuration)
                                self.status.mutate { $0 = .configured }
                                if !self.isSessionRunning {
                                    self.startSession()
                                }
                                let configurationInfo = CameraFeedManagerConfigurationInfo(
                                    configuration: configuration,
                                    date: Date(),
                                    captureDevice: self.captureDevice
                                )
                                self.configurationInfo = configurationInfo
                                future(.success(configurationInfo))
                            }
                            catch {
                                self.status.mutate { $0 = .failed }
                                future(.failure(error))
                            }
                        }
                    }
                    self.configuration.mutate { $0 = configuration }
                }
            }
            catch {
                future(.failure(error))
            }
        }
    }

    public func start() throws {
        self.addObservers()
        self.startSession()
    }

    public func record(_ mode: RecordMode, _ completion: CameraFeedRecordCompletion?) throws {
        switch mode {
        case .on:
            self.setupWriter()
            self.sessionAtSourceTime.mutate { value in
                value = nil
            }
            self.isRecording = true
        case let .off(albumName):
            guard self.isRecording else {
                completion?(.none)
                return
            }
            self.isRecording = false
            self.sessionAtSourceTime.mutate { value in
                value = nil
            }
            self.videoWriter?.finishWriting { [weak self] in
                self?.sessionAtSourceTime.mutate { value in
                    value = nil
                }
                if self?.videoWriter?.status == .failed {
                    completion?(.failure(
                        self?.videoWriter?
                            .error ?? CellyError(message: "Video writed undefined error")
                    ))
                    return
                }
                guard let url = self?.videoWriter?.outputURL else {
                    completion?(
                        .failure(
                            CellyError(message: "Unable to get output url for recording movie")
                        )
                    )
                    return
                }
                self?.photoLibraryWrapper.save(outputURL: url, name: albumName, completion)
            }
        }
    }

    public func pause() throws {}

    public func stop(_ completion: (() -> Void)?) throws {
        self.removeObservers()
        self.sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
            completion?()
        }
    }

    public func resume(_ completion: @escaping (Bool) -> Void) throws {
        self.sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.startSession()
            DispatchQueue.main.async {
                completion(self.isSessionRunning)
            }
        }
    }

    public func zoom(level: CGFloat) throws {
        try self.captureDevice?.zoom(level: level)
    }

    public func focus(point: CGPoint) throws {
        try self.captureDevice?.set(focusPoint: point)
    }

    public func exposure(point: CGPoint) throws {
        try self.captureDevice?.set(exposurePointOfInterest: point)
    }

    public func photo(sound: Bool, _ completion: @escaping CameraFeedManagerPhotoCompletion) {
        self.photoRequest = (sound: sound, completion: completion)
    }

    // MARK: Session Configuration Methods.

    fileprivate func authorizate(
        _ completion: @escaping ((camera: Status, photoLibrary: PhotoLibraryWrapper.Status)) -> Void
    ) {
        self.authorizateCaptureDevice { captureDeviceStatus in
            guard captureDeviceStatus == .authorized else {
                completion((
                    camera: captureDeviceStatus,
                    photoLibrary: .failed
                ))
                return
            }
            self.photoLibraryWrapper.authorizatePhotoLibrary { photoLibraryStatus in
                completion((
                    camera: .authorized,
                    photoLibrary: photoLibraryStatus
                ))
            }
        }
    }

    fileprivate func authorizateCaptureDevice(
        completion: @escaping (Status) -> Void
    ) {
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            completion(.authorized)
            return
        }

        self.sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            self?.sessionQueue.resume()
            self?.sessionQueue.async {
                completion(granted ? .authorized : .permissionDenied)
            }
        }
    }

    fileprivate func configureSession(
        configuration: CameraFeedManagerConfiguration
    ) throws {
        func addVideoDeviceInput() throws {
            // #422 Preserving setting from previous capture device
            let isConfiguringFirstTime = self.captureDevice == nil
            guard
                let camera = self.captureDevice ?? AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .back
                )
            else {
                #if targetEnvironment(simulator)
                    return
                #else
                    throw CellyError(message: "Unable to get capture device")
                #endif
            }

            let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
            self.session.inputs.forEach { self.session.removeInput($0) }
            guard self.session.canAddInput(videoDeviceInput) else {
                throw CellyError(message: "Unable to add input on capture device")
            }

            self.session.addInput(videoDeviceInput)
            try camera.lock(true) { device in
                if isConfiguringFirstTime {
                    self.session.beginConfiguration()
                    // Start: Resolution
                    switch configuration.resolution.height {
                    case 1080:
                        self.session.sessionPreset = .hd1920x1080
                    case 480:
                        self.session.sessionPreset = .vga640x480
                    default:
                        self.session.sessionPreset = .hd1280x720
                    }
                    self.session.commitConfiguration()
                    // End: Resolution
                }
                // Start: Dimension
                try device.dimension(
                    configuration.resolution,
                    fps: configuration.fps,
                    autolock: false
                )
                // End: Dimension
                // Start: Exposure
                if let exposurePointOfInterest = configuration.exposurePointOfInterest {
                    try device.set(
                        exposurePointOfInterest: exposurePointOfInterest,
                        autolock: false
                    )
                }
                if configuration.iso != nil || configuration.shutter != nil {
                    try device.exposure(
                        level: configuration.iso ?? camera.iso,
                        duration: configuration.shutter ?? camera.exposureDuration,
                        autolock: false
                    )
                }
                if let exposureMode = configuration.exposureMode {
                    try device.set(exposureMode: exposureMode, autolock: false)
                }
                // End: Exposure
                // Start: White balance
                if let whiteBalanceMode = configuration.whiteBalanceMode {
                    try device.set(whiteBalanceMode: whiteBalanceMode, autolock: false)
                }
                if let whiteBalanceGrains = configuration.whiteBalanceGrains {
                    try device.set(whiteBalanceGains: whiteBalanceGrains, autolock: false)
                }
                if configuration.whiteBalanceGrayWorld == true {
                    try device.set(
                        whiteBalanceGains: device.grayWorldDeviceWhiteBalanceGains,
                        autolock: false
                    )
                }
                // End: White balance
                // Start: Focus
                if let focusPoint = configuration.focusPoint {
                    try device.set(focusPoint: focusPoint, autolock: false)
                }
                if
                    let lensPosition = self.captureDevice?.lensPosition,
                    configuration.focusMode == .locked
                {
                    try device.set(lensPosition: lensPosition, autolock: false)
                }
                else if let focusMode = configuration.focusMode {
                    try device.set(focusMode: focusMode, autolock: false)
                }
                // End: Focus
                if let zoom = configuration.zoom {
                    try device.zoom(level: zoom, autolock: false)
                }
            }
            self.captureDevice = camera
        }
        func addVideoDataOutput() throws {
            let sampleBufferQueue = DispatchQueue(
                label: "camera-feed-queue",
                qos: .userInitiated,
                attributes: [],
                autoreleaseFrequency: .workItem
            )
            self.videoDataOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutput.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey): kCMPixelFormat_32BGRA,
            ]

            self.session.outputs.forEach { self.session.removeOutput($0) }
            guard self.session.canAddOutput(self.videoDataOutput) else {
                throw CellyError(message: "Unable to add video data output on capture device")
            }
            self.session.addOutput(self.videoDataOutput)
        }
        func addImageDataOutput() throws {
            guard self.session.canAddOutput(self.imageDataOutput) else {
                throw CellyError(message: "Unable to add photo data output on capture device")
            }
            self.session.addOutput(self.imageDataOutput)
        }

        assert(Thread.isMainThread == false)
        self.session.beginConfiguration()
        defer { self.session.commitConfiguration() }
        try addVideoDeviceInput()
        try addVideoDataOutput()
        try addImageDataOutput()
    }

    fileprivate func startSession() {
        guard self.status.value == .configured else { return }
        self.sessionQueue.async {
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
        }
    }

    @objc
    fileprivate func fireTimer() {
        if self.countedFrames.value > 1 {
            self.fps = self.countedFrames.value
        }
        self.countedFrames.mutate { value in
            value = 0
        }
    }
}

// MARK: - Notification Observers

extension CameraFeedManagerRealImpl {
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(
                CameraFeedManagerRealImpl
                    .sessionRuntimeErrorOccured(notification:)
            ),
            name: NSNotification.Name.AVCaptureSessionRuntimeError,
            object: self.session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(CameraFeedManagerRealImpl.sessionWasInterrupted(notification:)),
            name: NSNotification.Name.AVCaptureSessionWasInterrupted,
            object: self.session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(CameraFeedManagerRealImpl.sessionInterruptionEnded),
            name: NSNotification.Name.AVCaptureSessionInterruptionEnded,
            object: self.session
        )
    }

    private func removeObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.AVCaptureSessionRuntimeError,
            object: self.session
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.AVCaptureSessionWasInterrupted,
            object: self.session
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.AVCaptureSessionInterruptionEnded,
            object: self.session
        )
    }

    @objc
    private func sessionWasInterrupted(notification: Notification) {
        Log.log(.info, "camera-feed-manager | session-interrupted")
        if
            let userInfoValue = notification
                .userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
            let reasonIntegerValue = userInfoValue.integerValue,
            let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue)
        {
            switch reason {
            case .audioDeviceInUseByAnotherClient:
                Log.log(.notice, "camera-feed-manager | session-interruption | reason audioDeviceInUseByAnotherClient")
            case .videoDeviceInUseByAnotherClient:
                Log.log(.notice, "camera-feed-manager | session-interruption | reason videoDeviceInUseByAnotherClient")
            case .videoDeviceNotAvailableDueToSystemPressure:
                Log.log(.notice, "camera-feed-manager | session-interruption | reason videoDeviceNotAvailableDueToSystemPressure")
            case .videoDeviceNotAvailableInBackground:
                Log.log(.notice, "camera-feed-manager | session-interruption | reason videoDeviceNotAvailableInBackground")
            case .videoDeviceNotAvailableWithMultipleForegroundApps:
                Log.log(.notice, "camera-feed-manager | session-interruption | reason videoDeviceNotAvailableWithMultipleForegroundApps")
            @unknown default:
                Log.log(.notice, "camera-feed-manager | session-interruption | reason unknown")
            }

            var canResumeManually = false
            if reason == .videoDeviceInUseByAnotherClient {
                canResumeManually = true
            }
            else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
                canResumeManually = false
            }

            self.delegates.makeIterator().forEach {
                $0.sessionWasInterrupted(canResumeManually: canResumeManually)
            }
        }
    }

    @objc
    private func sessionInterruptionEnded(notification _: Notification) {
        Log.log(.info, "camera-feed-manager | session-interruption-ended")
        self.delegates.makeIterator().forEach {
            $0.sessionInterruptionEnded()
        }
    }

    @objc
    private func sessionRuntimeErrorOccured(notification: Notification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
            Log.log(.error, "camera-feed-manager | session | runtime-error")
            return
        }
        Log.log(.error, "camera-feed-manager | session | runtime-error  %@", error.localizedDescription)
        if error.code == .mediaServicesWereReset {
            self.sessionQueue.async {
                if self.isSessionRunning {
                    self.startSession()
                }
                else {
                    DispatchQueue.main.async {
                        self.delegates.makeIterator().forEach {
                            $0.sessionRunTimeErrorOccured()
                        }
                    }
                }
            }
        }
        else {
            self.delegates.makeIterator().forEach {
                $0.sessionRunTimeErrorOccured()
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraFeedManagerRealImpl: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard self.configuration.value != nil else {
            assertionFailure("Service is not configured")
            return
        }

        do {
            let cgImage = try _captureFrame(sampleBuffer)
            if let photoRequest = self.photoRequest {
                photoRequest.completion?(.success(cgImage))
                if photoRequest.sound {
                    AudioServicesPlaySystemSound(1108)
                }
                self.photoRequest = nil
            }
            self.delegates.makeIterator().forEach {
                $0.didVideoOutput(
                    cgImage: cgImage,
                    error: nil
                )
            }
        }
        catch {
            self.delegates.makeIterator().forEach {
                $0.didVideoOutput(
                    cgImage: nil,
                    error: error
                )
            }
        }
    }

    private func _captureFrame(_ sampleBuffer: CMSampleBuffer) throws -> CGImage? {
        // START: Recording frames
        Log.signpost("Camera Record") {
            if
                let videoWriter = self.videoWriter,
                self.isRecording,
                videoWriter.status == .writing,
                self.sessionAtSourceTime.value == nil
            {
                let sessionAtSourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                videoWriter.startSession(atSourceTime: sessionAtSourceTime)
                self.sessionAtSourceTime.mutate { value in
                    value = sessionAtSourceTime
                }
            }
            if
                self.isRecording,
                let videoWriterInput = self.videoWriterInput,
                videoWriterInput.isReadyForMoreMediaData,
                self.sessionAtSourceTime.value != nil
            {
                videoWriterInput.append(sampleBuffer)
            }
        }
        // END
        // START: Counting frames
        self.frameCounter.mutate { $0 += 1 }
        self.countedFrames.mutate { value in
            value += 1
        }
        return try Log.signpost("Camera Preprocessing") {
            // Removing exif metadata
            CMRemoveAllAttachments(sampleBuffer)

            // Outputting result buffer
            guard var imagePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                throw CellyError(message: "Unable to convert CMSampleBuffer to CVBuffer!")
            }
            // Step 3: Rotating of buffer if need
            let rotationAngle = UInt(self.rotationAngle())
            if rotationAngle % 180 == 0 {
                imagePixelBuffer = imagePixelBuffer
                    .rotate90PixelBuffer(factor: rotationAngle) ?? imagePixelBuffer
            }

            // MARK: CVPixelBuffer2CGImage

            var cgImage: CGImage!
            if ProcessInfo.processInfo.environment["debug_crop_no_flipped"] != nil {
                cgImage = try imagePixelBuffer.cgimage().flipped()
            }
            else {
                cgImage = try imagePixelBuffer.cgimage()
            }

            return cgImage
        }
        // END
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraFeedManagerRealImpl: AVCapturePhotoCaptureDelegate {
    public func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto _: AVCapturePhoto,
        error _: Error?
    ) {}
}

// MARK: - Recording

extension CameraFeedManagerRealImpl {
    private func setupWriter() {
        guard let configuration = self.configuration.value else {
            assertionFailure("Service is not configured")
            return
        }
        do {
            guard
                let outputFileName = (NSUUID().uuidString as NSString)
                    .appendingPathExtension("mov")
            else {
                assertionFailure("Unable to get unique movie recording file name")
                return
            }
            let tmpDirectory = NSTemporaryDirectory() as NSString
            let outputFilePath = tmpDirectory
                .appendingPathComponent(outputFileName)
            let outputFileURL = URL(fileURLWithPath: outputFilePath)
            let videoWriter = try AVAssetWriter(
                url: outputFileURL,
                fileType: .mp4
            )

            // Add video input
            let codec: AVVideoCodecType = { () -> AVVideoCodecType in
                switch configuration.codecType {
                case "hvec":
                    return .hevc
                case "jpeg":
                    return .jpeg
                case "h264":
                    return .h264
                default:
                    assertionFailure("Undefined codec in configuration")
                    return .hevc
                }
            }()
            let videoWriterInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: [
                    AVVideoCodecKey: codec,
                    AVVideoWidthKey: configuration.resolution
                        .width,
                    AVVideoHeightKey: configuration.resolution
                        .height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: configuration
                            .bitrate,
                    ],
                ]
            )
            videoWriterInput.transform = self.videoTransform()
            videoWriterInput.expectsMediaDataInRealTime = true
            if videoWriter.canAdd(videoWriterInput) {
                videoWriter.add(videoWriterInput)
            }
            videoWriter.startWriting()

            self.videoWriterInput = videoWriterInput
            self.videoWriter = videoWriter
        }
        catch {
            Log.log(
                .error,
                "camera-feed-maanger | asset-writer | error %@",
                error.localizedDescription
            )
        }
    }

    private func videoTransform() -> CGAffineTransform {
        switch UIDevice.current.orientation {
        case .landscapeLeft,
             .portraitUpsideDown:
            return CGAffineTransform(rotationAngle: CGFloat(.pi * 0.0) / 180.0)
        case .landscapeRight,
             .portrait:
            return CGAffineTransform(rotationAngle: CGFloat(.pi * -180.0) / 180.0)
        default:
            return CGAffineTransform(rotationAngle: CGFloat(.pi * 90.0) / 180.0)
        }
    }

    private func rotationAngle() -> CGFloat {
        switch UIDevice.current.orientation {
        case .landscapeRight,
             .portrait:
            return 180.0
        default:
            return 0.0
        }
    }
}

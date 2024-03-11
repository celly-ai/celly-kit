import AVFoundation
import CellyCore

public extension AVCaptureDevice {
    // MARK: Dimension

    func dimension(
        _ resolution: CGSize,
        fps: CMTime,
        autolock: Bool = true
    ) throws {
        for format in self.formats {
            let containsFPS = format.videoSupportedFrameRateRanges.contains {
                Int32($0.maxFrameRate) >= fps.timescale
            }
            let containsResolution = (
                format.highResolutionStillImageDimensions
                    .width == Int32(resolution.width)
                    && format.highResolutionStillImageDimensions.height == Int32(resolution.height)
            )
            if containsFPS, containsResolution {
                try self.lock(autolock) { device in
                    device.activeFormat = format
                    Log.log(
                        .debug,
                        "capture-device | active-format %@", String(describing: format)
                    )
                    try device.fps(fps, autolock: false)
                }
            }
        }
    }

    // MARK: Zoom

    func zoom(level: CGFloat, autolock: Bool = true) throws {
        try self.lock(autolock) { device in
            let maxZoomFactor = device.activeFormat.videoMaxZoomFactor
            device.videoZoomFactor = max(1.0, min(level, maxZoomFactor))
            Log.log(
                .notice,
                "capture-device | zoom %0.0lf", level
            )
        }
    }

    // MARK: FPS

    func fps(_ fps: CMTime, autolock: Bool = true) throws {
        try self.lock(autolock) { device in
            let videoSupportedFrameRateRanges = device.activeFormat.videoSupportedFrameRateRanges
                .sorted {
                    $0.maxFrameRate < $1.maxFrameRate
                }
            let maxFPS = min(fps, videoSupportedFrameRateRanges.first?.maxFrameDuration ?? fps)
            device.activeVideoMaxFrameDuration = maxFPS
            device.activeVideoMinFrameDuration = maxFPS
            Log.log(
                .notice,
                "capture-device | fps %@", String(describing: fps)
            )
        }
    }

    // MARK: Focus

    func set(focusMode: AVCaptureDevice.FocusMode, autolock: Bool = true) throws {
        try self.lock(autolock) { device in
            device.focusMode = focusMode
            Log.log(
                .notice,
                "capture-device | focus-mode | %@", { () -> String in
                    switch focusMode {
                    case .autoFocus: return "autoFocus"
                    case .continuousAutoFocus: return "continuousAutoFocus"
                    case .locked: return "locked"
                    @unknown default: return "unknown"
                    }
                }()
            )
        }
    }

    func set(focusPoint: CGPoint, autolock: Bool = true) throws {
        try self.lock(autolock) { device in
            try device.set(focusMode: .autoFocus, autolock: false)
            device.focusPointOfInterest = focusPoint
            Log.log(
                .notice,
                "capture-device | focus P(%0.0lf,%0.0lf) ", focusPoint.x, focusPoint.y
            )
        }
    }

    func set(lensPosition: Float, autolock: Bool = true) throws {
        try self.lock(autolock) { device in
            device.setFocusModeLocked(lensPosition: lensPosition) { _ in
                Log.log(
                    .notice,
                    "capture-device| lens-position P(%0.5f) ", lensPosition
                )
            }
        }
    }

    // MARK: Exposure

    func set(exposurePointOfInterest: CGPoint, autolock: Bool = true) throws {
        try self.lock(autolock) { device in
            device.exposurePointOfInterest = exposurePointOfInterest
            device.exposureMode = .autoExpose
            Log.log(
                .notice,
                "capture-device | exposure-point-of-interest %@",
                String(describing: self.exposurePointOfInterest)
            )
        }
    }

    func set(exposureMode: AVCaptureDevice.ExposureMode, autolock: Bool = true) throws {
        guard self.exposureMode != exposureMode else {
            return
        }
        try self.lock(autolock) { device in
            device.exposureMode = exposureMode
            Log.log(
                .notice,
                "capture-device | exposure-mode | %@", { () -> String in
                    switch exposureMode {
                    case .autoExpose: return "autoExpose"
                    case .continuousAutoExposure: return "continuousAutoExposure"
                    case .custom: return "custom"
                    case .locked: return "locked"
                    @unknown default: return "unknown"
                    }
                }()
            )
        }
    }

    func exposure(
        level: Float,
        duration: CMTime,
        autolock: Bool = true,
        _ completion: ((AVCaptureDevice) -> Void)? = nil
    ) throws {
        // Shutter: Start
        let minShutter = self.activeFormat.minExposureDuration
        let maxShutter = self.activeFormat.maxExposureDuration
        var chosenDuration = duration
        if !(minShutter...maxShutter ~= chosenDuration) {
            Log.log(
                .error,
                "%@",
                "The passed exposure duration \(duration.value):\(duration.timescale) is outside the supported range: \(minShutter.value):\(minShutter.timescale) - \(maxShutter.value):\(maxShutter.timescale)"
            )
            chosenDuration = CMTimeMinimum(CMTimeMaximum(minShutter, chosenDuration), maxShutter)
        }
        // Shutter: End
        // Iso: Start
        let minIso = self.activeFormat.minISO
        let maxIso = self.activeFormat.maxISO
        var chosenLevel = level
        if !(minIso...maxIso ~= chosenLevel) {
            Log.log(.error, "%@", "The passed iso \(level) is outside the supported range: \(minIso) - \(maxIso)")
            chosenLevel = fmin(fmax(minIso, chosenLevel), maxIso)
        }
        // Iso: End
        try self.lock(autolock) { device in
            device.setExposureModeCustom(
                duration: chosenDuration,
                iso: chosenLevel
            ) { _ in
                Log.log(
                    .notice,
                    "capture-device | exposure-set | iso %@ | duration %@",
                    String(describing: self.iso),
                    String(describing: self.exposureDuration)
                )
                completion?(self)
            }
        }
    }

    // MARK: White balance

    func set(whiteBalanceMode: AVCaptureDevice.WhiteBalanceMode, autolock: Bool = true) throws {
        try self.lock(autolock) { device in
            device.whiteBalanceMode = whiteBalanceMode
            Log.log(
                .notice,
                "capture-device | white-balance-mode %@", { () -> String in
                    switch whiteBalanceMode {
                    case .autoWhiteBalance: return "autoWhiteBalance"
                    case .continuousAutoWhiteBalance: return "continuousAutoWhiteBalance"
                    case .locked: return "locked"
                    @unknown default: return "unknown"
                    }
                }()
            )
        }
    }

    func set(
        whiteBalanceGains: AVCaptureDevice.WhiteBalanceGains,
        autolock: Bool = true,
        _ completion: (() -> Void)? = nil
    ) throws {
        try self.lock(autolock) { device in
            device.setWhiteBalanceModeLocked(
                with: device.normalizedGains(whiteBalanceGains)
            ) { _ in
                Log.log(
                    .notice,
                    "capture-device | white-balance-gains | \(String(describing: self.deviceWhiteBalanceGains))"
                )
                completion?()
            }
        }
    }

    private func normalizedGains(
        _ gains: AVCaptureDevice.WhiteBalanceGains
    ) -> AVCaptureDevice.WhiteBalanceGains {
        func normolizedChannel(_ gain: Float) -> Float {
            max(1, min(self.maxWhiteBalanceGain, gain))
        }
        return WhiteBalanceGains(
            redGain: normolizedChannel(gains.redGain),
            greenGain: normolizedChannel(gains.greenGain),
            blueGain: normolizedChannel(gains.blueGain)
        )
    }

    func lock(_ locked: Bool, _ configure: (AVCaptureDevice) throws -> Void) throws {
        if locked { try self.lockForConfiguration() }
        try configure(self)
        if locked { self.unlockForConfiguration() }
    }
}

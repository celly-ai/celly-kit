import Accelerate
import CoreGraphics
import CoreImage
import Foundation

public extension CVPixelBuffer {
    static func pixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let frameSize = CGSize(width: image.width, height: image.height)

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(frameSize.width),
            Int(frameSize.height),
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )

        if status != kCVReturnSuccess {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(
            rawValue: CGBitmapInfo.byteOrder32Little
                .rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        let context = CGContext(
            data: data,
            width: Int(frameSize.width),
            height: Int(frameSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
            space: rgbColorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )

        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }

    static func pixelBuffer(from image: CIImage, pixelFormatType: OSType) throws -> CVPixelBuffer {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue,
        ] as CFDictionary
        var pixelBufferRaw: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(image.extent.width),
            Int(image.extent.height),
            pixelFormatType,
            attrs,
            &pixelBufferRaw
        )

        guard let pixelBuffer = pixelBufferRaw, status == kCVReturnSuccess else {
            throw CVError(code: status)
        }

        return pixelBuffer
    }

    /// Returns the RGB data representation of the given image buffer with the specified `byteCount`.
    ///
    /// - Parameters
    ///   - buffer: The BGRA pixel buffer to convert to RGB data.
    ///   - byteCount: The expected byte count for the RGB data calculated using the values that the
    ///       model was trained on: `batchSize * imageWidth * imageHeight * componentsCount`.
    ///   - isModelQuantized: Whether the model is quantized (i.e. fixed point values rather than
    ///       floating point values).
    /// - Returns: The RGB data representation of the image buffer or `nil` if the buffer could not be
    ///     converted.
    func rgbDataFromBuffer(
        byteCount _: Int,
        channels _: Int,
        alphaComponent _: Int,
        rgbPixelChannels _: Int,
        lastBgrComponent _: Int,
        transformFloatBytes: ((inout [Float]) -> Void)?
    ) -> Data? {
//        let buffer = self
//        CVPixelBufferLockBaseAddress(buffer, .readOnly)
//        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
//        guard let mutableRawPointer = CVPixelBufferGetBaseAddress(buffer) else {
//            return nil
//        }
//        assert(CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA)
//        let count = CVPixelBufferGetDataSize(buffer)
//        let bufferData = Data(bytesNoCopy: mutableRawPointer, count: count, deallocator: .none)
//        var rgbBytes = [UInt8](repeating: 0, count: byteCount)
//        var pixelIndex = 0
//        for component in bufferData.enumerated() {
//            let bgraComponent = component.offset % channels;
//            let isAlphaComponent = bgraComponent == alphaComponent;
//            guard !isAlphaComponent else {
//                pixelIndex += 1
//                continue
//            }
//            // Swizzle BGR -> RGB.
//            let rgbIndex = pixelIndex * rgbPixelChannels + (lastBgrComponent - bgraComponent)
//            rgbBytes[rgbIndex] = component.element
//        }
//        let floatRGBBytes = rgbBytes.map { byte -> Float in // Float - 4 bytes per value
//            return Float(byte) / 128.0 - 1.0
//        }

        CVPixelBufferLockBaseAddress(self, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
        }
        guard let sourceData = CVPixelBufferGetBaseAddress(self) else {
            return nil
        }

        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(self)
        let destinationChannelCount = 3
        let destinationBytesPerRow = destinationChannelCount * width

        var sourceBuffer = vImage_Buffer(
            data: sourceData,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: sourceBytesPerRow
        )

        guard let destinationData = malloc(height * destinationBytesPerRow) else {
            Log.log(.error, "celly-core | cvpixel-buffer | rgbDataFromBuffer: out_of_memory ")
            return nil
        }

        defer {
            free(destinationData)
        }

        var destinationBuffer = vImage_Buffer(
            data: destinationData,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: destinationBytesPerRow
        )

        let pixelBufferFormat = CVPixelBufferGetPixelFormatType(self)

        switch pixelBufferFormat {
        case kCVPixelFormatType_32BGRA:
            vImageConvert_BGRA8888toRGB888(
                &sourceBuffer,
                &destinationBuffer,
                UInt32(kvImageNoFlags)
            )
        case kCVPixelFormatType_32ARGB:
            vImageConvert_ARGB8888toRGB888(
                &sourceBuffer,
                &destinationBuffer,
                UInt32(kvImageNoFlags)
            )
        case kCVPixelFormatType_32RGBA:
            vImageConvert_RGBA8888toRGB888(
                &sourceBuffer,
                &destinationBuffer,
                UInt32(kvImageNoFlags)
            )
        default:
            // Unknown pixel format.
            return nil
        }

        let byteData = Data(
            bytes: destinationBuffer.data,
            count: destinationBuffer.rowBytes * height
        )
        guard let transformFloatBytes = transformFloatBytes else {
            return byteData
        }

        // Not quantized, convert to floats
        let bytes = [UInt8](unsafeData: byteData)!
        var floatBytes = [Float](repeating: 0, count: bytes.count)
        vDSP_vfltu8(bytes, 1, &floatBytes, 1, vDSP_Length(bytes.count))
        transformFloatBytes(&floatBytes)
        return floatBytes.withUnsafeBufferPointer(Data.init)
    }

    /**
     Returns thumbnail by cropping pixel buffer to biggest square and scaling the cropped image to model dimensions.
     */
    func resized(toSize size: CGSize) -> CVPixelBuffer? {
        let imageWidth = CVPixelBufferGetWidth(self)
        let imageHeight = CVPixelBufferGetHeight(self)

        let pixelBufferType = CVPixelBufferGetPixelFormatType(self)

        assert(pixelBufferType == kCVPixelFormatType_32BGRA)

        let inputImageRowBytes = CVPixelBufferGetBytesPerRow(self)
        let imageChannels = 4

        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))

        // Finds the biggest square in the pixel buffer and advances rows based on it.
        guard let inputBaseAddress = CVPixelBufferGetBaseAddress(self) else {
            return nil
        }

        // Gets vImage Buffer from input image
        var inputVImageBuffer = vImage_Buffer(
            data: inputBaseAddress,
            height: UInt(imageHeight),
            width: UInt(imageWidth),
            rowBytes: inputImageRowBytes
        )

        let scaledImageRowBytes = Int(size.width) * imageChannels
        guard let scaledImageBytes = malloc(Int(size.height) * scaledImageRowBytes) else {
            return nil
        }

        // Allocates a vImage buffer for scaled image.
        var scaledVImageBuffer = vImage_Buffer(
            data: scaledImageBytes,
            height: UInt(size.height),
            width: UInt(size.width),
            rowBytes: scaledImageRowBytes
        )

        // Performs the scale operation on input image buffer and stores it in scaled image buffer.
        let scaleError = vImageScale_ARGB8888(
            &inputVImageBuffer,
            &scaledVImageBuffer,
            nil,
            vImage_Flags(0)
        )

        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))

        guard scaleError == kvImageNoError else {
            return nil
        }

        let releaseCallBack: CVPixelBufferReleaseBytesCallback = { _, pointer in

            if let pointer = pointer {
                free(UnsafeMutableRawPointer(mutating: pointer))
            }
        }

        var scaledPixelBuffer: CVPixelBuffer?

        // Converts the scaled vImage buffer to CVPixelBuffer
        let conversionStatus = CVPixelBufferCreateWithBytes(
            nil,
            Int(size.width),
            Int(size.height),
            pixelBufferType,
            scaledImageBytes,
            scaledImageRowBytes,
            releaseCallBack,
            nil,
            nil,
            &scaledPixelBuffer
        )

        guard conversionStatus == kCVReturnSuccess else {
            free(scaledImageBytes)
            return nil
        }

        return scaledPixelBuffer
    }

    /**
     Returns thumbnail by cropping pixel buffer to biggest square and scaling the cropped image to model dimensions.
     */
    func scaled(to size: CGSize) throws -> CVPixelBuffer {
        let imageWidth = CVPixelBufferGetWidth(self)
        let imageHeight = CVPixelBufferGetHeight(self)
        let pixelBufferType = CVPixelBufferGetPixelFormatType(self)
        assert(pixelBufferType == kCVPixelFormatType_32BGRA)
        let inputImageRowBytes = CVPixelBufferGetBytesPerRow(self)
        let imageChannels = 4
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        // Finds the biggest square in the pixel buffer and advances rows based on it.
        guard let inputBaseAddress = CVPixelBufferGetBaseAddress(self) else {
            throw CellyError(message: "Failed to get base address from \(self)")
        }
        // Gets vImage Buffer from input image
        var inputVImageBuffer = vImage_Buffer(
            data: inputBaseAddress,
            height: UInt(imageHeight),
            width: UInt(imageWidth),
            rowBytes: inputImageRowBytes
        )
        let scaledImageRowBytes = Int(size.width) * imageChannels
        guard let scaledImageBytes = malloc(Int(size.height) * scaledImageRowBytes) else {
            throw CellyError(
                message: "Failed allocale size \(Int(size.height) * scaledImageRowBytes)"
            )
        }
        // Allocates a vImage buffer for scaled image.
        var scaledVImageBuffer = vImage_Buffer(
            data: scaledImageBytes,
            height: UInt(size.height),
            width: UInt(size.width),
            rowBytes: scaledImageRowBytes
        )
        // Performs the scale operation on input image buffer and stores it in scaled image buffer.
        let scaleError = vImageScale_ARGB8888(
            &inputVImageBuffer,
            &scaledVImageBuffer,
            nil,
            vImage_Flags(0)
        )
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        guard scaleError == kvImageNoError else {
            throw CellyError(message: "Failed to scale with error \(scaleError)")
        }
        let releaseCallBack: CVPixelBufferReleaseBytesCallback = { _, pointer in
            if let pointer = pointer {
                free(UnsafeMutableRawPointer(mutating: pointer))
            }
        }
        var scaledPixelBuffer: CVPixelBuffer?
        // Converts the scaled vImage buffer to CVPixelBuffer
        let conversionStatus = CVPixelBufferCreateWithBytes(
            nil,
            Int(size.width),
            Int(size.height),
            pixelBufferType,
            scaledImageBytes,
            scaledImageRowBytes,
            releaseCallBack,
            nil,
            nil,
            &scaledPixelBuffer
        )
        guard let resultPixelBuffer = scaledPixelBuffer, conversionStatus == kCVReturnSuccess else {
            free(scaledImageBytes)
            throw CellyError(message: "Failed conversation with status \(conversionStatus)")
        }
        return resultPixelBuffer
    }

    /**
     Returns thumbnail by cropping pixel buffer to biggest square and scaling the cropped image to
     model dimensions.
     */
    func centerThumbnail(ofSize size: CGSize) -> CVPixelBuffer? {
        let imageWidth = CVPixelBufferGetWidth(self)
        let imageHeight = CVPixelBufferGetHeight(self)
        let pixelBufferType = CVPixelBufferGetPixelFormatType(self)

        assert(pixelBufferType == kCVPixelFormatType_32BGRA)
//
        let inputImageRowBytes = CVPixelBufferGetBytesPerRow(self)
        let imageChannels = 4

        let thumbnailSize = min(imageWidth, imageHeight)
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))

        var originX = 0
        var originY = 0

        if imageWidth > imageHeight {
            originX = (imageWidth - imageHeight) / 2
        }
        else {
            originY = (imageHeight - imageWidth) / 2
        }

        // Finds the biggest square in the pixel buffer and advances rows based on it.
        guard
            let inputBaseAddress = CVPixelBufferGetBaseAddress(self)?.advanced(
                by: originY * inputImageRowBytes + originX * imageChannels
            )
        else {
            return nil
        }

        // Gets vImage Buffer from input image
        var inputVImageBuffer = vImage_Buffer(
            data: inputBaseAddress, height: UInt(thumbnailSize), width: UInt(thumbnailSize),
            rowBytes: inputImageRowBytes
        )

        let thumbnailRowBytes = Int(size.width) * imageChannels
        guard let thumbnailBytes = malloc(Int(size.height) * thumbnailRowBytes) else {
            return nil
        }

        // Allocates a vImage buffer for thumbnail image.
        var thumbnailVImageBuffer = vImage_Buffer(
            data: thumbnailBytes,
            height: UInt(size.height),
            width: UInt(size.width),
            rowBytes: thumbnailRowBytes
        )

        // Performs the scale operation on input image buffer and stores it in thumbnail image buffer.
        let scaleError = vImageScale_ARGB8888(
            &inputVImageBuffer,
            &thumbnailVImageBuffer,
            nil,
            vImage_Flags(0)
        )

        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))

        guard scaleError == kvImageNoError else {
            return nil
        }

        let releaseCallBack: CVPixelBufferReleaseBytesCallback = { _, pointer in

            if let pointer = pointer {
                free(UnsafeMutableRawPointer(mutating: pointer))
            }
        }

        var thumbnailPixelBuffer: CVPixelBuffer?

        // Converts the thumbnail vImage buffer to CVPixelBuffer
        let conversionStatus = CVPixelBufferCreateWithBytes(
            nil, Int(size.width), Int(size.height), pixelBufferType, thumbnailBytes,
            thumbnailRowBytes, releaseCallBack, nil, nil, &thumbnailPixelBuffer
        )

        guard conversionStatus == kCVReturnSuccess else {
            free(thumbnailBytes)
            return nil
        }

        return thumbnailPixelBuffer
    }

    /**
     Rotates CVPixelBuffer by the provided factor of 90 counterclock-wise.
     - Note: The new CVPixelBuffer is not backed by an IOSurface and therefore
     cannot be turned into a Metal texture.
     /* factor:
     *  0 -- rotate 0 degrees (simply copy the data from src to dest)
     *  1 -- rotate 90 degrees counterclockwise
     *  2 -- rotate 180 degress
     *  3 -- rotate 270 degrees counterclockwise
     */
     */
    func rotate90PixelBuffer(factor: UInt) -> CVPixelBuffer? {
        let srcPixelBuffer: CVPixelBuffer = self
        let flags = CVPixelBufferLockFlags(rawValue: 0)
        guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(srcPixelBuffer, flags) else {
            return nil
        }
        defer { CVPixelBufferUnlockBaseAddress(srcPixelBuffer, flags) }

        guard let srcData = CVPixelBufferGetBaseAddress(srcPixelBuffer) else {
            Log.log(.error, "celly-core | cvpixel-buffer | rotate90PixelBuffer: CVPixelBufferGetBaseAddress=null")
            return nil
        }
        let sourceWidth = CVPixelBufferGetWidth(srcPixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(srcPixelBuffer)
        var destWidth = sourceHeight
        var destHeight = sourceWidth
        var color = UInt8(0)

        if factor % 2 == 0 {
            destWidth = sourceWidth
            destHeight = sourceHeight
        }

        let srcBytesPerRow = CVPixelBufferGetBytesPerRow(srcPixelBuffer)
        var srcBuffer = vImage_Buffer(
            data: srcData,
            height: vImagePixelCount(sourceHeight),
            width: vImagePixelCount(sourceWidth),
            rowBytes: srcBytesPerRow
        )

        let destBytesPerRow = destWidth * 4
        guard let destData = malloc(destHeight * destBytesPerRow) else {
            Log.log(.error, "celly-core | cvpixel-buffer | rotate90PixelBuffer: out_of_memory ")
            return nil
        }
        var destBuffer = vImage_Buffer(
            data: destData,
            height: vImagePixelCount(destHeight),
            width: vImagePixelCount(destWidth),
            rowBytes: destBytesPerRow
        )

        let rotation: UInt8
        if factor == 0 {
            rotation = UInt8(kRotate0DegreesClockwise)
        }
        else if factor == 90 {
            rotation = UInt8(kRotate90DegreesClockwise)
        }
        else if factor == 180 {
            rotation = UInt8(kRotate180DegreesClockwise)
        }
        else if factor == 270 {
            rotation = UInt8(kRotate270DegreesClockwise)
        }
        else {
            fatalError("Unsupported factor \(factor)")
        }
        let error = vImageRotate90_ARGB8888(
            &srcBuffer,
            &destBuffer,
            rotation,
            &color,
            vImage_Flags(0)
        )
        if error != kvImageNoError {
            os_log(.info, "Rotating error %ld", error)
            free(destData)
            return nil
        }

        let releaseCallback: CVPixelBufferReleaseBytesCallback = { _, ptr in
            if let ptr = ptr {
                free(UnsafeMutableRawPointer(mutating: ptr))
            }
        }

        let pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer)
        var dstPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreateWithBytes(
            nil,
            destWidth,
            destHeight,
            pixelFormat,
            destData,
            destBytesPerRow,
            releaseCallback,
            nil,
            nil,
            &dstPixelBuffer
        )
        if status != kCVReturnSuccess {
            Log.log(.error, "celly-core | cvpixel-buffer | rotate90PixelBuffer: CVPixelBufferCreateWithBytes!=success")
            free(destData)
            return nil
        }
        return dstPixelBuffer
    }

    /// https://gist.github.com/valkjsaaa/f9edfc25b4fd592caf82834fafc07759
    func deepcopy() throws -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let format = CVPixelBufferGetPixelFormatType(self)
        var pixelBufferCopyOptional: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, width, height, format, nil, &pixelBufferCopyOptional)
        guard status == kCVReturnSuccess else {
            throw CellyError(message: "Unable to create copy buffer, status: \(status)")
        }
        if let pixelBufferCopy = pixelBufferCopyOptional {
            CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
            CVPixelBufferLockBaseAddress(pixelBufferCopy, [])
            let baseAddress = CVPixelBufferGetBaseAddress(self)
            let dataSize = CVPixelBufferGetDataSize(self)
            let target = CVPixelBufferGetBaseAddress(pixelBufferCopy)
            memcpy(target, baseAddress, dataSize)
            CVPixelBufferUnlockBaseAddress(pixelBufferCopy, [])
            CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
        }
        guard let pixelBufferCopy = pixelBufferCopyOptional else {
            throw CellyError(message: "Error on scale operation")
        }
        return pixelBufferCopy
    }

    // Converts to Images

    var ciimage: CIImage {
        CIImage(cvImageBuffer: self).settingProperties([AnyHashable: Any]())
    }

    func cgimage() throws -> CGImage {
        guard let cgImage = CGImage.create(pixelBuffer: self) else {
            throw CellyError(message: "Unable to create cgimage from pixelBuffer")
        }
        return cgImage
    }

    /**
       First crops the pixel buffer, then resizes it.
       - Note: The new CVPixelBuffer is not backed by an IOSurface and therefore
         cannot be turned into a Metal texture.
      - Note: 32BGRA pixel format supported
     */
    func resizePixelBuffer(
        cropX: Int,
        cropY: Int,
        cropWidth: Int,
        cropHeight: Int,
        scaleWidth: Int,
        scaleHeight: Int
    ) throws -> CVPixelBuffer {
        let srcPixelBuffer = self

        let flags = CVPixelBufferLockFlags(rawValue: 0)
        guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(srcPixelBuffer, flags) else {
            throw CellyError(
                message: "Failed to lock the base address of the pixel buffer \(String(describing: srcPixelBuffer))"
            )
        }
        defer { CVPixelBufferUnlockBaseAddress(srcPixelBuffer, flags) }
        guard let srcData = CVPixelBufferGetBaseAddress(srcPixelBuffer) else {
            throw CellyError(
                message: "Could not get pixel buffer base address \(String(describing: srcPixelBuffer))"
            )
        }
        let pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer)
        guard pixelFormat == kCVPixelFormatType_32BGRA else {
            throw CellyError(message: "Unsupporeted format \(srcPixelBuffer.pixelFormatName())")
        }
        let srcBytesPerRow = CVPixelBufferGetBytesPerRow(srcPixelBuffer)
        let offset = cropY * srcBytesPerRow + cropX * 4
        var srcBuffer = vImage_Buffer(
            data: srcData.advanced(by: offset),
            height: vImagePixelCount(cropHeight),
            width: vImagePixelCount(cropWidth),
            rowBytes: srcBytesPerRow
        )

        let destBytesPerRow = scaleWidth * 4
        guard let destData = malloc(scaleHeight * destBytesPerRow) else {
            throw CellyError(message: "Out of memory \(String(describing: srcPixelBuffer))")
        }
        var destBuffer = vImage_Buffer(
            data: destData,
            height: vImagePixelCount(scaleHeight),
            width: vImagePixelCount(scaleWidth),
            rowBytes: destBytesPerRow
        )

        let error = vImageScale_ARGB8888(&srcBuffer, &destBuffer, nil, vImage_Flags(0))
        if error != kvImageNoError {
            free(destData)
            throw CellyError(message: "Error on scale operation: \(error)")
        }

        let releaseCallback: CVPixelBufferReleaseBytesCallback = { _, ptr in
            if let ptr = ptr {
                free(UnsafeMutableRawPointer(mutating: ptr))
            }
        }

        var dstPixelBufferRaw: CVPixelBuffer?
        let status = CVPixelBufferCreateWithBytes(
            nil,
            scaleWidth,
            scaleHeight,
            pixelFormat,
            destData,
            destBytesPerRow,
            releaseCallback,
            nil,
            nil,
            &dstPixelBufferRaw
        )
        guard let dstPixelBuffer = dstPixelBufferRaw, status == kCVReturnSuccess else {
            free(destData)
            throw CVError(code: status)
        }
        return dstPixelBuffer
    }

    func cropPixelBuffer(rect: CGRect) throws -> CVPixelBuffer {
        try self.cropPixelBuffer(
            cropX: Int(rect.minX),
            cropY: Int(rect.minY),
            cropWidth: Int(rect.width),
            cropHeight: Int(rect.height)
        )
    }

    func cropPixelBuffer(
        cropX: Int,
        cropY: Int,
        cropWidth: Int,
        cropHeight: Int
    ) throws -> CVPixelBuffer {
        try self.resizePixelBuffer(
            cropX: cropX,
            cropY: cropY,
            cropWidth: cropWidth,
            cropHeight: cropHeight,
            scaleWidth: cropWidth,
            scaleHeight: cropHeight
        )
    }
}

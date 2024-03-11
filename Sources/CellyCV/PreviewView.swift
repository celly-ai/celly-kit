import AVFoundation
import UIKit

/**
 The camera frame is displayed on this view.
 */
public final class PreviewView: UIView {
    
    public var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Layer expected is of type VideoPreviewLayer")
        }
        return layer
    }

    public var cgImage: CGImage? {
        didSet {
            self.syncQueue.sync {
                self.internalCGImage = cgImage
            }
        }
    }

    @objc
    public  func setNeedsDraw(displaylink _: CADisplayLink) {
        self.draw(.zero)
    }

    public override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    public override func draw(_: CGRect) {
        self.layer.contents = self.syncQueue.sync {
            self.internalCGImage
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    public func setup() {
        let displaylink = CADisplayLink(
            target: self,
            selector: #selector(self.setNeedsDraw(displaylink:))
        )

        displaylink.add(
            to: .current,
            forMode: .default
        )
    }
    
    // MARK: Private
    
    private var internalCGImage: CGImage?
    
    private let syncQueue = DispatchQueue(
        label: "Preview View Sync Queue",
        qos: .userInitiated,
        attributes: [],
        autoreleaseFrequency: .workItem
    )
    
}

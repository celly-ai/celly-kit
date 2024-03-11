import AVFoundation
import UIKit

public class PlayerView: UIView {
    public var playerLayer: AVPlayerLayer {
        guard let layer = layer as? AVPlayerLayer else {
            fatalError("Layer expected is of type AVPlayerLayer")
        }
        return layer
    }

    public override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    public var player: AVPlayer? {
        set {
            if let layer = layer as? AVPlayerLayer {
                layer.player = newValue
            }
        }
        get {
            if let layer = layer as? AVPlayerLayer {
                return layer.player
            }
            else {
                return nil
            }
        }
    }

    public func draw(cgImage: CGImage?) {
        self.layer.contents = cgImage
    }
}

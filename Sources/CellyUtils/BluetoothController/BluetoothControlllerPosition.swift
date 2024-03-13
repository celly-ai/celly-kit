import Foundation

public struct BluetoothControllerPosition {
    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    public let x: Float
    public let y: Float
    public let z: Float
}

extension BluetoothControllerPosition: Equatable {}

extension BluetoothControllerPosition: CustomStringConvertible {
    public var description: String {
        [self.x, self.y, self.z].map { String(format: "%0.1f", $0) }.joined(separator: ";")
    }
}

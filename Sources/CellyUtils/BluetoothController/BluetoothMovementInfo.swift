import CellyCore
import Foundation

public struct BluetoothMovementInfo {
    let type: MovementType
    let x: Float?
    let y: Float?
    let z: Float?
    let f: Float?
    let waitSignal: WaitSignalType?

    public enum MovementType: String {
        case absolute
        case relative
    }

    public enum WaitSignalType {
        case idle
        case throttle(Double)
        case debounce(Double)
        public static let `default`: WaitSignalType = .throttle(0.2)
    }

    public init(type: MovementType, x: Float? = nil, y: Float? = nil, z: Float? = nil, f: Float? = nil, waitSignal: WaitSignalType? = nil) {
        self.type = type
        self.x = x
        self.y = y
        self.z = z
        self.f = f
        self.waitSignal = waitSignal
    }
}

// MARK: CustomStringConvertible

extension BluetoothMovementInfo: CustomStringConvertible {
    public var description: String {
        let coords = [x, y, z]
            .compactMap { $0 }
            .map { String(format: "%0.3lf", $0) }
            .joined(separator: ",")
        return String(format: "(%@, %@, %@)", self.type.description, coords, self.waitSignal?.description ?? "-")
    }
}

extension BluetoothMovementInfo.MovementType: CustomStringConvertible {
    public var description: String {
        self.rawValue
    }
}

extension BluetoothMovementInfo.WaitSignalType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .idle: return "idle"
        case let .throttle(interval): return "throttle-\(interval)"
        case let .debounce(interval): return "debounce-\(interval)"
        }
    }
}

// MARK: Encodable

extension BluetoothMovementInfo.MovementType: Encodable {}

extension BluetoothMovementInfo.WaitSignalType: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .idle:
            try container.encode("idle")
        case let .throttle(interval):
            try container.encode(["throttle": interval])
        case let .debounce(interval):
            try container.encode(["debounce": interval])
        }
    }
}

extension BluetoothMovementInfo: Encodable {
    private enum EncodingKeys: String, CodingKey {
        case type
        case x
        case y
        case z
        case f
        case waitSignal
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EncodingKeys.self)
        try container.encode(self.type, forKey: .type)
        try container.encodeIfPresent(self.x, forKey: .x)
        try container.encodeIfPresent(self.y, forKey: .y)
        try container.encodeIfPresent(self.z, forKey: .z)
        try container.encodeIfPresent(self.f, forKey: .f)
        try container.encodeIfPresent(self.waitSignal, forKey: .waitSignal)
    }
}

// MARK: Decodable

extension BluetoothMovementInfo.MovementType: Decodable {}

extension BluetoothMovementInfo.WaitSignalType: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let dictionary = try? container.decode([String: Double].self) {
            if let interval = dictionary["throttle"] {
                self = .throttle(interval)
            }
            else if let interval = dictionary["debounce"] {
                self = .debounce(interval)
            }
            throw CellyError(message: "Unknown dictionary \(dictionary)")
        }
        else if let idle = try? container.decode(String.self), idle == "idle" {
            self = .idle
        }
        else {
            self = BluetoothMovementInfo.WaitSignalType.default
        }
    }
}

extension BluetoothMovementInfo: Decodable {
    private enum DecodingKeys: String, CodingKey {
        case type
        case x
        case y
        case z
        case f
        case waitSignal
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DecodingKeys.self)

        self.type = try container.decode(MovementType.self, forKey: .type)
        self.x = try container.decodeIfPresent(Float.self, forKey: .x)
        self.y = try container.decodeIfPresent(Float.self, forKey: .y)
        self.z = try container.decodeIfPresent(Float.self, forKey: .z)
        self.f = try container.decodeIfPresent(Float.self, forKey: .f)
        self.waitSignal = try container.decodeIfPresent(WaitSignalType.self, forKey: .waitSignal) ?? BluetoothMovementInfo.WaitSignalType.default
    }
}

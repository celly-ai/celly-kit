import Foundation

// MARK: - RestorableCodingKey

public protocol RestorableCodingKey: CustomDebugStringConvertible, CustomStringConvertible {}

// MARK: - RestorableEncoder

public protocol RestorableEncoder {
    func encode(value: Encodable, for key: RestorableCodingKey, jsonEncoder: JSONEncoder) throws
    func finish()
    var data: Data { get }
}

public class RestorableEncoderImpl: RestorableEncoder {
    let archiver: NSKeyedArchiver

    public var data: Data {
        self.archiver.encodedData
    }

    public init() {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.outputFormat = .binary
        self.archiver = archiver
    }

    public func encode(
        value: Encodable,
        for key: RestorableCodingKey,
        jsonEncoder: JSONEncoder
    ) throws {
        self.archiver.encode(
            try value.toJSON(jsonEncoder: jsonEncoder) as [AnyHashable: Any],
            forKey: key.description
        )
    }

    public func finish() {
        self.archiver.finishEncoding()
    }
}

// MARK: - RestorableDecoder

public protocol RestorableDecoder {
    func decode<T: Decodable>(of cls: T.Type, for key: RestorableCodingKey) throws -> T
    func finish()
}

public class RestorableDecoderImpl: RestorableDecoder {
    let unarchiver: NSKeyedUnarchiver

    public init(data: Data) throws {
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.decodingFailurePolicy = .setErrorAndReturn
        self.unarchiver = unarchiver
    }

    public func decode<T: Decodable>(of cls: T.Type, for key: RestorableCodingKey) throws -> T {
        guard
            let decodedObject = self.unarchiver.decodeObject(
                of: [NSDictionary.self, NSArray.self],
                forKey: key.description
            )
        else {
            throw CellyError(message: "Unable to restore \(key.description)")
        }
        if let error = unarchiver.error {
            throw error
        }
        guard let decodedDictionary = decodedObject as? [AnyHashable: Any] else {
            throw CellyError(
                message: "Unable to cast \(type(of: decodedObject)) to \(type(of: cls))"
            )
        }
        return try T.create(from: decodedDictionary)
    }

    public func finish() {
        self.unarchiver.finishDecoding()
    }
}

// MARK: - Restorable

/// Assumption: uniqueness of keys is the responsibility of the user. Two identical keys would result in overridden value and loss of data
public protocol Restorable {
    func apply(coder: RestorableEncoder) throws

    func restore(coder: RestorableDecoder) throws
}

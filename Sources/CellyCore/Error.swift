import Foundation

public class CellyError: Error, LocalizedError {
    public enum ErrorCode: Int {
        case aborted
        case unauthorized = 401
        case serialization = 413
        case undefined = -1
    }

    private var message: String

    public var errorDescription: String? {
        self.message
    }

    public var localizedDescription: String {
        self.message
    }

    public var code: ErrorCode?

    public init(message: String, code: ErrorCode? = nil) {
        self.message = message
        self.code = code
    }

    public init(message: String, status: Int) {
        self.message = message
        self.code = ErrorCode(rawValue: status) ?? .undefined
    }
}

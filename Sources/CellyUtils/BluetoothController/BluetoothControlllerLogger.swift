import CellyCore
import Foundation

public enum BluetoothControllerLoggerLevel: Int, Equatable, Comparable {
    public static func < (
        lhs: BluetoothControllerLoggerLevel,
        rhs: BluetoothControllerLoggerLevel
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    case none = 0
    case error = 1
    case warning = 2
    case notice = 3
    case trace = 4
    case debug = 5
    case `default` = 6
}

public protocol BluetoothControllerLogger {
    func log(_ items: Any...)
    func log(_ items: Any..., separator: String)
    func log(_ items: Any..., separator: String, terminator: String)
    func log(_ level: BluetoothControllerLoggerLevel, _ items: Any...)
    func log(_ level: BluetoothControllerLoggerLevel, _ items: Any..., separator: String)
    func log(
        _ level: BluetoothControllerLoggerLevel,
        _ items: Any...,
        separator: String,
        terminator: String
    )
}

public class BluetoothControllerLoggerImpl: BluetoothControllerLogger {
    private let level: BluetoothControllerLoggerLevel

    public init(level: BluetoothControllerLoggerLevel) {
        self.level = level
    }

    public func log(
        _ level: BluetoothControllerLoggerLevel,
        _ items: Any...,
        separator: String,
        terminator: String
    ) {
        guard self.level >= level else { return }

        let logString = items.map { String(describing: $0) }.joined(separator: separator)
            .appending(terminator)
        let logLevel = { () -> LogType in
            switch level {
            case .error: return .error
            case .notice: return .notice
            case .warning: return .warning
            case .default: return .default
            case .trace: return .trace
            case .debug: return .debug
            case .none: return .default
            }
        }()
        Log.log(logLevel, "%@", logString)
    }

    // MARK: - Wrappers

    public func log(_ level: BluetoothControllerLoggerLevel, _ items: Any...) {
        self.log(level, items, separator: " ")
    }

    public func log(_ level: BluetoothControllerLoggerLevel, _ items: Any..., separator _: String) {
        self.log(level, items, separator: " ", terminator: "\n")
    }

    public func log(_ items: Any...) {
        self.log(items, separator: " ")
    }

    public func log(_ items: Any..., separator: String) {
        self.log(items, separator: separator, terminator: "\n")
    }

    public func log(_ items: Any..., separator: String, terminator: String) {
        self.log(.default, items, separator: separator, terminator: terminator)
    }
}

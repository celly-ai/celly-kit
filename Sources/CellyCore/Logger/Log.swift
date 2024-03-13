import Foundation
import os
import OSLog

// TODO: OSLogMessage wrapper: privacy, formatting
public struct LogEntity {
    public let date: Date
    public let category: String
    public let composedMessage: String
}

public enum Log {
    private static let _subsystem = Bundle.main.bundleIdentifier ?? "undefined"

    private static let _app = Logger(subsystem: _subsystem, category: "App")
    private static let _pointsOfInterest = OSSignposter(
        subsystem: _subsystem,
        category: .pointsOfInterest
    )

    public static func log(
        _ type: LogType = .default,
        _ message: String,
        _ args: CVarArg...
    ) {
        let msg = String(format: message, arguments: args)
        switch type {
        case .default:
            self._app.log("\(msg, align: .none, privacy: .public)")
        case .info:
            self._app.info("\(msg, align: .none, privacy: .public)")
        case .notice:
            self._app.notice("\(msg, align: .none, privacy: .public)")
        case .debug:
            self._app.debug("\(msg, align: .none, privacy: .public)")
        case .trace:
            self._app.trace("\(msg, align: .none, privacy: .public)")
        case .warning:
            self._app.warning("\(msg, align: .none, privacy: .public)")
        case .error:
            self._app.error("\(msg, align: .none, privacy: .public)")
        case .fault:
            self._app.fault("\(msg, align: .none, privacy: .public)")
        case .critical:
            self._app.critical("\(msg, align: .none, privacy: .public)")
        }
    }

    @discardableResult
    public static func signpost<T>(
        _ name: StaticString,
        _ task: () throws -> T,
        _ message: String = "",
        _ args: CVarArg...
    ) rethrows -> T {
        try self._signposter().withIntervalSignpost(
            name,
            "\(String(format: message, arguments: args), align: .none, privacy: .public)",
            around: task
        )
    }

    public static func signpost(
        _: LogSignpostType,
        _ name: StaticString,
        _ message: String = "",
        _ args: CVarArg...
    ) {
        self._signposter().emitEvent(
            name,
            "\(String(format: message, arguments: args), align: .none, privacy: .public)"
        )
    }

    public static func export() async throws -> [LogEntity] {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let result = try export()
                continuation.resume(with: .success(result))
            }
            catch {
                continuation.resume(with: .failure(error))
            }
        }
    }

    public static func export() throws -> [LogEntity] {
        let store = try OSLogStore(scope: .currentProcessIdentifier) //  OSLogStore.local()
        let oneDayAgo = store.position(date: Date().addingTimeInterval(-3600 * 24))
        return try store
            .getEntries(at: oneDayAgo)
            .compactMap { $0 as? OSLogEntryLog }
            .filter { $0.subsystem == _subsystem }
            .map {
                LogEntity(date: $0.date, category: $0.category, composedMessage: $0.composedMessage)
            }
    }

    // MARK: Private

    private static func _signposter() -> OSSignposter {
        #if DEBUG
            let isSignPostEnabled = ProcessInfo.processInfo.environment["SIGNPOST_ENABLED"] != nil
            return isSignPostEnabled ? self._pointsOfInterest : .disabled
        #else
            return .disabled
        #endif
    }
}

public enum LogType {
    case `default`
    case notice
    case debug
    case trace
    case info
    case warning
    case error
    case fault
    case critical
}

public enum LogSignpostType {
    case begin
    case end
    case event
}

public struct LogInterpolation {
    init(literalCapacity _: Int, interpolationCount _: Int) {}
}

public enum LogPrivacy {
    case auto
    case `private`
    case sensetive
}

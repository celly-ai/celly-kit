import Foundation

public enum BluetoothControllerStatus: CustomStringConvertible {
    case none
    case ok(BluetoothControllerOutputInfo)
    case msg(BluetoothControllerOutputInfo, String)
    case idle(BluetoothControllerOutputInfo, BluetoothControllerPosition)
    case jog(BluetoothControllerOutputInfo, BluetoothControllerPosition)
    case alarm(BluetoothControllerOutputInfo, BluetoothControllerPosition)
    case ALARM(BluetoothControllerOutputInfo)
    case home(BluetoothControllerOutputInfo, BluetoothControllerPosition)
    case outputError(BluetoothControllerOutputInfo, Error)
    case inputError(Error?)

    public var description: String {
        switch self {
        case .none:
            return "none"
        case .ok:
            return "ok"
        case let .msg(_, msg):
            return msg
        case let .idle(_, pos):
            return "idle: \(pos.description)"
        case let .jog(_, pos):
            return "jog: \(pos.description)"
        case let .alarm(_, pos):
            return "alarm: \(pos.description)"
        case .ALARM:
            return "ALARM"
        case .home:
            return "home"
        case let .outputError(_, error):
            return "Output error: \(error.localizedDescription)"
        case let .inputError(error):
            return "Input error: \(error?.localizedDescription ?? "unknown")"
        }
    }
}

extension BluetoothControllerStatus: Equatable {
    public static func == (lhs: BluetoothControllerStatus, rhs: BluetoothControllerStatus) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.ok, .ok):
            return true
        case let (.home(lhsOutputInfo, lhsPos), .home(rhsOutputInfo, rhsPos)):
            return (lhsOutputInfo == rhsOutputInfo) && (lhsPos == rhsPos)
        case let (.msg(lhsOutputInfo, lhsMsg), .msg(rhsOutputInfo, rhsMsg)):
            return (lhsOutputInfo == rhsOutputInfo) && (lhsMsg == rhsMsg)
        case let (.idle(lhsOutputInfo, lhsPos), .idle(rhsOutputInfo, rhsPos)):
            return (lhsOutputInfo == rhsOutputInfo) && (lhsPos == rhsPos)
        case let (.jog(lhsOutputInfo, lhsPos), .jog(rhsOutputInfo, rhsPos)):
            return (lhsOutputInfo == rhsOutputInfo) && (lhsPos == rhsPos)
        case let (.alarm(lhsOutputInfo, lhsPos), .alarm(rhsOutputInfo, rhsPos)):
            return (lhsOutputInfo == rhsOutputInfo) && (lhsPos == rhsPos)
        case let (.outputError(lhsOutputInfo, lhsError), .outputError(rhsOutputInfo, rhsError)):
            return (lhsOutputInfo == rhsOutputInfo) &&
                (lhsError.localizedDescription == rhsError.localizedDescription)
        case let (.inputError(lhsError), .inputError(rhsError)):
            return (lhsError?.localizedDescription == rhsError?.localizedDescription)
        case (_, _):
            return false
        }
    }
}

// Equatable only my cases
public func ~= (lhs: BluetoothControllerStatus, rhs: BluetoothControllerStatus) -> Bool {
    switch (lhs, rhs) {
    case (.none, .none):
        return true
    case (.ok, .ok):
        return true
    case (.home, .home):
        return true
    case (.msg, .msg):
        return true
    case (.idle, .idle):
        return true
    case (.jog, .jog):
        return true
    case (.alarm, .alarm):
        return true
    case (.outputError, .outputError):
        return true
    case (.inputError, .inputError):
        return true
    case (_, _):
        return false
    }
}

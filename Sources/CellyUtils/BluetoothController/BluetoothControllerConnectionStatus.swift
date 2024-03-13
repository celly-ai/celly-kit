import Foundation

public enum BluetoothControllerConnectionStatus {
    case connected
    case scanning
    case disconnected
    case failure(Error?)
    public var description: String {
        switch self {
        case let .failure(error):
            return error?.localizedDescription ?? "Unknown error"
        case .connected:
            return "Connected"
        case .disconnected:
            return "Disconnected"
        case .scanning:
            return "Scanning"
        }
    }
}

extension BluetoothControllerConnectionStatus: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.connected, .connected):
            return true
        case (.failure, .failure):
            return true
        case (.disconnected, .disconnected):
            return true
        case (.scanning, .scanning):
            return true
        default:
            return false
        }
    }
}

import Foundation

public protocol CellyGRBLController {
    /// Converts  BluetoothMovementInfo to jog command string
    func movement2Jog(
        _ movementInfo: BluetoothMovementInfo
    ) -> String?
}

public final class CellyGRBLControllerImpl: CellyGRBLController {
    public init() {}
    public func movement2Jog(
        _ movementInfo: BluetoothMovementInfo
    ) -> String? {
        var cmd = ["$J=G21"]
        switch movementInfo.type {
        case .absolute: cmd.append("G90")
        case .relative: cmd.append("G91")
        }
        if let x = movementInfo.x {
            cmd.append(String(format: "X%.2lf", x))
        }
        if let y = movementInfo.y {
            cmd.append(String(format: "Y%.2lf", y))
        }
        if let z = movementInfo.z {
            cmd.append(String(format: "Z%.2lf", z))
        }
        let f = movementInfo.f ?? 3000
        cmd.append(String(format: "F%.0lf", f))
        cmd.append("\n")
        return cmd.joined()
    }
}

import CellyCore
import Foundation

public struct BluetoothControllerOutputInfo {
    let rawString: String
    let characteristicUUID: String
}

extension BluetoothControllerOutputInfo: Equatable {}

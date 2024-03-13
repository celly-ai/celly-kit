import Combine
import Foundation

public protocol BluetoothController {
    var position: BluetoothControllerPosition { get }
    var jogDate: Date { get }
    var connectionStatusSubject: CurrentValueSubject<BluetoothControllerConnectionStatus, Never> {
        get
    }
    var statusSubject: CurrentValueSubject<BluetoothControllerStatus, Never> { get }

    func configure(_ config: BluetoothControllerConfig)

    @discardableResult
    func jog(_ movementInfo: BluetoothMovementInfo) async throws -> BluetoothControllerStatus
    @discardableResult
    func home(postHommingStep: Bool) async throws -> BluetoothControllerStatus
    func unlock() throws
    func reset() throws
    func abort() throws
    func connect()
    func disconnect()
    func send(text: String) throws

    /// Legacy log routines
    func jogAsync(_ movementInfo: BluetoothMovementInfo?) throws
    func jogAndWaitIdlePromise(_ movementInfo: BluetoothMovementInfo)
        -> AnyPublisher<BluetoothControllerStatus, Never>
    func jogAndWaitOkSync(_ movementInfo: BluetoothMovementInfo) throws
    func jogAndWaitIdleSync(_ movementInfo: BluetoothMovementInfo) throws
    func homePromise(postHommingStep: Bool) -> AnyPublisher<BluetoothControllerStatus, Never>
    func abortSync() throws
}

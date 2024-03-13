import CellyCore
import Combine
import CoreBluetooth
import Foundation
import SwiftUI

private let QUICK_FIX_21_06_2022_STRING = true

private enum MotorControllerConfiguration {
    static let peripheralName = "celly_01"
    static let serviceUUID = CBUUID(string: "FFE0")
}

public protocol BluetoothControllerEnvironment {
    var skipHomingEnabled: Bool { get }
}

// Separate Bluetooth and Motor Controllers
public class BluetoothControllerImpl: NSObject, BluetoothController {
    fileprivate var manager: CBCentralManager!
    fileprivate var peripheral: CBPeripheral?
    fileprivate var characteristic: CBCharacteristic?
    fileprivate var bluetoothLogger: BluetoothControllerLogger?
    fileprivate var outputParser: BluetoothControllerOutputParser
    fileprivate let environment: BluetoothControllerEnvironment
    fileprivate let grblController: CellyGRBLController

    // Timers
    fileprivate var statusPollingDispatchTimer: DispatchSourceTimer
    fileprivate var movePollingDispatchTimer: DispatchSourceTimer
    fileprivate var movePollingDispatchTimerState: MovePollingDispatchTimerState; enum MovePollingDispatchTimerState {
        case suspended
        case resumed
    }

    // Motor Controller
    public var position: BluetoothControllerPosition {
        self.correct(self._position.value)
    }
    // Calculation corrected pos for Z coord (inertion added)
    private var lastThreePositions = [BluetoothControllerPosition]()
    private var lastThreeTimes = [Double]()
    private var lastControllerPosition: BluetoothControllerPosition = .init(x: 0, y: 0, z: 0)
    private var lastControllerPositionTime = CFAbsoluteTimeGetCurrent()
    func correct(_ position: BluetoothControllerPosition) -> BluetoothControllerPosition {
        guard lastThreePositions.count >= 3, lastThreeTimes.count >= 3 else {
            lastThreePositions.append(position)
            lastThreeTimes.append(CFAbsoluteTimeGetCurrent())
            return position
        }
        
        var newPosition: BluetoothControllerPosition
        if position == lastControllerPosition {
            let t = (CFAbsoluteTimeGetCurrent() - lastControllerPositionTime) < 0.1 ? (CFAbsoluteTimeGetCurrent() - lastControllerPositionTime) : 0.1
            let dz = abs(lastThreePositions[2].z - lastThreePositions[0].z) < 0.5 ? (lastThreePositions[2].z - lastThreePositions[0].z) : 0
            let dt = (lastThreeTimes[2] - lastThreeTimes[0]) < 1.0 ? Float((lastThreeTimes[2] - lastThreeTimes[0])):1.0
            let v = dz / dt
            newPosition = .init(x: position.x, y: position.y, z: position.z + v*Float(t))
        } else {
            lastThreePositions.append(position)
            lastThreeTimes.append(CFAbsoluteTimeGetCurrent())
            newPosition = .init(x: position.x, y: position.y, z: position.z)
            lastControllerPosition = position
            lastControllerPositionTime = CFAbsoluteTimeGetCurrent()
        }
        
        if lastThreePositions.count > 3 {
            lastThreePositions.removeFirst()
        }
        if lastThreeTimes.count > 3 {
            lastThreeTimes.removeFirst()
        }
        
        return newPosition
    }

    public var jogDate: Date

    private let _position: Atomic<BluetoothControllerPosition>
    private var motorInitiatedMovementDate: Date?

    private var config: BluetoothControllerConfig
    // START
    // TODO: Refactor
    private var jogNoChangeCoordinateLimit: Int
    private var jogNoChangeCoordinateCounter: Int
    private var noChangePos: BluetoothControllerPosition
    private var lastAbortDate: Date
    private var lastJogAsyncDate: Date
    // END

    public var connectionStatusSubject: CurrentValueSubject<BluetoothControllerConnectionStatus, Never>
    public var statusSubject: CurrentValueSubject<BluetoothControllerStatus, Never>
    fileprivate var cancellableSet: Set<AnyCancellable>

    // START
    // TODO: Refactor
    fileprivate var moveSubject: PassthroughSubject<String, Never>
    fileprivate var moveSubsctiption: AnyCancellable?
    fileprivate var moveAborted: Atomic<Bool>
    // END

    // Workaround
    var homingInitiatedDate: Atomic<Date?>
    //

    public init(
        config: BluetoothControllerConfig,
        bluetoothLogger: BluetoothControllerLogger?,
        environment: BluetoothControllerEnvironment,
        grblController: CellyGRBLController,
        outputParser: BluetoothControllerOutputParser,
        polling: Bool = true
    ) {
        self.outputParser = outputParser
        self.connectionStatusSubject = CurrentValueSubject(.disconnected)
        self.statusSubject = CurrentValueSubject(.none)
        self.environment = environment
        self.bluetoothLogger = bluetoothLogger
        self.cancellableSet = Set<AnyCancellable>()
        self.manager = CBCentralManager()
        self.grblController = grblController
        self.config = config
        self.statusPollingDispatchTimer = DispatchSource
            .makeTimerSource(queue: DispatchQueue.global(qos: .background))
        self.movePollingDispatchTimer = DispatchSource
            .makeTimerSource(queue: DispatchQueue.global(qos: .background))
        // START
        // TODO: Refactor
        self.jogNoChangeCoordinateLimit = 5
        self.jogNoChangeCoordinateCounter = 0
        self.noChangePos = .init(x: 0, y: 0, z: 0)
        self.lastAbortDate = Date.distantPast
        self.lastJogAsyncDate = Date.distantPast
        self.homingInitiatedDate = Atomic(nil)
        self.jogDate = Date.distantPast
        self._position = Atomic(.init(x: 0, y: 0, z: 0))
        self.moveAborted = Atomic(false)
        self.moveSubject = PassthroughSubject<String, Never>()
        self.movePollingDispatchTimerState = .suspended
        self.statusSubject = CurrentValueSubject(.none)
        // END
        super.init()
        self.manager.delegate = self
        // START: STATUS OBSERVING
        self.setupStatusObserving(
            outputParset: self.outputParser,
            cancellableSet: &self.cancellableSet
        ) { [weak self] status in
            guard let self = self else { return }
            if let homingInitiatedDate = self.homingInitiatedDate.value {
                guard Date().timeIntervalSince(homingInitiatedDate) > 3 else {
                    return
                }
                self.homingInitiatedDate.mutate { $0 = nil }
            }
            switch status {
            case let .idle(_, pos):
                self._position.mutate { $0 = pos }
            case let .jog(_, pos):
                self._position.mutate { $0 = pos }
            case let .alarm(_, pos):
                self._position.mutate { $0 = pos }
            case let .home(_, pos):
                self._position.mutate { $0 = pos }
            default:
                break
            }
            self.statusSubject.send(status)
        }
        // EMD
        // START: POLLING
        if polling {
            self.setupPolling(
                dispatchTimer: self.statusPollingDispatchTimer,
                repeating: .milliseconds(50),
                leeway: .never
            ) { [weak self] in
                if case .disconnected = self?.connectionStatusSubject.value { return }
                try? self?.send(text: "?")
                guard let self = self else { return }
                if self.jogNoChangeCoordinateCounter == 0 {
                    self.noChangePos = self.position
                }
                else if self.noChangePos != self.position {
                    self.jogNoChangeCoordinateCounter = 0
                }
            }
        }
        // END
        self.connectionStatusSubject.sink { status in
            self.bluetoothLogger?.log(.notice, "bluetooth-controller | connection ", status)
            switch status {
            case .disconnected:
                self.connect()
            default:
                break
            }
        }.store(in: &self.cancellableSet)
    }

    public func configure(_ config: BluetoothControllerConfig) {
        self.config = config
    }

    public func unlock() throws {
        self.bluetoothLogger?.log(.notice, "bluetooth-controller | grbl | unlocking")
        try self.send(
            peripheral: self.peripheral,
            characteristic: self.characteristic,
            text: "$X\n"
        )
    }

    func resetZero() throws {
        self.bluetoothLogger?.log(.notice, "bluetooth-controller | grbl | reset-zero-coordinates")
        try self.send(
            peripheral: self.peripheral,
            characteristic: self.characteristic,
            text: "G10 P0 L20 X0 Y0 Z0\n"
        )
    }

    public func reset() throws {
        self.bluetoothLogger?.log(.notice, "bluetooth-controller | grbl | reseting")
        try self.send(
            peripheral: self.peripheral,
            characteristic: self.characteristic,
            data: Data([0x18])
        )
        sleep(1)
    }

    public func abort() throws {
        if Date().timeIntervalSince(self.lastAbortDate) < 0.25 {
            self.bluetoothLogger?.log(.trace, "bluetooth-controller | grbl | abort-throttling")
            usleep(200_000)
        }
        self.bluetoothLogger?.log(.debug, "bluetooth-controller | grbl  | joggling-abort")
        self.lastAbortDate = Date()
        try self.send(
            peripheral: self.peripheral,
            characteristic: self.characteristic,
            data: Data([0x85])
        )
    }

    public func home(postHommingStep: Bool) async throws -> BluetoothControllerStatus {
        try await withCheckedThrowingContinuation { continuation in
            self.homePromise(postHommingStep: postHommingStep)
                .sink { completion in
                    switch completion {
                    case .finished: break
                    case .failure: break
                    }
                } receiveValue: { status in
                    continuation.resume(returning: status)
                }
                .store(in: &self.cancellableSet)
        }
    }

    public func jog(_ movementInfo: BluetoothMovementInfo) async throws -> BluetoothControllerStatus {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let promise = try { () -> AnyPublisher<BluetoothControllerStatus, Never> in
                    switch movementInfo.waitSignal {
                    case .idle:
                        return self.jogAndWaitIdlePromise(movementInfo)
                    case .throttle:
                        fatalError("no-imp")
                    case .debounce:
                        fatalError("no-imp")
                    default:
                        try self._jog(movementInfo)
                        return Just(self.statusSubject.value).eraseToAnyPublisher()
                    }
                }()
                promise
                    .sink { completion in
                        switch completion {
                        case .finished: break
                        case .failure: break
                        }
                    } receiveValue: { status in
                        continuation.resume(returning: status)
                    }
                    .store(in: &self.cancellableSet)
            }
            catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: Legacy

    public func homePromise(postHommingStep: Bool) -> AnyPublisher<BluetoothControllerStatus, Never> {
        if self.environment.skipHomingEnabled {
            return Just(self.statusSubject.value).eraseToAnyPublisher()
        }
        try? self._home()
        try? self.resetZero() // FIXME: Move after waiting for idle
        let homingConfig = self.config.homingConfig
        return self.waitingForIdle()
            .flatMap { _ in
                postHommingStep ?
                    self
                    .jogAndWaitIdlePromise(.init(
                        type: .absolute,
                        x: homingConfig.x,
                        y: homingConfig.y,
                        z: homingConfig.z,
                        f: homingConfig.f
                    )) // post-homing step
                    : Just(self.statusSubject.value).eraseToAnyPublisher()
            }
            .setFailureType(to: CellyError.self)
            .timeout(60, scheduler: RunLoop.main, customError: {
                CellyError(message: "Post homing timeout")
            })
            .replaceError(with: self.statusSubject.value)
            .eraseToAnyPublisher()
    }

    public func abortSync() throws {
        let sema = DispatchSemaphore(value: 0)
        let cancellable = self.abortPromise()
            .sink { _ in
                sema.signal()
            }
        let result = sema.wait(wallTimeout: .now() + .seconds(1))
        self.bluetoothLogger?.log(
            .debug,
            "bluetooth-controller | grbl | abort-sync ",
            String(describing: result)
        )
        switch result {
        case .success:
            break
        case .timedOut:
            cancellable.cancel()
        }
    }

    func abortPromise() -> AnyPublisher<BluetoothControllerStatus, Never> {
        let statusSubject = self.statusSubject
        let currentStatus = statusSubject.value
        let scheduler = RunLoop.main
        try? self.abort()
        return statusSubject
            .first { (status: BluetoothControllerStatus) -> (Bool) in
                currentStatus ~= status
            }
            .setFailureType(to: CellyError.self)
            .timeout(2, scheduler: scheduler, customError: {
                CellyError(message: "Abort timeout")
            })
            .replaceError(with: self.statusSubject.value)
            .eraseToAnyPublisher()
    }

    public func jogAsync(_ movementInfo: BluetoothMovementInfo?) throws {
        guard let movementInfo = movementInfo else { return }
        switch movementInfo.waitSignal {
        case .none:
            assertionFailure("Used jogPromise without wait-signal")
        case .idle:
            fatalError("no-imp")
        case let .debounce:
            fatalError("no-imp")
        case let .throttle(interval):
            let interval1 = Date().timeIntervalSince(self.lastJogAsyncDate)
            guard interval1 > Double(interval) else {
                return
            }
            self.lastJogAsyncDate = Date()
            Log.log(.debug, "virtual-pad | x\(movementInfo.x ?? 0), y\(movementInfo.y ?? 0), z\(movementInfo.z ?? 0)")
            try self._jog(movementInfo)
        }
    }

    public func jogAndWaitOkSync(_ movementInfo: BluetoothMovementInfo) throws {
        let sema = DispatchSemaphore(value: 0)
        let cancellable = self.statusSubject
            .first { (status: BluetoothControllerStatus) -> (Bool) in
                if case BluetoothControllerStatus.idle = status {
                    return true
                }
                return false
            }
            .map { [weak self] _ in
                try? self?._jog(movementInfo)
            }
            .flatMap { _ in self.waitingForOk() }
            .setFailureType(to: CellyError.self)
            .timeout(20, scheduler: RunLoop.main, customError: {
                self.bluetoothLogger?.log(
                    .error,
                    "bluetooth-controller | grbl | joggling-wait-ok-promise-timeout"
                )
                return CellyError(message: "Joggling promise timeout")
            })
            .replaceError(with: self.statusSubject.value)
            .eraseToAnyPublisher()
            .sink { _ in
                sema.signal()
            }
        let result = sema.wait(wallTimeout: .now() + .seconds(20))
        self.bluetoothLogger?.log(
            .debug,
            "bluetooth-controller | grbl | jog-and-wait-ok-sync ",
            String(describing: result)
        )
        switch result {
        case .success:
            break
        case .timedOut:
            cancellable.cancel()
        }
    }

    public func jogAndWaitIdleSync(_ movementInfo: BluetoothMovementInfo) throws {
        let sema = DispatchSemaphore(value: 0)
        let cancellable = self.jogAndWaitIdlePromise(movementInfo)
            .sink { _ in
                sema.signal()
            }
        let result = sema.wait(wallTimeout: .now() + .seconds(60))
        self.bluetoothLogger?.log(
            .debug,
            "bluetooth-controller | grbl | jog-and-wait-idle-sync ",
            String(describing: result)
        )
        switch result {
        case .success:
            break
        case .timedOut:
            cancellable.cancel()
        }
    }

    public func jogAndWaitIdlePromise(_ movementInfo: BluetoothMovementInfo) -> AnyPublisher<BluetoothControllerStatus, Never> {
        self.statusSubject
            .first { (status: BluetoothControllerStatus) -> (Bool) in
                if case BluetoothControllerStatus.idle = status {
                    return true
                }
                return false
            }
            .map { [weak self] _ in
                try? self?._jog(movementInfo)
            }
            .flatMap { _ in self.waitingForOk() }
            .flatMap { _ in self.waitingForJoggling() }
            .flatMap { _ in self.waitingForIdle() }
            .setFailureType(to: CellyError.self)
            .timeout(60, scheduler: RunLoop.main, customError: {
                self.bluetoothLogger?.log(
                    .error,
                    "bluetooth-controller | grbl | joggling-wait-idle-promise-timeout"
                )
                return CellyError(message: "Joggling-wait-idle promise timeout")
            })
            .replaceError(with: self.statusSubject.value)
            .eraseToAnyPublisher()
    }

    // MARK: Private

    private func waitingForOk() -> AnyPublisher<BluetoothControllerStatus, Never> {
        let scheduler = RunLoop.main
        return self.statusSubject.eraseToAnyPublisher()
            .first { (status: BluetoothControllerStatus) -> (Bool) in
                if case BluetoothControllerStatus.ok = status {
                    return true
                }
                return false
            }
            .eraseToAnyPublisher()
            .setFailureType(to: CellyError.self)
            .timeout(0.5, scheduler: scheduler, customError: {
                CellyError(message: "waitingForOk timeout")
            })
            .replaceError(with: self.statusSubject.value)
            .eraseToAnyPublisher()
    }

    private func waitingForJoggling() -> AnyPublisher<BluetoothControllerStatus, Never> {
        let scheduler = RunLoop.main
        return self.statusSubject.eraseToAnyPublisher()
            .first { (status: BluetoothControllerStatus) -> (Bool) in
                switch status {
                case .jog:
                    return true
                default:
                    break
                }
                return false
            }
            .eraseToAnyPublisher()
            .setFailureType(to: CellyError.self)
            .timeout(2.0, scheduler: scheduler, customError: {
                CellyError(message: "Joggling timeout")
            })
            .replaceError(with: self.statusSubject.value)
            .eraseToAnyPublisher()
    }

    private func waitingForIdle() -> AnyPublisher<BluetoothControllerStatus, Never> {
        let scheduler = RunLoop.main
        let timeout: RunLoop.SchedulerTimeType.Stride = 60
        return self.statusSubject.eraseToAnyPublisher()
            .first { (status: BluetoothControllerStatus) -> (Bool) in
                if case BluetoothControllerStatus.idle = status {
                    return true
                }
                return false
            }
            .eraseToAnyPublisher()
            .setFailureType(to: CellyError.self)
            .timeout(timeout, scheduler: scheduler, customError: {
                CellyError(message: "Waiting for idle promise timeout")
            })
            .replaceError(with: self.statusSubject.value)
            .eraseToAnyPublisher()
    }

    private func send(
        peripheral: CBPeripheral?,
        characteristic: CBCharacteristic?,
        text: String
    ) throws {
        // START: QUICK_FIX_21_06_2022_STRING
        if QUICK_FIX_21_06_2022_STRING {
            func splitStringIntoSubstrings(_ inputString: String, substringLength: Int) -> [String] {
                var substrings = [String]()
                var currentIndex = inputString.startIndex

                while currentIndex < inputString.endIndex {
                    let nextIndex = inputString.index(currentIndex, offsetBy: substringLength, limitedBy: inputString.endIndex) ?? inputString
                        .endIndex
                    let substring = String(inputString[currentIndex..<nextIndex])
                    substrings.append(substring)
                    currentIndex = nextIndex
                }

                return substrings
            }

            if text != "?" {
                //self.bluetoothLogger?.log(.debug, "BLE: ", text)
            }
            // var substrNumber = 0
            for substr in splitStringIntoSubstrings(text, substringLength: 20) {
                guard
                    let transmitdata = substr.data(using: .ascii)
                else {
                    throw CellyError(message: "Unable to encode \(text)", status: -1)
                }

                /* if substrNumber > 0 {
                     usleep(50_000)
                 }
                 substrNumber += 1 */
                try self.send(peripheral: peripheral, characteristic: characteristic, data: transmitdata)
            }
            return
        }
        // END
        guard
            let transmitdata = text.data(using: .ascii)
        else {
            throw CellyError(message: "Unable to encode \(text)", status: -1)
        }
        if text != "?" {
            self.bluetoothLogger?.log(.debug, String(
                format: "bluetooth-controller | sending | %@.%@, text %@, data: %@",
                peripheral?.name ?? "unknown",
                characteristic?.uuid.uuidString ?? "unknown",
                text, // .replacingOccurrences(of: "\n", with: "\\n"),
                String(
                    describing: transmitdata
                )
            ))
        }
        try self.send(peripheral: peripheral, characteristic: characteristic, data: transmitdata)
    }

    private func send(
        peripheral: CBPeripheral?,
        characteristic: CBCharacteristic?,
        data: Data
    ) throws {
        guard
            let peripheral = peripheral,
            let characteristic = characteristic
        else {
            throw CellyError(
                message: "Trying to send data before discovring peripheral with characteristic",
                status: -1
            )
        }
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
    }

    private func setupStatusObserving(
        outputParset _: BluetoothControllerOutputParser,
        cancellableSet: inout Set<AnyCancellable>,
        handler: @escaping (BluetoothControllerStatus)
            -> Void
    ) {
        self.outputParser.outputSubject
            .sink(receiveValue: handler)
            .store(in: &cancellableSet)
    }

    private func setupPolling(
        dispatchTimer: DispatchSourceTimer,
        repeating: DispatchTimeInterval,
        leeway: DispatchTimeInterval,
        handler: @escaping () -> Void
    ) {
        dispatchTimer.schedule(deadline: .now(), repeating: repeating, leeway: leeway)
        dispatchTimer.setEventHandler(handler: handler)
        dispatchTimer.resume()
    }

    private func setupMoveObservingIfNeeded(
        moveSubject: PassthroughSubject<String, Never>,
        statusSubject: CurrentValueSubject<
            BluetoothControllerStatus,
            Never
        >,
        cancellable: inout AnyCancellable?,
        handler: @escaping ((String, BluetoothControllerStatus)) -> Void
    ) {
        guard cancellable == nil else { return }
        cancellable = moveSubject
            .zip(statusSubject.eraseToAnyPublisher())
            // .combineLatest(statusSubject.eraseToAnyPublisher())
            .throttle(for: 1, scheduler: RunLoop.main, latest: true)
            .sink(receiveValue: handler)
    }

    public func send(text: String) throws {
        try self.send(peripheral: self.peripheral, characteristic: self.characteristic, text: text)
    }

    public func connect() {
        // self.manager.scanForPeripherals(withServices: [MotorControllerConfiguration.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        self.manager.scanForPeripherals(withServices: nil, options: nil)
    }

    public func disconnect() {
        guard let peripheral = peripheral else {
            return
        }
        self.bluetoothLogger?.log(.notice, "bluetooth-controller | grbl | disconnecting")
        self.manager.cancelPeripheralConnection(peripheral)
        self.connectionStatusSubject.send(.disconnected)
    }

    private func _jog(_ movementInfo: BluetoothMovementInfo) throws {
        self.jogDate = Date()
        self.jogNoChangeCoordinateCounter += 1
        if self.jogNoChangeCoordinateCounter >= self.jogNoChangeCoordinateLimit {
            self.bluetoothLogger?.log(
                .warning,
                "bluetooth-controller | grbl | jog-no-change-coordinate-counter"
            )
            try self.reset()
            self.jogNoChangeCoordinateCounter = 0
        }

        guard
            let jogglingCmd = self.grblController.movement2Jog(
                movementInfo
            )
        else {
            return
        }
        // check for out of the limits
        let hardLimit: Float = -1.9
        let xLimit: Float = 145
        let yLimit: Float = 25
        let zLimit: Float = 65
        var targetX: Float = movementInfo.x ?? 0
        var targetY: Float = movementInfo.y ?? 0
        var targetZ: Float = movementInfo.z ?? 0
        // Log.log(.debug,"bluetooth-controller | movementInfo.type %@", movementInfo.type)
        if movementInfo.type == .relative {
            Log.log(.debug, "bluetooth-controller | movementInfo == relative")
            targetX += self.position.x
            targetY += self.position.y
            targetZ += self.position.z
        }
        if
            (min(targetX, targetY, targetZ) <= hardLimit) ||
            (targetX >= xLimit) ||
            (targetY >= yLimit) ||
            (targetZ >= zLimit)
        {
            Log.log(
                .debug,
                "bluetooth-controller | jog | limit achieved, ignore | position (x=%3.3lf, y=%3.3lf, z=%3.3lf), movementInfo(%3.3lf, %3.3lf, %3.3lf)",
                self.position.x, self.position.y, self.position.z, movementInfo.x ?? 0, movementInfo.y ?? 0, movementInfo.z ?? 0
            )
        }
        else {
            self.bluetoothLogger?.log(
                .debug,
                "bluetooth-controller | grbl | joggling-moving ",
                jogglingCmd
            )
            try self.send(text: jogglingCmd)
        }
    }

    func _home() throws {
        self.bluetoothLogger?.log(.notice, "bluetooth-controller | grbl | homing")
        try self.send(
            peripheral: self.peripheral,
            characteristic: self.characteristic,
            text: "$H\n"
        )
        self.homingInitiatedDate.mutate { $0 = Date() }
        self.statusSubject.send(.home(
            .init(
                rawString: "<ios-inserted>",
                characteristicUUID: self.characteristic?.uuid.uuidString ?? "<nil>"
            ),
            self.position
        ))
    }
}

extension BluetoothControllerImpl: CBCentralManagerDelegate {
    // MARK: Monitoring the Central Manager’s State

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.bluetoothLogger?.log(
            "bluetooth-controller | central.state",
            central.stateDescription()
        )
        if central.state == .poweredOff {
            self.connectionStatusSubject.send(.disconnected)
        }
        if central.state == .poweredOn {
            self.connectionStatusSubject.send(.scanning)
            self.manager.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    // MARK: Discovering and Retrieving Peripherals

    public func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData _: [String: Any],
        rssi: NSNumber
    ) {
        let peripheralName = peripheral.name ?? "unknown"
        self.bluetoothLogger?
            .log(String(
                format: "discoved %@ with signal stregnth %ld",
                peripheralName,
                rssi.intValue
            ))
        if peripheralName == MotorControllerConfiguration.peripheralName {
            self.peripheral = peripheral
            self.peripheral?.delegate = self
            self.manager.stopScan()
            self.manager.connect(peripheral, options: nil)
            self.bluetoothLogger?.log(String(
                format: "%@.maximumWriteValueLengthWithResponse: %ld",
                peripheralName,
                peripheral.maximumWriteValueLength(for: .withResponse)
            ))
            self.bluetoothLogger?.log(String(
                format: "%@.maximumWriteValueLengthWithoutResponse: %ld",
                peripheralName,
                peripheral.maximumWriteValueLength(for: .withoutResponse)
            ))
        }
    }

    // MARK: Monitoring Connections with Peripherals

    public func centralManager(
        _: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        self.bluetoothLogger?.log("didConnect", peripheral.name ?? "unknown", separator: ". ")
        peripheral.discoverServices(nil)
    }

    public func centralManager(
        _: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        if let error = error {
            self.connectionStatusSubject.send(.failure(error))
        }
        self.bluetoothLogger?.log(
            .error,
            "didFailToConnect",
            peripheral.name ?? "unknown",
            error?.localizedDescription ?? "unknown error",
            separator: ". "
        )
    }

    public func centralManager(
        _: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        if let error = error {
            self.connectionStatusSubject.send(.failure(error))
        }
        self.connectionStatusSubject.send(.disconnected)
        self.bluetoothLogger?.log(
            "didDisconnectPeripheral",
            peripheral.name ?? "unknown",
            error?.localizedDescription ?? "no error",
            separator: ". "
        )
    }

    public func centralManager(
        _: CBCentralManager,
        connectionEventDidOccur event: CBConnectionEvent,
        for peripheral: CBPeripheral
    ) {
        self.bluetoothLogger?.log(
            "connectionEventDidOccur",
            peripheral.name ?? "unknown",
            event,
            separator: ". "
        )
    }

    // MARK: Monitoring the Central Manager’s Authorization

    public func centralManager(
        _: CBCentralManager,
        didUpdateANCSAuthorizationFor peripheral: CBPeripheral
    ) {
        self.bluetoothLogger?.log(
            "didUpdateANCSAuthorizationFor",
            peripheral.name ?? "uknown",
            separator: ". "
        )
    }
}

extension BluetoothControllerImpl: CBPeripheralDelegate {
    // MARK: Discovering Services

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        if let error = error {
            self.connectionStatusSubject.send(.failure(error))
        }
        self.bluetoothLogger?.log(
            "didDiscoverServices",
            peripheral.name ?? "uknown",
            String(describing: peripheral.services),
            error?.localizedDescription ?? "no error",
            separator: ". "
        )
        for service in peripheral.services ?? [] {
            let isNeededService = service.uuid.isEqual(MotorControllerConfiguration.serviceUUID)
            self.bluetoothLogger?.log(
                "service.uuid",
                service.uuid,
                "Checking",
                isNeededService,
                separator: ". "
            )
            guard isNeededService else { continue }
            peripheral.discoverCharacteristics(nil, for: service)
            peripheral.discoverIncludedServices(nil, for: service)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverIncludedServicesFor service: CBService,
        error: Error?
    ) {
        self.bluetoothLogger?.log(
            "didDiscoverIncludedServicesForService",
            peripheral.name ?? "uknown",
            String(describing: service.uuid),
            String(describing: service.includedServices),
            error?.localizedDescription ?? "no error",
            separator: ". "
        )
        for includedService in service.includedServices ?? [] {
            peripheral.discoverCharacteristics(nil, for: includedService)
            peripheral.discoverIncludedServices(nil, for: includedService)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverDescriptorsFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        self.bluetoothLogger?.log(
            "didDiscoverDescriptorsForCharacteristic",
            peripheral.name ?? "uknown",
            String(describing: characteristic.uuid),
            String(describing: characteristic.descriptors),
            error?.localizedDescription ?? "no error",
            separator: ". "
        )
    }

    // MARK: Discovering Characteristics and their Descriptors

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        self.bluetoothLogger?.log(
            "didDiscoverCharacteristicsForService",
            peripheral.name ?? "uknown",
            String(describing: service.uuid),
            String(describing: service.characteristics),
            error?.localizedDescription ?? "no error",
            separator: ". "
        )
        for characteristic in service.characteristics ?? [] {
            let isNeededCharacteristic = service.uuid
                .isEqual(MotorControllerConfiguration.serviceUUID)
            self.bluetoothLogger?.log(
                "characteristic.uuid",
                characteristic.uuid,
                "Checking",
                isNeededCharacteristic,
                separator: ". "
            )
            guard isNeededCharacteristic else { continue }
            self.characteristic = characteristic
            self.connectionStatusSubject.send(.connected)
            peripheral.setNotifyValue(true, for: characteristic)
            self.bluetoothLogger?.log(
                "setNotifyValueTrue",
                peripheral.name ?? "uknown",
                String(describing: characteristic),
                separator: ". "
            )
            peripheral.discoverDescriptors(for: characteristic)
        }
    }

    // MARK: Retrieving Characteristic and Descriptor Values

    // !!!
    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        self.bluetoothLogger?.log(
            "didUpdateValueForCharacteristic",
            peripheral.name ?? "uknown",
            String(describing: characteristic),
            error?.localizedDescription ?? "no error",
            separator: ". "
        )

        if let characteristicValue = characteristic.value {
            do {
                try self.outputParser.parse(
                    data: characteristicValue,
                    characteristicUUID: characteristic.uuid.uuidString
                )
            }
            catch {
                self.connectionStatusSubject.send(.failure(error))
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor descriptor: CBDescriptor,
        error: Error?
    ) {
        self.bluetoothLogger?.log(
            "didUpdateValueForDescriptor",
            peripheral.name ?? "uknown",
            String(describing: descriptor),
            error?.localizedDescription ?? "no error",
            separator: ". "
        )
    }

    // MARK: Writing Characteristic and Descriptor Values

    // !!!
    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        self.bluetoothLogger?.log(
            "didWriteValueForCharacteristic",
            peripheral.name ?? "uknown",
            String(describing: characteristic),
            error?.localizedDescription ?? "no error",
            separator: ". "
        )
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor descriptor: CBDescriptor,
        error: Error?
    ) {
        self.bluetoothLogger?.log(
            "didWriteValueForDescriptor",
            peripheral.name ?? "uknown",
            String(describing: descriptor),
            error?.localizedDescription ?? "no error",
            separator: ". "
        )
    }

    // !!!
    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        self.bluetoothLogger?.log(
            "peripheralIsReadyToSendWriteWithoutResponse",
            String(describing: peripheral),
            separator: ". "
        )
    }

    // MARK: Managing Notifications for a Characteristic’s Value

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        self.bluetoothLogger?.log(
            "didUpdateNotificationStateFor",
            peripheral.name ?? "uknown",
            String(describing: characteristic),
            error?.localizedDescription ?? "no error",
            separator: ". "
        )
    }

    // MARK: Retrieving a Peripheral’s RSSI Data

    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI number: NSNumber, error: Error?) {
        self.bluetoothLogger?.log(
            "peripheralDidReadRSSI",
            peripheral.name ?? "uknown",
            String(describing: number),
            error?.localizedDescription ?? "no error",
            separator: ". "
        )
    }

    // MARK: Monitoring Changes to a Peripheral’s Name or Services

    public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        self.bluetoothLogger?.log(
            "peripheralDidUpdateName",
            peripheral.name ?? "uknown",
            separator: ". "
        )
    }

    // MARK: Monitoring L2CAP Channels

    public func peripheral(
        _ peripheral: CBPeripheral,
        didOpen channel: CBL2CAPChannel?,
        error _: Error?
    ) {
        self.bluetoothLogger?.log(
            "peripheraldidOpenChannel",
            peripheral.name ?? "uknown",
            String(describing: channel),
            separator: ". "
        )
    }
}

extension CBCentralManager {
    func stateDescription() -> String {
        switch state {
        case .poweredOn: return "poweredOn"
        case .poweredOff: return "poweredOff"
        case .resetting: return "resetting"
        case .unauthorized: return "unauthorized"
        case .unsupported: return "unsupported"
        case .unknown: return "unknown"
        @unknown default:
            fatalError()
        }
    }
}

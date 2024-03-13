import CellyCore
import Combine
import Foundation

public protocol BluetoothControllerFakeEnvironment {
    var shouldSimulateMotorizedMovement: Bool { get }
    var shouldSimulateMotorizedAlarm: Bool { get }
}

public class BluetoothControllerFakeImpl: BluetoothController {
    public var position: BluetoothControllerPosition
    public var connectionStatusSubject: CurrentValueSubject<BluetoothControllerConnectionStatus, Never>
    public var statusSubject: CurrentValueSubject<BluetoothControllerStatus, Never>
    public var jogDate: Date

    private let environment: BluetoothControllerFakeEnvironment
    private let bluetoothLogger: BluetoothControllerLogger?
    private let grblController: CellyGRBLController

    private var jogNoChangeCoordinateLimit: Int
    private var jogNoChangeCoordinateCounter: Int
    private var noChangePos: BluetoothControllerPosition
    private var lastAbortDate: Date
    private var lastJogAsyncDate: Date

    public init(
        environment: BluetoothControllerFakeEnvironment,
        grblController: CellyGRBLController,
        bluetoothLogger: BluetoothControllerLogger?
    ) {
        self.bluetoothLogger = bluetoothLogger
        self.grblController = grblController
        self.environment = environment
        self.position = BluetoothControllerPosition(x: 0, y: 0, z: 0)
        self
            .connectionStatusSubject = CurrentValueSubject(
                BluetoothControllerConnectionStatus
                    .connected
            )
        self.statusSubject = CurrentValueSubject(BluetoothControllerStatus.idle(
            .init(rawString: "fake", characteristicUUID: "fake"),
            .init(x: 0, y: 0, z: 0)
        ))
        self.jogDate = Date.distantPast
        self.jogNoChangeCoordinateLimit = 5
        self.jogNoChangeCoordinateCounter = 0
        self.noChangePos = .init(x: 0, y: 0, z: 0)
        self.lastAbortDate = Date.distantPast
        self.lastJogAsyncDate = Date.distantPast
        if environment.shouldSimulateMotorizedMovement {
            self._simulateMovement()
        }
        if environment.shouldSimulateMotorizedAlarm {
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(3)) {
                let date = Date()
                while true {
                    if Int(Date().timeIntervalSince(date)) % 2 == 0 {
                        self.statusSubject
                            .send(BluetoothControllerStatus.alarm(.init(rawString: "fake", characteristicUUID: "fake"), .init(x: 0, y: 0, z: 0)))
                    }
                }
            }
        }
    }

    public func configure(_: BluetoothControllerConfig) {}

    public func connect() {}
    public func disconnect() {}
    public func unlock() throws {}
    public func home(postHommingStep _: Bool) async throws -> BluetoothControllerStatus {
        BluetoothControllerStatus.idle(
            .init(rawString: "fake", characteristicUUID: "fake"),
            .init(x: 0, y: 0, z: 0)
        )
    }

    public func jog(_ movementInfo: BluetoothMovementInfo) async throws -> BluetoothControllerStatus {
        try self._jog(movementInfo)
        return BluetoothControllerStatus.idle(
            .init(rawString: "fake", characteristicUUID: "fake"),
            .init(x: 0, y: 0, z: 0)
        )
    }

    public func jogAsync(_ movementInfo: BluetoothMovementInfo?) throws {
        guard let movementInfo = movementInfo else {
            Log.log(.debug, "virtual-pad | stopped")
            return
        }
        switch movementInfo.waitSignal {
        case .none:
            assertionFailure("Used jogPromise without wait-signal")
        case .idle:
            fatalError("no-imp")
        case .debounce:
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

    public func reset() throws {}
    public func abort() throws {}

    // MARK: Private

    private func _simulateMovement() {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
            self.position = .init(
                x: self.position.x + Float.random(in: 100...1000) / 744_801,

                y: self.position.y + Float.random(in: 100...1000) / 744_801,

                z: self.position.z + Float.random(in: 100...1000) / 744_801
            )
            self._simulateMovement()
        }
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
        self.bluetoothLogger?.log(.debug, "bluetooth-controller | grbl | jog ", movementInfo.x ?? 0, movementInfo.y ?? 0, movementInfo.z ?? 0)
        try self.send(text: jogglingCmd)
        // START: MOCKED MOVEMENT
        switch movementInfo.type {
        case .relative:
            self.position = .init(
                x: self.position.x + (movementInfo.x ?? 0),
                y: self.position.y + (movementInfo.y ?? 0),
                z: self.position.z + (movementInfo.z ?? 0)
            )
        case .absolute:
            self.position = .init(
                x: movementInfo.x ?? self.position.x,
                y: movementInfo.y ?? self.position.y,
                z: movementInfo.z ?? self.position.z
            )
        }
        self.bluetoothLogger?.log(.debug, "bluetooth-controller | grbl | pos  ", self.position.x, self.position.y, self.position.z)
        // END
    }

    public func send(text: String) throws {
        func splitStringIntoSubstrings(_ inputString: String, substringLength: Int) -> [String] {
            var substrings = [String]()
            var currentIndex = inputString.startIndex

            while currentIndex < inputString.endIndex {
                let nextIndex = inputString.index(currentIndex, offsetBy: substringLength, limitedBy: inputString.endIndex) ?? inputString.endIndex
                let substring = String(inputString[currentIndex..<nextIndex])
                substrings.append(substring)

                currentIndex = nextIndex
            }

            return substrings
        }
        var substrs = [String]()
        for substr in splitStringIntoSubstrings(text, substringLength: 20) {
            guard
                let transmitdata = substr.data(using: .ascii)
            else {
                throw CellyError(message: "Unable to encode \(text)", status: -1)
            }
            substrs.append(substr)
        }
        self.bluetoothLogger?.log(.debug, String(
            format: "bluetooth-controller-fake | sending | [ \"%@\" ]",
            substrs.joined(separator: " | ")
        ))
    }

    // MARK: Legacy

    public func jogAndWaitOkSync(_ movementInfo: BluetoothMovementInfo) throws {
        let sema = DispatchSemaphore(value: 0)
        let cancellable = self.jogPromise(movementInfo)
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

    public func homePromise(postHommingStep _: Bool) -> AnyPublisher<BluetoothControllerStatus, Never> {
        Just(BluetoothControllerStatus.idle(
            .init(rawString: "fake", characteristicUUID: "fake"),
            .init(x: 0, y: 0, z: 0)
        )).eraseToAnyPublisher()
    }

    public func abortSync() throws {}
    public func jogAndWaitIdlePromise(_: BluetoothMovementInfo)
        -> AnyPublisher<BluetoothControllerStatus, Never>
    {
        Just(BluetoothControllerStatus.idle(
            .init(rawString: "fake", characteristicUUID: "fake"),
            .init(x: 0, y: 0, z: 0)
        )).eraseToAnyPublisher()
    }

    func jogPromise(_ movementInfo: BluetoothMovementInfo)
        -> AnyPublisher<BluetoothControllerStatus, Never>
    {
        Future<BluetoothControllerStatus, Never> { [weak self] future in
            do {
                try self?._jog(movementInfo)
                future(.success(BluetoothControllerStatus.idle(
                    .init(rawString: "fake", characteristicUUID: "fake"),
                    .init(x: 0, y: 0, z: 0)
                )))
            }
            catch {
                assertionFailure(error.localizedDescription)
                return
            }
        }
        .eraseToAnyPublisher()
    }

    public func jogAndWaitIdleSync(_ movementInfo: BluetoothMovementInfo) throws {
        let sema = DispatchSemaphore(value: 0)
        let cancellable = self.jogPromise(movementInfo)
            .sink { _ in
                sema.signal()
            }
        let result = sema.wait(wallTimeout: .now() + .seconds(20))
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
}

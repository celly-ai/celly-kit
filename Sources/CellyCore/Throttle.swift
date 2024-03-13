import Foundation

public enum ThrottlerAssembly {
    public enum ThrottleType {
        case delay(TimeInterval)
        case fps(Int)
    }

    public static func assembly(
        type: ThrottleType,
        queue: DispatchQueue = DispatchQueue.main
    ) -> Throttler {
        switch type {
        case let .delay(minimumDelay):
            return ThrottlerDelay(
                minimumDelay: minimumDelay,
                queue: queue
            )
        case let .fps(fps):
            return ThrottlerFPS(
                fps: fps,
                queue: queue
            )
        }
    }
}

public protocol Throttler {
    func throttle(_ block: @escaping () -> Void)
}

public class ThrottlerDelay: Throttler {
    private var workItem: DispatchWorkItem
    private var previousDispatch: Date
    private let queue: DispatchQueue
    private let minimumDelay: TimeInterval
    private let isAsynced: Bool

    public init(
        minimumDelay: TimeInterval,
        queue: DispatchQueue = DispatchQueue.main,
        isAsynced: Bool = true
    ) {
        self.minimumDelay = minimumDelay
        self.queue = queue
        self.previousDispatch = Date.distantPast
        self.workItem = DispatchWorkItem(block: {})
        self.isAsynced = isAsynced
    }

    deinit {
        workItem.cancel()
    }

    public func throttle(_ block: @escaping () -> Void) {
        guard Date().timeIntervalSince(self.previousDispatch) >= self.minimumDelay else {
            return
        }
        self.previousDispatch = Date()
        self.workItem = DispatchWorkItem {
            block()
        }
        if self.isAsynced {
            self.queue.async(execute: self.workItem)
        }
        else {
            self.queue.sync(execute: self.workItem)
        }
    }
}

public class ThrottlerFPS: Throttler {
    private var workItem: DispatchWorkItem
    private let queue: DispatchQueue
    private let fps: Int
    private var framesCounter: Int
    private let isAsynced: Bool

    public init(
        fps: Int,
        queue: DispatchQueue = DispatchQueue.main,
        isAsynced: Bool = true

    ) {
        self.fps = fps
        self.framesCounter = 0
        self.queue = queue
        self.workItem = DispatchWorkItem(block: {})
        self.isAsynced = isAsynced
    }

    deinit {
        workItem.cancel()
    }

    public func throttle(_ block: @escaping () -> Void) {
        self.framesCounter += 1
        guard self.framesCounter % self.fps == 0 else {
            return
        }
        self.workItem = DispatchWorkItem {
            block()
        }
        if self.isAsynced {
            self.queue.async(execute: self.workItem)
        }
        else {
            self.queue.sync(execute: self.workItem)
        }
    }
}

import Foundation

public final class Atomic<A> {
    private let queue = DispatchQueue(
        label: "amin.benarieb.Celly-Atomic",
        attributes: .concurrent
    )
    private var _value: A
    private let didSet: DidSetCompletion?; public typealias DidSetCompletion = (A) -> Void

    public init(_ value: A, didSet: DidSetCompletion? = nil) {
        self._value = value
        self.didSet = didSet
    }

    public var value: A { self.queue.sync { self._value } }

    public func mutate(_ transform: (inout A) -> Void) {
        self.queue.sync(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            transform(&self._value)
            self.didSet?(self._value)
        }
    }
}

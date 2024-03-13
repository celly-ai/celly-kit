import Foundation

precedencegroup HigherThanAssignmentPrecedence {
    associativity: left
    higherThan: AssignmentPrecedence
}

infix operator =>: HigherThanAssignmentPrecedence

@discardableResult
public func => <T: AnyObject>(object: T, transform: (T) throws -> Void) rethrows -> T {
    try transform(object)
    return object
}

@discardableResult
public func => <T: AnyObject>(object: T, transform: (T) -> Void) -> T {
    transform(object)
    return object
}

public extension Optional where Wrapped: AnyObject {
    @discardableResult
    static func => (object: Self, transform: (Wrapped) throws -> Void) rethrows -> Self {
        if case let .some(wrapped) = object {
            try transform(wrapped)
            return wrapped
        }
        return .none
    }

    @discardableResult
    static func => (expression: Self, transform: (Wrapped) -> Void) -> Self {
        if case let .some(wrapped) = expression {
            transform(wrapped)
            return wrapped
        }
        return .none
    }
}

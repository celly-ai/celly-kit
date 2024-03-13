import Foundation

public extension Bool {
    static func ^ (left: Bool, right: Bool) -> Bool {
        left != right
    }
}

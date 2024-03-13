import Foundation

public protocol Loggable {
    func asDictionary() -> [String: Any]
}

public extension Loggable {
    func asDictionary() -> [String: Any] {
        let mirror = Mirror(reflecting: self)
        let dict = Dictionary(
            uniqueKeysWithValues: mirror.children.lazy
                .map { (label: String?, value: Any) -> (String, Any)? in
                    guard let label = label else { return nil }
                    return (label, value)
                }.compactMap { $0 }
        )
        return dict
    }
}

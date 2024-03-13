import Foundation

public extension Array {
    /// Creates a new array from the bytes of the given unsafe data.
    ///
    /// - Warning: The array's `Element` type must be trivial in that it can be copied bit for bit
    ///     with no indirection or reference-counting operations; otherwise, copying the raw bytes in
    ///     the `unsafeData`'s buffer to a new array returns an unsafe copy.
    /// - Note: Returns `nil` if `unsafeData.count` is not a multiple of
    ///     `MemoryLayout<Element>.stride`.
    /// - Parameter unsafeData: The data containing the bytes to turn into an array.
    init?(unsafeData: Data) {
        guard unsafeData.count % MemoryLayout<Element>.stride == 0 else { return nil }
        #if swift(>=5.0)
            self = unsafeData.withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
        #else
            self = unsafeData.withUnsafeBytes {
                .init(UnsafeBufferPointer<Element>(
                    start: $0,
                    count: unsafeData.count / MemoryLayout<Element>.stride
                ))
            }
        #endif // swift(>=5.0)
    }

    func toDictionary<Key: Hashable>(with selectKey: (Iterator.Element) -> Key)
        -> [Key: Iterator.Element]
    {
        var dict: [Key: Iterator.Element] = [:]
        for element in self {
            dict[selectKey(element)] = element
        }
        return dict
    }

    func appending(_ newElement: Element) -> [Element] {
        self + [newElement]
    }

    func appending(contentsOf sequence: [Element]) -> [Element] {
        self + sequence
    }

    // https://www.hackingwithswift.com/example-code/language/how-to-split-an-array-into-chunks
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

import Foundation

public final class WeakSet<T> {
    private let storage = NSHashTable<AnyObject>(options: [.weakMemory, .objectPointerPersonality])

    public init() {}

    public func add(item: T) {
        self.storage.add(item as AnyObject)
    }

    public func remove(item: T) {
        self.storage.remove(item as AnyObject)
    }
}

extension WeakSet: Sequence {
    public func makeIterator() -> IndexingIterator<[T]> {
        (self.storage.allObjects as? [T] ?? []).makeIterator()
    }
}

import Foundation

private class Canary {}

public struct OrderedKeyArray<Key: Comparable, Element: Hashable & Equatable> {
    public var elements: [Element] {
        self.storage as! [Element]
    }

    fileprivate var storage: NSMutableArray
    fileprivate var canary: Canary
    fileprivate let elementToKey: ElementToKey; public typealias ElementToKey = (Element) -> (Key)

    public init(elementToKey: @escaping ElementToKey, elements: [Element] = []) {
        self.elementToKey = elementToKey
        self.canary = Canary()
        self.storage = .init(array: elements)
    }

    public func forEach(_ body: (Element) -> Void) {
        self.storage.forEach { body($0 as! Element) }
    }

    public func contains(_ element: Element) -> Bool {
        // in general case NSMutableArray.contains
        // should create private NSObject class (not documented behavior)
        // with hashing implementation based on
        // Hashable protocol implementation
        // and check containing by O(1)
        // if not, fining explicitly index by O(logn)
        self.storage.contains(element) || self.index(of: element) != nil
    }

    public func index(of element: Element) -> Int? {
        let index = self.storage.index(
            of: element,
            inSortedRange: NSRange(0..<self.storage.count),
            usingComparator: self.compareElement
        )
        return index == NSNotFound ? nil : index
    }

    public func bisect_key_left(key: Key, maxCount: Int? = nil) -> Int {
        let start = maxCount.map { Swift.max(storage.count - $0, 0) } ?? 0
        return self.storage.index(
            of: key,
            inSortedRange: NSRange(start..<self.storage.count),
            options: [.insertionIndex, .firstEqual],
            usingComparator: self.compareElementAndKey
        )
    }

    public func bisect_key_right(key: Key, maxCount: Int? = nil) -> Int {
        let start = maxCount.map { Swift.max(storage.count - $0, 0) } ?? 0
        return self.storage.index(
            of: key,
            inSortedRange: NSRange(start..<self.storage.count),
            options: [.insertionIndex, .lastEqual],
            usingComparator: self.compareElementAndKey
        )
    }

    fileprivate func compareElementAndKey(_ a: Any, _ b: Any) -> ComparisonResult {
        func anyToKey(_ object: Any) -> Key {
            (object as? Key) ?? self.elementToKey(object as! Element)
        }
        let a = anyToKey(a), b = anyToKey(b)
        if a < b { return .orderedAscending }
        if a > b { return .orderedDescending }
        return .orderedSame
    }

    fileprivate func compareElement(_ a: Any, _ b: Any) -> ComparisonResult {
        let a = self.elementToKey(a as! Element), b = self.elementToKey(b as! Element)
        if a < b { return .orderedAscending }
        if a > b { return .orderedDescending }
        return .orderedSame
    }
}

extension OrderedKeyArray: RandomAccessCollection {
    public typealias Index = Int
    public typealias Indices = CountableRange<Int>

    public var startIndex: Int { 0 }
    public var endIndex: Int { self.storage.count }
    public subscript(i: Int) -> Element { self.storage[i] as! Element }
}

extension OrderedKeyArray {
    @discardableResult
    public mutating func insert(_ newElement: Element)
        -> (inserted: Bool, memberAfterInsert: Int)
    {
        let index = self.index(for: newElement)
        self.makeUnique()
        self.storage.insert(newElement, at: index)
        return (true, index)
    }

    public mutating func remove(_ element: Element) -> Bool {
        guard let index = self.index(of: element) else {
            return false
        }
        self.makeUnique()
        self.storage.removeObject(at: index)
        return true
    }

    private func index(for value: Element) -> Int {
        self.storage.index(
            of: value,
            inSortedRange: NSRange(0..<self.storage.count),
            options: [.insertionIndex, .lastEqual],
            usingComparator: self.compareElement
        )
    }

    private mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&self.canary) {
            self.storage = self.storage.mutableCopy() as! NSMutableArray
            self.canary = Canary()
        }
    }
}

extension OrderedKeyArray: Equatable {
    public static func == (
        lhs: OrderedKeyArray<Key, Element>,
        rhs: OrderedKeyArray<Key, Element>
    ) -> Bool {
        lhs.storage.isEqual(rhs.storage)
    }
}

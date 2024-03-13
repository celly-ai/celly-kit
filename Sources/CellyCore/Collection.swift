import Foundation

public extension Collection where Element: Numeric {
    /// Returns the total sum of all elements in the array
    var total: Element { reduce(0, +) }
}

public extension Collection where Element: BinaryInteger {
    /// Returns the average of all elements in the array
    var average: Element {
        isEmpty ? 0 : self.total / Element(count)
    }

    var median: Element {
        guard !isEmpty else {
            return 0
        }
        let sortedArray = sorted()
        if count % 2 != 0 {
            return sortedArray[count / 2]
        }
        else {
            return sortedArray[count / 2] + sortedArray[count / 2 - 1] / 2
        }
    }

    var std: Element {
        let mean = self.median
        let v: Element = self.reduce(0) {
            $0 + ($1 - mean) * ($1 - mean)
        }
        let count = Element(self.count - 1)
        let denominator = count > 0 ? count : 1
        return Element(sqrt(Double(v / denominator)))
    }
}

public extension Collection where Element: BinaryFloatingPoint {
    /// Returns the average of all elements in the array
    var average: Element {
        isEmpty ? 0 : self.total / Element(count)
    }

    var median: Element {
        guard !isEmpty else {
            return 0.0
        }
        let sortedArray = sorted()
        if count % 2 != 0 {
            return Element(sortedArray[count / 2])
        }
        else {
            return Element(sortedArray[count / 2] + sortedArray[count / 2 - 1]) / 2.0
        }
    }

    var std: Element {
        let mean = self.median
        let v: Element = self.reduce(0) {
            $0 + ($1 - mean) * ($1 + mean)
        }
        let count = Element(!self.isEmpty ? self.count - 1 : 1)
        return sqrt(v / count)
    }
}

public extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

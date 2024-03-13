import Foundation

public extension Date {
    var timestamp: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        return dateFormatter.string(from: self)
    }
}

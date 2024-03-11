import Foundation

public extension String {
    init?(_ fourChatCode: FourCharCode) {
        let n = Int(fourChatCode)
        guard
            let firstChr = UnicodeScalar((n >> 24) & 255),
            let secondChr = UnicodeScalar((n >> 16) & 255),
            let thirdChr = UnicodeScalar((n >> 8) & 255),
            let fourChr = UnicodeScalar(n & 255)
        else {
            return nil
        }
        let scalars = [firstChr, secondChr, thirdChr, fourChr]
        let string = { () -> String in
            var s = ""
            s.unicodeScalars.append(contentsOf: scalars)
            return s
        }()
        self = string.trimmingCharacters(in: NSCharacterSet.whitespaces)
    }
}

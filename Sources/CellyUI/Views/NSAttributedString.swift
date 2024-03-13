import UIKit

// MARK: - Properties

public extension NSAttributedString {
    /// SwifterSwift: Bolded string.
    var bolded: NSAttributedString {
        applying(attributes: [.font: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)])
    }

    /// SwifterSwift: Underlined string.
    var underlined: NSAttributedString {
        applying(attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
    }

    /// SwifterSwift: Italicized string.
    var italicized: NSAttributedString {
        applying(attributes: [.font: UIFont.italicSystemFont(ofSize: UIFont.systemFontSize)])
    }

    /// SwifterSwift: Struckthrough string.
    var struckthrough: NSAttributedString {
        applying(attributes: [
            .strikethroughStyle: NSNumber(value: NSUnderlineStyle.single.rawValue as Int),
        ])
    }

    /// SwifterSwift: Dictionary of the attributes applied across the whole string
    var attributes: [NSAttributedString.Key: Any] {
        attributes(at: 0, effectiveRange: nil)
    }

    /// SwifterSwift: Add color to NSAttributedString.
    ///
    /// - Parameter color: text color.
    /// - Returns: a NSAttributedString colored with given color.
    func colored(_ color: UIColor) -> NSAttributedString {
        applying(attributes: [.foregroundColor: color])
    }

    func font(_ font: UIFont) -> NSAttributedString {
        applying(attributes: [NSAttributedString.Key.font: font])
    }

    func textAlignment(_ textAlignment: NSTextAlignment) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        return applying(attributes: [NSAttributedString.Key.paragraphStyle: paragraphStyle])
    }

    func lineSpace(_ space: CGFloat) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = space
        return applying(attributes: [NSAttributedString.Key.paragraphStyle: paragraphStyle])
    }

    func charSpace(_ space: CGFloat) -> NSAttributedString {
        applying(attributes: [NSAttributedString.Key.kern: space])
    }

    func lineBreakMode(_ lineBreakMode: NSLineBreakMode) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = lineBreakMode
        return applying(attributes: [NSAttributedString.Key.paragraphStyle: paragraphStyle])
    }
}

// MARK: - Methods

public extension NSAttributedString {
    /// SwifterSwift: Applies given attributes to the new instance of NSAttributedString initialized with self object
    ///
    /// - Parameter attributes: Dictionary of attributes
    /// - Returns: NSAttributedString with applied attributes
    private func applying(attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let copy = NSMutableAttributedString(attributedString: self)
        let range = (string as NSString).range(of: string)
        copy.addAttributes(attributes, range: range)

        return copy
    }

    /// SwifterSwift: Apply attributes to substrings matching a regular expression
    ///
    /// - Parameters:
    ///   - attributes: Dictionary of attributes
    ///   - pattern: a regular expression to target
    /// - Returns: An NSAttributedString with attributes applied to substrings matching the pattern
    func applying(
        attributes: [NSAttributedString.Key: Any],
        toRangesMatching pattern: String
    )
        -> NSAttributedString
    {
        guard let pattern = try? NSRegularExpression(pattern: pattern, options: [])
        else { return self }

        let matches = pattern.matches(in: string, options: [], range: NSRange(0..<length))
        let result = NSMutableAttributedString(attributedString: self)

        for match in matches {
            result.addAttributes(attributes, range: match.range)
        }

        return result
    }

    /// SwifterSwift: Apply attributes to occurrences of a given string
    ///
    /// - Parameters:
    ///   - attributes: Dictionary of attributes
    ///   - target: a subsequence string for the attributes to be applied to
    /// - Returns: An NSAttributedString with attributes applied on the target string
    func applying<T: StringProtocol>(
        attributes: [NSAttributedString.Key: Any], toOccurrencesOf target: T
    ) -> NSAttributedString {
        let pattern = "\\Q\(target)\\E"

        return self.applying(attributes: attributes, toRangesMatching: pattern)
    }
}

import UIKit

@IBDesignable
public class CellyButton: UIButton {
    static let ButtonFontSize: CGFloat = 12.0
    static let ButtonHeight: CGFloat = 44.0

    public enum ButtonStyle: String {
        case blue
        case white
    }

    // MARK: Properties

    @IBInspectable
    public var cornerRadius: CGFloat = 8 {
        didSet {
            self.setup(cornerRadius: self.cornerRadius)
        }
    }

    @IBInspectable
    private var _style: String = ButtonStyle.blue.rawValue {
        didSet {
            self.style = ButtonStyle(rawValue: self._style) ?? .blue
        }
    }

    public var style = ButtonStyle.blue {
        didSet {
            self.setup(style: self.style)
        }
    }

    // MARK: Public

    public func add(target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        self.addTarget(target, action: action, for: controlEvents)
    }

    public func set(title: String?, for state: UIControl.State) {
        self.setTitle(title, for: state)
    }

    // MARK: Init

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    override public func prepareForInterfaceBuilder() {
        self.setup()
    }

    public convenience init(style: ButtonStyle? = nil) {
        self.init(frame: .zero)
        self.setup()
        self.style = style ?? .blue
    }

    // MARK: Setup

    private func setup() {
        self.setup(cornerRadius: self.cornerRadius)
        self.setup(style: self.style)
    }

    private func setup(cornerRadius: CGFloat) {
        self.layer.cornerRadius = cornerRadius
        self.layer.masksToBounds = true
    }

    private func setup(style: ButtonStyle) {
        switch style {
        case .white:
            self.setTitleColor(Style.Color.blue, for: .normal)
            self.setBackground(color: Style.Color.white, for: .normal)
            self.setTitleColor(
                Style.Color.blue.withAlphaComponent(0.9),
                for: .highlighted
            )
            self.setBackground(color: Style.Color.white.withAlphaComponent(0.9), for: .highlighted)
            self.setTitleColor(Style.Color.blue.withAlphaComponent(0.5), for: .disabled)
            self.setBackground(color: Style.Color.white.withAlphaComponent(0.5), for: .disabled)
        default:
            self.setTitleColor(Style.Color.white, for: .normal)
            self.setBackground(color: Style.Color.blue, for: .normal)
            self.setTitleColor(Style.Color.white.withAlphaComponent(0.8), for: .highlighted)
            self.setBackground(color: Style.Color.blue.withAlphaComponent(0.8), for: .highlighted)
            self.setTitleColor(Style.Color.white.withAlphaComponent(0.7), for: .disabled)
            self.setBackground(color: Style.Color.blue.withAlphaComponent(0.7), for: .disabled)
        }
    }
}

public class CellyButtonDeprecated: UIView {
    public enum ButtonStyle {
        case blue
        case white
    }

    private var style = ButtonStyle.blue {
        didSet {
            switch self.style {
            case .blue:
                self.bgColor = Style.Color.blue
                self.textColor = Style.Color.white
            case .white:
                self.bgColor = Style.Color.white
                self.textColor = Style.Color.blue
            }
        }
    }

    private var height: CGFloat = 44.0
    private var bgColor: UIColor = Style.Color.blue
    private var textColor: UIColor = Style.Color.white
    private var cornerRadius: CGFloat = 8.0
    private var insets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    private let button = PrivateCellyButton(frame: .zero)

    public func add(target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        self.button.addTarget(target, action: action, for: controlEvents)
    }

    public func set(title: String?, for state: UIControl.State) {
        self.button.setTitle(title, for: state)
    }

    // Lifecycle

    convenience init(style: ButtonStyle) {
        self.init(frame: .zero)
        self.style = style
        self.setup()
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: Private

    private func setup() {
        // View
        self.backgroundColor = .clear
        self.layer.masksToBounds = false
        self.clipsToBounds = false

        // Button
        self.addSubview(self.button)
        NSLayoutConstraint.activate([
            self.button.topAnchor.constraint(equalTo: self.topAnchor, constant: self.insets.top),
            self.button.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -self.insets.bottom),
            self.button.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: self.insets.left),
            self.button.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -self.insets.right),
            self.button.heightAnchor.constraint(equalToConstant: self.height + self.insets.top + self.insets.bottom),
        ])
        self.button.setTitleColor(self.textColor, for: .normal)
        self.button.setBackground(color: self.bgColor, for: .normal)
        self.button.layer.cornerRadius = self.cornerRadius
        self.button.layer.masksToBounds = true
    }
}

private class PrivateCellyButton: UIButton {
    // Lifecycle

    override public func awakeFromNib() {
        super.awakeFromNib()
        self.setup()
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    // MARK: Private

    private func setup() {}
}

import UIKit

@objc
public class ClosureSleeve: NSObject {
    public let closure: () -> Void

    public init(_ closure: @escaping () -> Void) {
        self.closure = closure
    }

    @objc
    public func invoke() {
        self.closure()
    }
}

public extension UIControl {
    func addAction(
        for controlEvents: UIControl.Event = .touchUpInside,
        _ closure: @escaping () -> Void
    ) {
        let sleeve = ClosureSleeve(closure)
        addTarget(sleeve, action: #selector(ClosureSleeve.invoke), for: controlEvents)
        objc_setAssociatedObject(
            self,
            "[\(UUID().uuidString)]",
            sleeve,
            objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN
        )
    }
}

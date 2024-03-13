import CellyCore
import UIKit

public class Style {
    public func application(
        _: UIApplication,
        didFinishLaunchingWith _: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        UINavigationBar.appearance().barTintColor = Style.Color.blue
        UINavigationBar.appearance().tintColor = Style.Color.white
        UINavigationBar.appearance().titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: Style.Color.white,
        ]
    }

    public init() {}

    public enum Color {
        public static let blue = UIColor(hex: "1091D6") // 0077B5
        public static let lightBlue = UIColor(hex: "69C7FF") // 1091D6
        public static let white = UIColor.white
        public static let gray = UIColor(hex: "bbbbbb")
        public static let lightGray = UIColor(hex: "ecf0f1")
        public static let red = UIColor(hex: "FE5A51")
        public static let pink = UIColor(hex: "F88B85")
        public static let green = UIColor(hex: "1ABC9C")
        public static let orange = UIColor(hex: "f39c12")
        public static let maroon = UIColor(hex: "740700")
    }
}

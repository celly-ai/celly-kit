import UIKit

public class NavigationControllerConfigurator {
    public init(attirbutes: NavigationControllerConfigurator.Attirbutes? = nil, navigationController: UINavigationController? = nil) {
        self.attirbutes = attirbutes
        self.navigationController = navigationController
    }

    public var attirbutes: Attirbutes?
    public struct Attirbutes {
        public let hidden: Bool?
        public let backgroundImageForMetrics: (backgroundImage: UIImage?, metrics: UIBarMetrics)?
        public let shadowImage: UIImage?
        public let isTranslucent: Bool?
        public let backgroundColor: UIColor?
        public init(
            hidden: Bool? = nil,
            backgroundImageForMetrics: (backgroundImage: UIImage?, metrics: UIBarMetrics)? = nil,
            shadowImage: UIImage? = nil,
            isTranslucent: Bool? = nil,
            backgroundColor: UIColor? = nil
        ) {
            self.hidden = hidden
            self.backgroundImageForMetrics = backgroundImageForMetrics
            self.shadowImage = shadowImage
            self.isTranslucent = isTranslucent
            self.backgroundColor = backgroundColor
        }
    }

    public weak var navigationController: UINavigationController?

    public func apply(
        navigationController: UINavigationController?,
        attirbutes: Attirbutes,
        animated: Bool
    ) {
        guard let navigationController = navigationController else { return }
        self.attirbutes = Attirbutes(
            hidden: navigationController.isNavigationBarHidden,
            backgroundImageForMetrics: (
                backgroundImage: navigationController.navigationBar.backgroundImage(for: .default),
                metrics: .default
            ),
            shadowImage: navigationController.navigationBar.shadowImage,
            isTranslucent: navigationController.navigationBar.isTranslucent,
            backgroundColor: navigationController.view.backgroundColor
        )
        attirbutes.hidden
            .map { navigationController.setNavigationBarHidden($0, animated: animated) }
        attirbutes.backgroundImageForMetrics
            .map {
                navigationController.navigationBar
                    .setBackgroundImage($0.backgroundImage, for: $0.metrics)
            }
        attirbutes.shadowImage.map { navigationController.navigationBar.shadowImage = $0 }
        attirbutes.isTranslucent.map { navigationController.navigationBar.isTranslucent = $0 }
        attirbutes.backgroundColor.map { navigationController.view.backgroundColor = $0 }

        self.navigationController = navigationController
    }

    public func clear(animated: Bool) {
        guard
            let attirbutes = self.attirbutes,
            let navigationController = self.navigationController
        else {
            return
        }
        attirbutes.hidden
            .map { navigationController.setNavigationBarHidden($0, animated: animated) }
        attirbutes.backgroundImageForMetrics
            .map {
                navigationController.navigationBar
                    .setBackgroundImage($0.backgroundImage, for: $0.metrics)
            }
        attirbutes.shadowImage.map { navigationController.navigationBar.shadowImage = $0 }
        attirbutes.isTranslucent.map { navigationController.navigationBar.isTranslucent = $0 }
        attirbutes.backgroundColor.map { navigationController.view.backgroundColor = $0 }
    }
}

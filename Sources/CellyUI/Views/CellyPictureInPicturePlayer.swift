import AVFoundation
import UIKit

public class CellyPictureInPicturePlayer: NSObject {
    public struct Quality {
        public init(peak: (String, UIColor)? = nil) {
            self.peak = peak
        }

        let peak: (String, UIColor)?
    }

    private var closeButton: UIButton?
    private var contentView: UIView!
    private var imageView: UIImageView!
    private var label: UILabel!
    private var slider: UISlider!
    private var blurLabel: UILabel!
    private var blurSlider: UISlider!

    public var isHidden: Bool {
        get {
            self.contentView.isHidden
        }
        set {
            [
                self.contentView,
                self.label,
                self.slider,
                self.blurLabel,
                self.blurSlider,
                self.imageView,
            ].forEach { $0.isHidden = newValue }
            if newValue {
                self.imageView.image = nil
            }
        }
    }

    override public init() {
        super.init()
    }

    public func show(
        image: CGImage?,
        quality: Quality? = nil
    ) {
        guard !self.contentView.isHidden else {
            return
        }

        if let image = image {
            self.imageView.image = UIImage(cgImage: image)
        }

        if let (level, color) = quality?.peak {
            self.label.text = "Quality \(level)"
            self.label.backgroundColor = color
            self.label.isHidden = false
            if let value = Float(level) {
                self.slider.isHidden = false
                self.slider.value = value
            }
        }
        else {
            self.label.isHidden = true
            self.slider.isHidden = true
        }
    }

    public enum Corner {
        case topRight
        case leftBottom
    }

    public func present(
        in view: UIView,
        size: CGSize,
        corner: Corner
    ) {
        self.setupIfNeeded(in: view)
        self.showContentView(size: size, in: view, corner: corner)
    }

    private func showContentView(
        size: CGSize,
        in view: UIView,
        corner: Corner,
        completion: ((Bool) -> Void)? = nil
    ) {
        var x: CGFloat = 0.0
        var y: CGFloat = 0.0
        let width = size.width
        let height = size.height
        switch corner {
        case .leftBottom:
            x = view.frame.width - width - 32.0
            y = view.frame.height - height - 32.0
        case .topRight:
            x = view.frame.width - width - 32.0
            y = 32
        }
        let fullFrame = CGRect(
            x: x,
            y: y,
            width: width,
            height: height
        )

        [self.contentView, self.label, self.slider, self.blurLabel, self.blurSlider, self.imageView]
            .forEach { $0.isHidden = false }
        self.contentView.frame = CGRect(x: 10, y: 10, width: 10, height: 10)
        self.closeButton?.alpha = 0.0

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.contentView.frame = fullFrame
            self.closeButton?.alpha = 1.0
        }, completion: completion)
    }

    // MARK: Setup

    private func setupIfNeeded(in view: UIView) {
        guard self.contentView == nil else {
            return
        }
        let contentView = UIView(frame: view.bounds)
        contentView.backgroundColor = .black
        contentView.layer.cornerRadius = 8.0
        contentView.layer.masksToBounds = true
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 1
        contentView.layer.shadowOffset = .zero
        contentView.layer.shadowRadius = 5
        view.addSubview(contentView)

        let recognizer = UIPanGestureRecognizer(
            target: self,
            action: #selector(self.handleDrag(_:))
        )
        recognizer.maximumNumberOfTouches = 1
        contentView.addGestureRecognizer(recognizer)

        let imageView = UIImageView(frame: view.bounds)
        imageView.backgroundColor = .clear
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])

        let label = UILabel()
        label.backgroundColor = .white
        label.textColor = .black
        label.textAlignment = .center
        label.layer.cornerRadius = 8.0
        label.layer.masksToBounds = true
        let blurLabel = UILabel()
        blurLabel.backgroundColor = .white
        blurLabel.textColor = .black
        blurLabel.textAlignment = .center
        blurLabel.layer.cornerRadius = 8.0
        blurLabel.layer.masksToBounds = true
        let stackView = UIStackView(arrangedSubviews: [label, blurLabel])
        stackView.distribution = .fillEqually
        stackView.axis = .horizontal
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 50),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -50),
        ])

        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 15
        slider.setThumbImage(UIImage(), for: .normal)
        let blurSlider = UISlider()
        blurSlider.setThumbImage(UIImage(), for: .normal)
        blurSlider.minimumValue = 0
        blurSlider.maximumValue = 15
        let sliderStackView = UIStackView(arrangedSubviews: [slider, blurSlider])
        sliderStackView.distribution = .fillEqually
        sliderStackView.axis = .horizontal
        view.addSubview(sliderStackView)
        NSLayoutConstraint.activate([
            sliderStackView.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 30),
            sliderStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            sliderStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
        ])

        let closeButton = UIButton(type: .system)
        closeButton.setImage(
            UIImage(systemName: "xmark.square.fill")?
                .withTintColor(.white, renderingMode: .alwaysTemplate),
            for: .normal
        )
        closeButton.tintColor = .white
        closeButton.addTarget(
            self,
            action: #selector(self.handleCloseTapped(_:)),
            for: .touchUpInside
        )
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isHidden = true
        contentView.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
        ])

        self.imageView = imageView
        self.contentView = contentView
        self.label = label
        self.slider = slider
        self.blurLabel = blurLabel
        self.blurSlider = blurSlider
    }

    // MARK: Actions

    @objc
    private func handleCloseTapped(_: Any) {
        self.hideContentView()
    }

    @objc
    private func handleDrag(_ sender: UIPanGestureRecognizer) {
        let screenBounds = UIScreen.main.bounds

        let translation = sender.translation(in: self.contentView)
        self.contentView.center = CGPoint(
            x: self.contentView.center.x + translation.x,
            y: self.contentView.center.y + translation.y
        )
        sender.setTranslation(CGPoint(x: 0, y: 0), in: self.contentView)

        if sender.state == .ended {
            var finalPoint = CGPoint(x: 0, y: 0)

            finalPoint.x = max(
                32 + self.contentView.frame.size.width,
                min(self.contentView.frame.maxX, screenBounds.size.width - 32.0)
            )
            finalPoint.y = max(
                32 + self.contentView.frame.size.height,
                min(self.contentView.frame.maxY, screenBounds.size.height - 32.0)
            )

            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                self.contentView.frame.origin = CGPoint(
                    x: finalPoint.x - self.contentView.frame.size.width,
                    y: finalPoint.y - self.contentView.frame.size.height
                )
            })
        }
    }

    private func hideContentView() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.contentView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
            self.closeButton?.alpha = 0
        }, completion: { _ in
            self.contentView.isHidden = true
        })
    }
}

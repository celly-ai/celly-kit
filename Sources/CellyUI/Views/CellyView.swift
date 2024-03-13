import UIKit

public typealias CellyViewCancelAction = () -> Void

public protocol CellyView: AnyObject {
    func hideLoading()
    func showLoading()
    func showLoading(
        progress: ABProgress?,
        cancelAction: CellyViewCancelAction?
    )
    func showSuccess()
    func showDone()
    func show(error: Error, action: (() -> Void)?)
    func show(error: Error)
    func show(
        title: String?,
        mesg: String,
        cancelAction: (title: String, handler: () -> Void),
        actions: [(title: String, handler: () -> Void)]?
    )
}

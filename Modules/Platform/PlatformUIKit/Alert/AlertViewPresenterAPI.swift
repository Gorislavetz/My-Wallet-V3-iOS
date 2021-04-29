// Copyright © Blockchain Luxembourg S.A. All rights reserved.

public protocol AlertViewPresenterAPI: AnyObject {
    func notify(content: AlertViewContent, in viewController: UIViewController?)
    func error(in viewController: UIViewController?, action: (() -> Void)?)
}

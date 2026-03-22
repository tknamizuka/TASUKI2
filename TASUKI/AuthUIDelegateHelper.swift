//
//  AuthUIDelegateHelper.swift
//  TASUKI
//
//  Firebase Auth の OAuth ログインで Web 認証 UI を表示するための AuthUIDelegate 実装。
//  uiDelegate に nil を渡すとクラッシュするため、キーウィンドウ上の ViewController から present / dismiss する。
//

import UIKit
import FirebaseAuth

final class AuthUIDelegateHelper: NSObject, AuthUIDelegate {

    static let shared = AuthUIDelegateHelper()

    private override init() {
        super.init()
    }

    /// 最前面の ViewController（presented の連鎖を辿る）
    private func topViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topViewController(from: presented)
        }
        if let nav = root as? UINavigationController {
            if let visible = nav.visibleViewController {
                return topViewController(from: visible)
            }
        }
        if let tab = root as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(from: selected)
            }
        }
        return root
    }

    private func keyWindowRootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) {
                return window.rootViewController
            }
        }
        return scenes.first?.windows.first?.rootViewController
    }

    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?) {
        DispatchQueue.main.async {
            guard let root = self.keyWindowRootViewController() else {
                completion?()
                return
            }
            let top = self.topViewController(from: root)
            top.present(viewControllerToPresent, animated: flag, completion: completion)
        }
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        DispatchQueue.main.async {
            guard let root = self.keyWindowRootViewController() else {
                completion?()
                return
            }
            let top = self.topViewController(from: root)
            top.dismiss(animated: flag, completion: completion)
        }
    }
}

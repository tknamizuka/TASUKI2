import Foundation
import FirebaseCore

/// SwiftUI の `App` では `@StateObject` の初期化が `AppDelegate.application(_:didFinishLaunchingWithOptions:)` より早いことがあり、
/// `FirebaseApp.configure()` 前に `Firestore.firestore()` が走ると起動直後にクラッシュする。
/// すべての Firebase 利用より前に **一度だけ** 呼ぶ。
enum FirebaseBootstrap {
    private static let lock = NSLock()
    private static var didConfigure = false

    static func configureIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !didConfigure else { return }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("[TASUKI][BOOT] FirebaseApp.configure()")
        } else {
            print("[TASUKI][BOOT] Firebase already configured; skipping")
        }
        didConfigure = true
    }
}

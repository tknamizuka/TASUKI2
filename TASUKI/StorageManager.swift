import Foundation
import UIKit
import Combine
import FirebaseStorage
import FirebaseAuth

final class StorageManager: ObservableObject {
    
    static let shared = StorageManager()
    private let storage: Storage = Storage.storage()
    
    private init() {}
    
    /// プロフィール画像をアップロードしてダウンロードURLを取得
    /// - Parameters:
    ///   - image: アップロードする画像
    ///   - uid: ユーザーID
    /// - Returns: ダウンロードURL（失敗時はnil）
    func uploadProfileImage(_ image: UIImage, uid: String) async throws -> String {
        // 画像をJPEG形式に変換（圧縮率0.5）
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            throw NSError(domain: "StorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "画像の変換に失敗しました。"])
        }
        
        // 保存先パス
        let path = "profile_images/\(uid).jpg"
        let storageRef = storage.reference().child(path)
        
        // メタデータを設定
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // 1. アップロード実行
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            storageRef.putData(imageData, metadata: metadata) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        
        // ダウンロードURL を指数バックオフでリトライ
        let maxAttempts = 5
        for attempt in 0..<maxAttempts {
            do {
                let urlString = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                    storageRef.downloadURL { url, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let url = url {
                            continuation.resume(returning: url.absoluteString)
                        } else {
                            continuation.resume(throwing: NSError(domain: "StorageManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "ダウンロードURLの取得に失敗しました。"]))
                        }
                    }
                }
                return urlString
            } catch {
                if attempt == maxAttempts - 1 {
                    throw error
                }
                // exponential backoff (1s, 2s, 4s, ...)
                let backoffSeconds = pow(2.0, Double(attempt))
                let backoffNano = UInt64(backoffSeconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: backoffNano)
            }
        }

        throw NSError(domain: "StorageManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "ダウンロードURLの取得に失敗しました。"])
    }
}

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

final class UserManager: ObservableObject {
    
    @Published var hasProfile: Bool? = nil  // nil: 未判定, true/false: 判定済み
    
    /// configure より前に `Firestore.firestore()` を触らないよう lazy にする（起動順問題の回避）
    private lazy var db = Firestore.firestore()
    
    /// ログイン中ユーザーのプロフィールを Firestore に保存 / 更新
    func saveUserProfile(user: User, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let firebaseUser = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "UserManager",
                                        code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "ログインユーザーが見つかりません。"])))
            return
        }
        
        // FirestoreEncoder (FirebaseFirestoreSwift) が無い環境でも動くよう、辞書で明示的に保存
        var data: [String: Any] = [
            "id": user.id.uuidString,
            "name": user.name,
            "profileImage": user.profileImage,
            "bio": user.bio,
            "rank": user.rank,
            "age": user.age,
            "gender": user.gender,
            "purpose": user.purpose,
            "prefecture": user.prefecture,
            "area": user.area,
            "pace": user.pace,
            "runningFrequency": user.runningFrequency,
            "personalBest": user.personalBest,
            "schedule": user.schedule,
            "nextRace": user.nextRace,
            "targetTime": user.targetTime,
            "monthlyDistance": user.monthlyDistance,
            "monthlyTarget": user.monthlyTarget,
            "avgPace": user.avgPace,
            "matchRate": user.matchRate,
            "lastLogin": Timestamp(date: user.lastLogin),
            "spotName": user.spotName,
            "latitude": user.latitude,
            "longitude": user.longitude,
            "distanceFromUserMock": user.distanceFromUserMock
        ]
        
        // profileImageUrl が存在する場合のみ追加
        if let profileImageUrl = user.profileImageUrl {
            data["profileImageUrl"] = profileImageUrl
        }
        
        db.collection("users")
            .document(firebaseUser.uid)
            .setData(data, merge: true) { [weak self] error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    DispatchQueue.main.async {
                        self?.hasProfile = true
                    }
                    completion(.success(()))
                }
            }
    }
    
    /// Firestore にプロフィールが存在するか確認
    func checkUserExists() {
        guard let firebaseUser = Auth.auth().currentUser else {
            DispatchQueue.main.async {
                self.hasProfile = nil
            }
            return
        }
        
        db.collection("users").document(firebaseUser.uid).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to check user existence: \(error.localizedDescription)")
                    self?.hasProfile = false
                    return
                }
                self?.hasProfile = snapshot?.exists ?? false
            }
        }
    }
    
    /// Firestore にプロフィールが存在するか確認（非同期版）
    func checkIfUserExists(uid: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            db.collection("users").document(uid).getDocument { snapshot, error in
                if let error = error {
                    print("Failed to check user existence: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: snapshot?.exists ?? false)
            }
        }
    }
}


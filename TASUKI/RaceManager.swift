//
//  RaceManager.swift
//  TASUKI
//
//  レースの作成・参加・スタート・距離更新・ゴール記録
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

final class RaceManager: ObservableObject {
    static let shared = RaceManager()
    private let db = Firestore.firestore()
    
    @Published var currentRace: Race?
    @Published var participants: [RaceParticipant] = []
    @Published var errorMessage: String?
    
    private var raceListener: ListenerRegistration?
    private var participantsListener: ListenerRegistration?
    
    private init() {}
    
    var currentUserId: String? { Auth.auth().currentUser?.uid }
    
    // MARK: - Create / Join
    
    /// 指定カテゴリで新規レースを作成し、作成者を参加させる
    func createRace(category: LiveRaceCategory, userName: String, userRank: String?, completion: @escaping (Result<String, Error>) -> Void) {
        guard let uid = currentUserId else {
            completion(.failure(NSError(domain: "RaceManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未ログイン"])))
            return
        }
        let ref = db.collection("races").document()
        let now = Timestamp(date: Date())
        let data: [String: Any] = [
            "distanceCategory": category.rawValue,
            "targetDistanceKm": category.targetDistanceKm,
            "status": RaceStatus.waiting.rawValue,
            "createdAt": now,
            "hostUserId": uid
        ]
        ref.setData(data) { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            self?.joinRace(raceId: ref.documentID, userId: uid, name: userName, rank: userRank) { result in
                switch result {
                case .success: completion(.success(ref.documentID))
                case .failure(let e): completion(.failure(e))
                }
            }
        }
    }
    
    /// 既存の「待機中」レースを検索（カテゴリ一致）
    func findWaitingRace(category: LiveRaceCategory, completion: @escaping (Result<String?, Error>) -> Void) {
        db.collection("races")
            .whereField("distanceCategory", isEqualTo: category.rawValue)
            .whereField("status", isEqualTo: RaceStatus.waiting.rawValue)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                let id = snapshot?.documents.first?.documentID
                completion(.success(id))
            }
    }
    
    /// レースに参加
    func joinRace(raceId: String, userId: String, name: String, rank: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        let ref = db.collection("races").document(raceId).collection("participants").document(userId)
        let data: [String: Any] = [
            "name": name,
            "rank": rank ?? "",
            "currentDistanceKm": 0.0,
            "joinedAt": Timestamp(date: Date())
        ]
        ref.setData(data, merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// マッチング: 待機中のレースがあれば参加、なければ作成
    func matchOrCreate(category: LiveRaceCategory, userName: String, userRank: String?, completion: @escaping (Result<String, Error>) -> Void) {
        findWaitingRace(category: category) { [weak self] result in
            switch result {
            case .failure(let e):
                completion(.failure(e))
            case .success(let raceId):
                if let raceId = raceId, let uid = self?.currentUserId {
                    self?.joinRace(raceId: raceId, userId: uid, name: userName, rank: userRank) { joinResult in
                        switch joinResult {
                        case .success: completion(.success(raceId))
                        case .failure(let e): completion(.failure(e))
                        }
                    }
                } else {
                    self?.createRace(category: category, userName: userName, userRank: userRank, completion: completion)
                }
            }
        }
    }
    
    // MARK: - Start Race (Host)
    
    /// レースをスタート（カウントダウン後に startTime を設定）
    func startRace(raceId: String, countdownSeconds: Int = 5, completion: @escaping (Result<Void, Error>) -> Void) {
        let startTime = Date().addingTimeInterval(TimeInterval(countdownSeconds))
        db.collection("races").document(raceId).updateData([
            "status": RaceStatus.starting.rawValue,
            "startTime": Timestamp(date: startTime)
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// startTime を過ぎていたら status を running に更新（どれか1クライアントが呼ぶ）
    func ensureRaceRunning(raceId: String, startTime: Date?) {
        guard let start = startTime, Date() >= start else { return }
        db.collection("races").document(raceId).getDocument { [weak self] snapshot, _ in
            guard let data = snapshot?.data(),
                  (data["status"] as? String) == RaceStatus.starting.rawValue else { return }
            self?.db.collection("races").document(raceId).updateData([
                "status": RaceStatus.running.rawValue
            ]) { _ in }
        }
    }
    
    // MARK: - Listeners
    
    /// レースドキュメントをリアルタイム監視
    func listenToRace(raceId: String) {
        raceListener?.remove()
        raceListener = db.collection("races").document(raceId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
                    return
                }
                guard let data = snapshot?.data() else {
                    DispatchQueue.main.async { self.currentRace = nil }
                    return
                }
                let race = self.parseRace(id: snapshot!.documentID, data: data)
                DispatchQueue.main.async {
                    self.currentRace = race
                    if race.status == .running && race.startTime == nil {
                        // startTime が無い場合は starting の startTime をそのまま使う
                    }
                }
            }
    }
    
    /// 参加者一覧をリアルタイム監視
    func listenToParticipants(raceId: String) {
        participantsListener?.remove()
        participantsListener = db.collection("races").document(raceId).collection("participants")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
                    return
                }
                let list = (snapshot?.documents ?? []).map { doc in
                    self.parseParticipant(id: doc.documentID, data: doc.data())
                }
                DispatchQueue.main.async { self.participants = list }
            }
    }
    
    /// レース監視を開始（race + participants）
    func startListening(raceId: String) {
        listenToRace(raceId: raceId)
        listenToParticipants(raceId: raceId)
    }
    
    func stopListening() {
        raceListener?.remove()
        participantsListener?.remove()
        raceListener = nil
        participantsListener = nil
        DispatchQueue.main.async {
            self.currentRace = nil
            self.participants = []
        }
    }
    
    // MARK: - During Race
    
    /// 現在の走行距離を更新（定期的に呼ぶ）
    func updateMyDistance(raceId: String, distanceKm: Double) {
        guard let uid = currentUserId else { return }
        db.collection("races").document(raceId).collection("participants").document(uid)
            .updateData(["currentDistanceKm": distanceKm]) { _ in }
    }
    
    /// ゴールを記録（経過秒数を送信）
    func submitFinish(raceId: String, finishTimeSeconds: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = currentUserId else {
            completion(.failure(NSError(domain: "RaceManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未ログイン"])))
            return
        }
        db.collection("races").document(raceId).collection("participants").document(uid)
            .updateData(["finishTimeSeconds": finishTimeSeconds]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }
    
    /// レースを終了状態にする（全員ゴール後や制限時間でホストが呼ぶ）
    func finishRace(raceId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("races").document(raceId).updateData([
            "status": RaceStatus.finished.rawValue
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Parse
    
    private func parseRace(id: String, data: [String: Any]) -> Race {
        let statusRaw = data["status"] as? String ?? RaceStatus.waiting.rawValue
        let status = RaceStatus(rawValue: statusRaw) ?? .waiting
        let startTime = (data["startTime"] as? Timestamp)?.dateValue()
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return Race(
            id: id,
            distanceCategory: data["distanceCategory"] as? String ?? "5k",
            targetDistanceKm: data["targetDistanceKm"] as? Double ?? 5.0,
            status: status,
            startTime: startTime,
            createdAt: createdAt,
            hostUserId: data["hostUserId"] as? String
        )
    }
    
    private func parseParticipant(id: String, data: [String: Any]) -> RaceParticipant {
        let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue() ?? Date()
        return RaceParticipant(
            id: id,
            name: data["name"] as? String ?? "",
            rank: (data["rank"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            currentDistanceKm: data["currentDistanceKm"] as? Double ?? 0,
            finishTimeSeconds: data["finishTimeSeconds"] as? Double,
            joinedAt: joinedAt
        )
    }
}

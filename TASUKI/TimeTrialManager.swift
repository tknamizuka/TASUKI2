//
//  TimeTrialManager.swift
//  TASUKI
//
//  タイムトライアル部屋の作成・参加・タイム提出・順位取得（EKIDEN とは別）
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

final class TimeTrialManager: ObservableObject {
    static let shared = TimeTrialManager()
    private lazy var db = Firestore.firestore()
    
    @Published var currentRoom: TimeTrialRoom?
    @Published var participants: [TimeTrialParticipant] = []
    @Published var errorMessage: String?
    
    private var roomListener: ListenerRegistration?
    private var participantsListener: ListenerRegistration?
    
    private init() {}
    
    var currentUserId: String? { Auth.auth().currentUser?.uid }
    
    /// "Rank S" -> "S", "Rank A" -> "A" など
    static func rankTier(fromRank rank: String?) -> String {
        guard let r = rank, r.hasPrefix("Rank ") else { return "E" }
        let tier = String(r.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        return tier.isEmpty ? "E" : tier
    }
    
    // MARK: - Create or Join
    
    /// 同距離・同ランクで空きがある部屋を探す。なければ新規作成（期間1週間）
    func createOrJoinRoom(distance: TimeTrialDistance, userRank: String?, userName: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let uid = currentUserId else {
            completion(.failure(NSError(domain: "TimeTrialManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未ログイン"])))
            return
        }
        let tier = Self.rankTier(fromRank: userRank)
        
        db.collection("time_trial_rooms")
            .whereField("distanceKm", isEqualTo: distance.distanceKm)
            .whereField("rankTier", isEqualTo: tier)
            .whereField("periodEnd", isGreaterThan: Timestamp(date: Date()))
            .order(by: "periodEnd", descending: false)
            .limit(to: 5)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                // 20名未満の部屋を探す
                let doc = snapshot?.documents.first { doc in
                    let count = doc.data()["participantCount"] as? Int ?? 0
                    return count < 20
                }
                if let d = doc {
                    self?.joinRoom(roomId: d.documentID, userId: uid, name: userName, rank: userRank, completion: completion)
                } else {
                    self?.createRoom(distance: distance, rankTier: tier, userId: uid, userName: userName, userRank: userRank, completion: completion)
                }
            }
    }
    
    private func createRoom(distance: TimeTrialDistance, rankTier: String, userId: String, userName: String, userRank: String?, completion: @escaping (Result<String, Error>) -> Void) {
        let ref = db.collection("time_trial_rooms").document()
        let now = Date()
        let periodEnd = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        let data: [String: Any] = [
            "distanceKm": distance.distanceKm,
            "rankTier": rankTier,
            "periodStart": Timestamp(date: now),
            "periodEnd": Timestamp(date: periodEnd),
            "createdAt": Timestamp(date: now),
            "participantCount": 0
        ]
        ref.setData(data) { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            self?.joinRoom(roomId: ref.documentID, userId: userId, name: userName, rank: userRank) { result in
                switch result {
                case .success: completion(.success(ref.documentID))
                case .failure(let e): completion(.failure(e))
                }
            }
        }
    }
    
    private func joinRoom(roomId: String, userId: String, name: String, rank: String?, completion: @escaping (Result<String, Error>) -> Void) {
        let ref = db.collection("time_trial_rooms").document(roomId).collection("participants").document(userId)
        let data: [String: Any] = [
            "name": name,
            "rank": rank ?? "",
            "joinedAt": Timestamp(date: Date())
        ]
        ref.setData(data, merge: true) { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            self?.incrementParticipantCount(roomId: roomId)
            completion(.success(roomId))
        }
    }
    
    private func incrementParticipantCount(roomId: String) {
        db.collection("time_trial_rooms").document(roomId)
            .updateData(["participantCount": FieldValue.increment(Int64(1))]) { _ in }
    }
    
    // MARK: - Submit Time（期間中1回のみ）
    
    func submitTime(roomId: String, timeSeconds: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = currentUserId else {
            completion(.failure(NSError(domain: "TimeTrialManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未ログイン"])))
            return
        }
        let ref = db.collection("time_trial_rooms").document(roomId).collection("participants").document(uid)
        let now = Timestamp(date: Date())
        ref.updateData([
            "submittedTimeSeconds": timeSeconds,
            "submittedAt": now
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Fetch
    
    func fetchRoom(roomId: String, completion: @escaping (Result<TimeTrialRoom, Error>) -> Void) {
        db.collection("time_trial_rooms").document(roomId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = snapshot?.data(), let room = self.parseRoom(id: snapshot!.documentID, data: data) else {
                completion(.failure(NSError(domain: "TimeTrialManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "部屋が見つかりません"])))
                return
            }
            completion(.success(room))
        }
    }
    
    func fetchParticipants(roomId: String, completion: @escaping (Result<[TimeTrialParticipant], Error>) -> Void) {
        db.collection("time_trial_rooms").document(roomId).collection("participants")
            .order(by: "joinedAt", descending: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                let list = (snapshot?.documents ?? []).map { self.parseParticipant(id: $0.documentID, data: $0.data()) }
                completion(.success(list))
            }
    }
    
    /// 提出済みタイムでソートした順位リスト＋ポイント
    func fetchRanking(roomId: String, completion: @escaping (Result<[TimeTrialRankingEntry], Error>) -> Void) {
        fetchParticipants(roomId: roomId) { result in
            switch result {
            case .failure(let e):
                completion(.failure(e))
            case .success(let list):
                let submitted = list.compactMap { p -> (TimeTrialParticipant, Double)? in
                    guard let sec = p.submittedTimeSeconds else { return nil }
                    return (p, sec)
                }
                let sorted = submitted.sorted { $0.1 < $1.1 }
                let entries = sorted.enumerated().map { index, item in
                    TimeTrialRankingEntry(
                        id: item.0.id,
                        rank: index + 1,
                        name: item.0.name,
                        timeSeconds: item.1,
                        points: TimeTrialPoints.points(forRank: index + 1)
                    )
                }
                completion(.success(entries))
            }
        }
    }
    
    // MARK: - Listeners
    
    func startListening(roomId: String) {
        roomListener?.remove()
        roomListener = db.collection("time_trial_rooms").document(roomId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
                    return
                }
                guard let data = snapshot?.data() else {
                    DispatchQueue.main.async { self.currentRoom = nil }
                    return
                }
                let room = self.parseRoom(id: snapshot!.documentID, data: data)
                DispatchQueue.main.async { self.currentRoom = room }
            }
        participantsListener?.remove()
        participantsListener = db.collection("time_trial_rooms").document(roomId).collection("participants")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
                    return
                }
                let list = (snapshot?.documents ?? []).map { self.parseParticipant(id: $0.documentID, data: $0.data()) }
                DispatchQueue.main.async { self.participants = list }
            }
    }
    
    func stopListening() {
        roomListener?.remove()
        participantsListener?.remove()
        roomListener = nil
        participantsListener = nil
        DispatchQueue.main.async {
            self.currentRoom = nil
            self.participants = []
        }
    }
    
    // MARK: - Parse
    
    private func parseRoom(id: String, data: [String: Any]) -> TimeTrialRoom? {
        guard let periodEnd = (data["periodEnd"] as? Timestamp)?.dateValue() else { return nil }
        let periodStart = (data["periodStart"] as? Timestamp)?.dateValue() ?? Date()
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return TimeTrialRoom(
            id: id,
            distanceKm: data["distanceKm"] as? Double ?? 5.0,
            rankTier: data["rankTier"] as? String ?? "E",
            periodStart: periodStart,
            periodEnd: periodEnd,
            createdAt: createdAt
        )
    }
    
    private func parseParticipant(id: String, data: [String: Any]) -> TimeTrialParticipant {
        let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue() ?? Date()
        let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue()
        return TimeTrialParticipant(
            id: id,
            name: data["name"] as? String ?? "",
            rank: (data["rank"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            joinedAt: joinedAt,
            submittedTimeSeconds: data["submittedTimeSeconds"] as? Double,
            submittedAt: submittedAt
        )
    }
}

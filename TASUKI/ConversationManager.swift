//
//  ConversationManager.swift
//  TASUKI
//
//  チャット・メッセージの会話をバックエンド（Firestore）で一意ID管理
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

/// 未読数表示用の共通ベース（@EnvironmentObject は具象型が必要なためクラスで定義）
class UnreadCountProviderBase: ObservableObject {
    @Published var unreadCount: Int = 0
    func refreshUnreadCount(completion: (() -> Void)? = nil) { completion?() }
}

final class ConversationManager: UnreadCountProviderBase {
    static let shared = ConversationManager()
    private let db = Firestore.firestore()
    
    private override init() { super.init() }
    
    var currentUserId: String? { Auth.auth().currentUser?.uid }
    
    /// 新規会話を開始し、バックエンドで一意の会話IDを発行して返す
    func createConversation(partnerUserId: String, partnerName: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let myUid = currentUserId else {
            completion(.failure(NSError(domain: "ConversationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未ログイン"])))
            return
        }
        let ref = db.collection("conversations").document()
        let now = Timestamp(date: Date())
        var data: [String: Any] = [
            "participantIds": [myUid, partnerUserId],
            "partnerName": partnerName,
            "createdAt": now,
            "lastMessageAt": now
        ]
        // 作成者は既読扱い（lastReadAt を設定）
        data["lastReadAt"] = [myUid: now]
        ref.setData(data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(ref.documentID))
            }
        }
    }
    
    /// 既存の会話IDを取得（自分と相手の組み合わせで検索）。無ければ nil
    func findExistingConversation(partnerUserId: String, completion: @escaping (Result<String?, Error>) -> Void) {
        guard let myUid = currentUserId else {
            completion(.failure(NSError(domain: "ConversationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未ログイン"])))
            return
        }
        db.collection("conversations")
            .whereField("participantIds", arrayContains: myUid)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                let doc = snapshot?.documents.first { doc in
                    let ids = doc.data()["participantIds"] as? [String] ?? []
                    return ids.contains(partnerUserId) && ids.contains(myUid)
                }
                completion(.success(doc?.documentID))
            }
    }
    
    /// 練習会に紐づくチャットを新規作成（practiceID 作成時に呼ぶ）。会話ID（chatID）を返す
    func createPracticeConversation(practiceId: String, hostUserId: String, practiceTitle: String, completion: @escaping (Result<String, Error>) -> Void) {
        let ref = db.collection("conversations").document()
        let now = Timestamp(date: Date())
        let partnerName = "練習会: \(practiceTitle)"
        var data: [String: Any] = [
            "participantIds": [hostUserId],
            "partnerName": partnerName,
            "practiceId": practiceId,
            "createdAt": now,
            "lastMessageAt": now,
            "lastReadAt": [hostUserId: now]
        ]
        ref.setData(data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(ref.documentID))
            }
        }
    }
    
    /// 練習会チャットに参加者を追加（参加者が MessageListView でそのチャットに参加できるようにする）
    func addParticipantToPracticeChat(conversationId: String, userId: String, completion: ((Error?) -> Void)? = nil) {
        let ref = db.collection("conversations").document(conversationId)
        ref.getDocument { [weak self] snapshot, error in
            if let error = error {
                completion?(error)
                return
            }
            guard let data = snapshot?.data(),
                  var ids = data["participantIds"] as? [String] else {
                completion?(NSError(domain: "ConversationManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "会話が見つかりません"]))
                return
            }
            if ids.contains(userId) {
                completion?(nil)
                return
            }
            ids.append(userId)
            ref.updateData(["participantIds": ids]) { err in
                completion?(err)
            }
        }
    }
    
    /// 会話開始: 既存があればそのID、無ければ新規作成してIDを返す
    func startOrGetConversation(partnerUserId: String, partnerName: String, completion: @escaping (Result<String, Error>) -> Void) {
        findExistingConversation(partnerUserId: partnerUserId) { [weak self] result in
            switch result {
            case .failure(let e):
                completion(.failure(e))
            case .success(let existingId):
                if let id = existingId {
                    completion(.success(id))
                } else {
                    self?.createConversation(partnerUserId: partnerUserId, partnerName: partnerName, completion: completion)
                }
            }
        }
    }
    
    /// 自分の会話一覧を取得（バックエンドの一意ID付き）
    func fetchMyConversations(completion: @escaping (Result<[MessageConversation], Error>) -> Void) {
        guard let myUid = currentUserId else {
            completion(.failure(NSError(domain: "ConversationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未ログイン"])))
            return
        }
        db.collection("conversations")
            .whereField("participantIds", arrayContains: myUid)
            .order(by: "lastMessageAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                let list = (snapshot?.documents ?? []).map { doc in
                    let data = doc.data()
                    let partnerName = data["partnerName"] as? String ?? ""
                    let lastMessage = data["lastMessage"] as? String ?? ""
                    let lastMessageAt = (data["lastMessageAt"] as? Timestamp)?.dateValue() ?? (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let lastReadAt: Date? = {
                        guard let map = data["lastReadAt"] as? [String: Timestamp],
                              let ts = map[myUid] else { return nil }
                        return ts.dateValue()
                    }()
                    let hasUnread = lastMessageAt > (lastReadAt ?? .distantPast)
                    return MessageConversation(
                        conversationId: doc.documentID,
                        partnerName: partnerName,
                        avatarImage: "person.circle.fill",
                        lastMessage: lastMessage.isEmpty ? "メッセージがありません" : lastMessage,
                        timestamp: lastMessageAt,
                        hasUnread: hasUnread
                    )
                }
                completion(.success(list))
            }
    }
    
    /// 会話を既読にする（lastReadAt を更新）
    func markConversationAsRead(conversationId: String, completion: ((Error?) -> Void)? = nil) {
        guard let myUid = currentUserId else {
            completion?(NSError(domain: "ConversationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未ログイン"]))
            return
        }
        let now = Timestamp(date: Date())
        db.collection("conversations").document(conversationId).updateData(["lastReadAt.\(myUid)": now]) { error in
            DispatchQueue.main.async {
                if error == nil { self.refreshUnreadCount() }
                completion?(error)
            }
        }
    }
    
    /// 未読会話数を再取得して unreadCount を更新（HomeView のバッジ用）
    override func refreshUnreadCount(completion: (() -> Void)? = nil) {
        guard currentUserId != nil else {
            DispatchQueue.main.async { self.unreadCount = 0; completion?() }
            return
        }
        fetchMyConversations { [weak self] result in
            switch result {
            case .success(let list):
                let count = list.filter { $0.hasUnread }.count
                DispatchQueue.main.async {
                    self?.unreadCount = count
                    completion?()
                }
            case .failure:
                DispatchQueue.main.async {
                    self?.unreadCount = 0
                    completion?()
                }
            }
        }
    }
    
    // MARK: - Messages（conversationId に紐づく。各メッセージは replyToMessageId で返信先を参照可能）
    
    /// メッセージを送信し、バックエンドで発行された messageId を返す
    func sendMessage(conversationId: String, text: String, replyToMessageId: String?, completion: @escaping (Result<String, Error>) -> Void) {
        guard let myUid = currentUserId else {
            completion(.failure(NSError(domain: "ConversationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未ログイン"])))
            return
        }
        let ref = db.collection("conversations").document(conversationId).collection("messages").document()
        let now = Timestamp(date: Date())
        var data: [String: Any] = [
            "text": text,
            "senderId": myUid,
            "timestamp": now
        ]
        if let replyId = replyToMessageId, !replyId.isEmpty {
            data["replyToMessageId"] = replyId
        }
        ref.setData(data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(ref.documentID))
            }
        }
    }
    
    /// 会話のメッセージ一覧を取得（replyToMessageId 付き）
    func fetchMessages(conversationId: String, completion: @escaping (Result<[ChatMessage], Error>) -> Void) {
        guard let myUid = currentUserId else {
            completion(.failure(NSError(domain: "ConversationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "未ログイン"])))
            return
        }
        db.collection("conversations").document(conversationId).collection("messages")
            .order(by: "timestamp", descending: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                let list = (snapshot?.documents ?? []).map { doc in
                    let data = doc.data()
                    let text = data["text"] as? String ?? ""
                    let senderId = data["senderId"] as? String ?? ""
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let replyToMessageId = data["replyToMessageId"] as? String
                    return ChatMessage(
                        id: doc.documentID,
                        text: text,
                        isFromMe: senderId == myUid,
                        timestamp: timestamp,
                        replyToMessageId: replyToMessageId
                    )
                }
                completion(.success(list))
            }
    }
}

// MARK: - プレビュー用モック（Firebase に触れず HomeView プレビューを表示）
final class PreviewUnreadProvider: UnreadCountProviderBase {
    override init() { super.init() }
    init(unreadCount: Int = 0) { super.init(); self.unreadCount = unreadCount }
}

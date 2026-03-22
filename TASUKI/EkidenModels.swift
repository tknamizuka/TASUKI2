//
//  EkidenModels.swift
//  TASUKI
//
//  バーチャル駅伝: イベント・エントリー・区間・襷状態・提出の Firestore モデル
//

import Foundation
import FirebaseFirestore

// MARK: - Firestore Collection Paths

/// Firestore コレクション・パス定数
enum EkidenFirestorePaths {
    static let events = "ekiden_events"
    static let entries = "ekiden_entries"
    static let legs = "legs"
    static let submissions = "submissions"
    static let rankings = "rankings"

    static func event(_ eventId: String) -> String { "\(events)/\(eventId)" }
    static func entry(_ entryId: String) -> String { "\(entries)/\(entryId)" }
    static func entryLegs(_ entryId: String) -> String { "\(entries)/\(entryId)/\(legs)" }
    static func entrySubmissions(_ entryId: String) -> String { "\(entries)/\(entryId)/\(submissions)" }
}

// MARK: - Ekiden Event Status

/// 駅伝イベントのステータス
enum EkidenEventStatus: String, Codable {
    case scheduled = "scheduled"   // 予定
    case active = "active"         // 開催中
    case finished = "finished"     // 終了
}

// MARK: - Ekiden Leg Status（襷リレー状態）

/// 区間の襷状態: 未開始 → 前区間完了待ち → 襷渡し済み・提出可能 → 提出済み
enum EkidenLegStatus: String, Codable {
    case awaitingTasuki = "awaitingTasuki"   // 前区間の襷待ち
    case ready = "ready"                     // 襷渡し済み・提出可能
    case submitted = "submitted"             // 提出済み
}

// MARK: - EkidenEvent（Firestore: ekiden_events/{eventId}）

/// 駅伝イベント定義: 開催期間、区間数、各区間の目標距離（参考値）、ルール文
struct EkidenEvent: Identifiable {
    let id: String
    let startAt: Date
    let endAt: Date
    let legCount: Int
    /// 各区間の目標距離（km）の配列。インデックスが区間番号（0=1区）
    let legs: [EkidenLegDefinition]
    let status: EkidenEventStatus
    let rulesText: String?
    let createdAt: Date
    
    /// イベント期間内であるか
    var isWithinEventWindow: Bool {
        let now = Date()
        return now >= startAt && now <= endAt
    }
    
    /// イベント終了済みであるか
    var isFinished: Bool {
        Date() > endAt || status == .finished
    }
}

/// 区間定義（イベント側）: 順番と目標距離
struct EkidenLegDefinition: Identifiable {
    let id: Int  // 区間番号（0-indexed、0=1区）
    let targetKm: Double
    let order: Int  // 走順（1区=1, 2区=2, ...）
}

// MARK: - EkidenEntry（Firestore: ekiden_entries/{entryId}）

/// チームの駅伝エントリー: チーム・イベント・オーナー・襷状態
struct EkidenEntry: Identifiable {
    let id: String
    let teamId: String
    let eventId: String
    let ownerUid: String
    /// 現在進行中の区間インデックス（0-indexed）
    var currentLegIndex: Int
    /// 襷の状態（オプションでCloud Functionsが管理）
    var tasukiState: String?
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - EkidenLeg（Firestore: ekiden_entries/{entryId}/legs/{legIndex}）

/// エントリー内の区間: 担当者・目標距離・襷状態・提出結果
struct EkidenLeg: Identifiable {
    let id: Int  // legIndex（0=1区）
    let assignedUid: String?
    let targetKm: Double
    var status: EkidenLegStatus
    var submittedAt: Date?
    var actualDistanceKm: Double?
    var elapsedSeconds: Double?
    /// 目標距離未達で提出した場合は true
    var isUnderTarget: Bool
    /// 目標距離超過時に、目標距離到達時点の通過タイム（秒）。超過時のみ
    var splitAtTargetSeconds: Double?
    
    var isSubmitted: Bool { status == .submitted }
    
    /// 襷が渡っていて提出可能か
    var canSubmit: Bool { status == .ready }
}

// MARK: - EkidenSubmission（Firestore: ekiden_entries/{entryId}/submissions/{submissionId}）

/// 提出の監査ログ: ソース、走行アクティビティID等
struct EkidenSubmission: Identifiable {
    let id: String
    let legIndex: Int
    let submittedByUid: String
    let submittedAt: Date
    let source: String           // "health_kit" | "manual" | "time_trial" 等
    let runActivityId: String?   // HealthKit 等の記録ID
    let actualDistanceKm: Double
    let elapsedSeconds: Double
    let isUnderTarget: Bool
    let splitAtTargetSeconds: Double?
}

// MARK: - Firestore パースヘルパー

extension EkidenEvent {
    /// Firestore ドキュメントからパース
    /// legs は目標距離の配列 [Double] または [{targetKm: Double}, ...] 形式をサポート
    static func parse(id: String, data: [String: Any]) -> EkidenEvent? {
        guard let startTs = data["startAt"] as? Timestamp,
              let endTs = data["endAt"] as? Timestamp else { return nil }
        let legCount = data["legCount"] as? Int ?? 0
        let legs: [EkidenLegDefinition]
        if let numbers = data["legs"] as? [Double] {
            legs = numbers.enumerated().map { EkidenLegDefinition(id: $0.offset, targetKm: $0.element, order: $0.offset + 1) }
        } else if let legsData = data["legs"] as? [[String: Any]] {
            legs = legsData.enumerated().compactMap { index, legData -> EkidenLegDefinition? in
                guard let targetKm = legData["targetKm"] as? Double else { return nil }
                return EkidenLegDefinition(id: index, targetKm: targetKm, order: index + 1)
            }
        } else {
            legs = (0..<max(1, legCount)).map { EkidenLegDefinition(id: $0, targetKm: 5.0, order: $0 + 1) }
        }
        let statusRaw = data["status"] as? String ?? EkidenEventStatus.scheduled.rawValue
        let status = EkidenEventStatus(rawValue: statusRaw) ?? .scheduled
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return EkidenEvent(
            id: id,
            startAt: startTs.dateValue(),
            endAt: endTs.dateValue(),
            legCount: max(legCount, legs.count),
            legs: legs.isEmpty ? (0..<max(1, legCount)).map { EkidenLegDefinition(id: $0, targetKm: 5.0, order: $0 + 1) } : legs,
            status: status,
            rulesText: data["rulesText"] as? String,
            createdAt: createdAt
        )
    }
}

extension EkidenEntry {
    /// Firestore ドキュメントからパース
    static func parse(id: String, data: [String: Any]) -> EkidenEntry? {
        guard let teamId = data["teamId"] as? String,
              let eventId = data["eventId"] as? String,
              let ownerUid = data["ownerUid"] as? String else { return nil }
        let currentLegIndex = data["currentLegIndex"] as? Int ?? 0
        let tasukiState = data["tasukiState"] as? String
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
        return EkidenEntry(
            id: id,
            teamId: teamId,
            eventId: eventId,
            ownerUid: ownerUid,
            currentLegIndex: currentLegIndex,
            tasukiState: tasukiState,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension EkidenLeg {
    /// Firestore ドキュメントからパース（legs サブコレクションのドキュメントIDが legIndex）
    static func parse(legIndex: Int, data: [String: Any]) -> EkidenLeg {
        let statusRaw = data["status"] as? String ?? EkidenLegStatus.awaitingTasuki.rawValue
        let status = EkidenLegStatus(rawValue: statusRaw) ?? .awaitingTasuki
        let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue()
        let actualDistanceKm = data["actualDistanceKm"] as? Double
        let elapsedSeconds = data["elapsedSeconds"] as? Double
        let isUnderTarget = data["isUnderTarget"] as? Bool ?? false
        let splitAtTargetSeconds = data["splitAtTargetSeconds"] as? Double
        return EkidenLeg(
            id: legIndex,
            assignedUid: data["assignedUid"] as? String,
            targetKm: data["targetKm"] as? Double ?? 5.0,
            status: status,
            submittedAt: submittedAt,
            actualDistanceKm: actualDistanceKm,
            elapsedSeconds: elapsedSeconds,
            isUnderTarget: isUnderTarget,
            splitAtTargetSeconds: splitAtTargetSeconds
        )
    }
}

extension EkidenSubmission {
    /// Firestore ドキュメントからパース
    static func parse(id: String, data: [String: Any]) -> EkidenSubmission? {
        guard let legIndex = data["legIndex"] as? Int,
              let submittedByUid = data["submittedByUid"] as? String,
              let source = data["source"] as? String,
              let actualDistanceKm = data["actualDistanceKm"] as? Double,
              let elapsedSeconds = data["elapsedSeconds"] as? Double else { return nil }
        let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue() ?? Date()
        let isUnderTarget = data["isUnderTarget"] as? Bool ?? false
        let splitAtTargetSeconds = data["splitAtTargetSeconds"] as? Double
        return EkidenSubmission(
            id: id,
            legIndex: legIndex,
            submittedByUid: submittedByUid,
            submittedAt: submittedAt,
            source: source,
            runActivityId: data["runActivityId"] as? String,
            actualDistanceKm: actualDistanceKm,
            elapsedSeconds: elapsedSeconds,
            isUnderTarget: isUnderTarget,
            splitAtTargetSeconds: splitAtTargetSeconds
        )
    }
}

//
//  RaceModels.swift
//  TASUKI
//
//  距離別マッチング・同時スタート・走行タイムで競うレース用モデル
//

import Foundation
import FirebaseFirestore

// MARK: - Live Race Category（事前設定カテゴリ: 5km / 10km / ハーフ）
enum LiveRaceCategory: String, CaseIterable, Identifiable {
    case fiveK = "5k"
    case tenK = "10k"
    case half = "half"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .fiveK: return "5km"
        case .tenK: return "10km"
        case .half: return "ハーフ"
        }
    }
    
    var targetDistanceKm: Double {
        switch self {
        case .fiveK: return 5.0
        case .tenK: return 10.0
        case .half: return 21.0975
        }
    }
}

// MARK: - Race Status
enum RaceStatus: String, Codable {
    case waiting = "waiting"   // 参加者待ち
    case starting = "starting" // カウントダウン中
    case running = "running"   // レース中
    case finished = "finished" // 終了
}

// MARK: - Race（Firestore の races ドキュメント）
struct Race: Identifiable {
    let id: String
    let distanceCategory: String  // "5k", "10k", "half"
    let targetDistanceKm: Double
    var status: RaceStatus
    var startTime: Date?
    let createdAt: Date
    let hostUserId: String?
    
    var category: LiveRaceCategory? {
        LiveRaceCategory(rawValue: distanceCategory)
    }
}

// MARK: - Race Participant（Firestore の participants サブコレクション）
struct RaceParticipant: Identifiable {
    let id: String  // userId
    let name: String
    let rank: String?
    var currentDistanceKm: Double
    var finishTimeSeconds: Double?  // ゴールした場合のスタートからの経過秒数
    let joinedAt: Date
    
    var isFinished: Bool { finishTimeSeconds != nil }
}

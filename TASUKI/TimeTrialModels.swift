//
//  TimeTrialModels.swift
//  TASUKI
//
//  タイムトライアル: 5〜15km の対戦部屋・同ランク20名・1週間で1回走ってタイムで順位・ポイント
//  EKIDEN MODE とは別機能
//

import Foundation
import FirebaseFirestore

// MARK: - タイムトライアル距離（5〜15km）
enum TimeTrialDistance: String, CaseIterable, Identifiable {
    case fiveK = "5k"
    case tenK = "10k"
    case fifteenK = "15k"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .fiveK: return "5km"
        case .tenK: return "10km"
        case .fifteenK: return "15km"
        }
    }
    
    var distanceKm: Double {
        switch self {
        case .fiveK: return 5.0
        case .tenK: return 10.0
        case .fifteenK: return 15.0
        }
    }
}

// MARK: - 部屋（1週間の期間・同ランク最大20名）
struct TimeTrialRoom: Identifiable {
    let id: String
    let distanceKm: Double
    let rankTier: String       // "S", "A", "B", "C", "D", "E"
    let periodStart: Date
    let periodEnd: Date
    let createdAt: Date
    
    var isInPeriod: Bool {
        let now = Date()
        return now >= periodStart && now <= periodEnd
    }
    
    var periodLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d"
        return "\(f.string(from: periodStart)) 〜 \(f.string(from: periodEnd))"
    }
}

// MARK: - 参加者（1部屋あたり1回だけタイム提出可）
struct TimeTrialParticipant: Identifiable {
    let id: String             // userId
    let name: String
    let rank: String?
    let joinedAt: Date
    var submittedTimeSeconds: Double?  // 提出済みなら記録（秒）
    var submittedAt: Date?
    
    var isSubmitted: Bool { submittedTimeSeconds != nil }
    
    var timeLabel: String? {
        guard let sec = submittedTimeSeconds else { return nil }
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        if m >= 60 {
            let h = m / 60
            let mm = m % 60
            return String(format: "%d:%02d:%02d", h, mm, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - 順位付き参加者（結果表示用）
struct TimeTrialRankingEntry: Identifiable {
    let id: String
    let rank: Int
    let name: String
    let timeSeconds: Double
    let points: Int
    
    var timeLabel: String {
        let m = Int(timeSeconds) / 60
        let s = Int(timeSeconds) % 60
        if m >= 60 {
            let h = m / 60
            let mm = m % 60
            return String(format: "%d:%02d:%02d", h, mm, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - 順位→ポイント（20名想定）
enum TimeTrialPoints {
    private static let pointsTable: [Int] = [
        100, 90, 81, 73, 66, 59, 53, 48, 43, 39,
        35, 31, 28, 25, 22, 20, 18, 16, 14, 12
    ]
    
    static func points(forRank rank: Int) -> Int {
        guard rank >= 1, rank <= 20 else { return 0 }
        return pointsTable[rank - 1]
    }
}

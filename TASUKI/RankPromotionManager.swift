import Foundation

/// ユーザーランクの昇格条件を判定して `UserDefaults("myRank")` を更新するマネージャ
///
/// - ランク表記は `"Rank S"` 〜 `"Rank E"` を想定
/// - 降格は行わず、昇格のみ行う
final class RankPromotionManager {
    static let shared = RankPromotionManager()
    
    private init() {}
    
    // MARK: - Public API
    
    /// 当月走行距離に基づいて昇格判定を行う（Home から呼び出し）
    /// - Parameter monthlyKm: HealthKit から取得した当月走行距離 (km)
    func evaluateMonthlyDistancePromotion(monthlyKm: Double) {
        let currentRank = currentRankString()
        let newRank = promotedRankByDistance(currentRank: currentRank, monthlyKm: monthlyKm)
        applyPromotionIfNeeded(from: currentRank, to: newRank, reason: "distance")
    }
    
    /// タイムトライアルの順位結果に基づいて昇格判定を行う
    /// - Parameters:
    ///   - entries: 現在の部屋の順位リスト
    ///   - myUserId: 現在ユーザーの ID（TimeTrialParticipant.id と同一）
    func evaluateTimeTrialPromotion(entries: [TimeTrialRankingEntry], myUserId: String?) {
        guard let myUserId = myUserId else { return }
        let currentRank = currentRankString()
        let newRank = promotedRankByTimeTrial(currentRank: currentRank, entries: entries, myUserId: myUserId)
        applyPromotionIfNeeded(from: currentRank, to: newRank, reason: "timeTrial")
    }
    
    // MARK: - Core Logic
    
    /// UserDefaults から現在のランク文字列を取得（未設定なら Rank E）
    private func currentRankString() -> String {
        if let stored = UserDefaults.standard.string(forKey: "myRank"), !stored.isEmpty {
            return stored
        }
        return "Rank E"
    }
    
    /// ランク文字列 `"Rank A"` -> ティア `"A"` に変換
    private func rankTier(from rank: String) -> String {
        guard rank.hasPrefix("Rank ") else { return "E" }
        let tier = String(rank.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        return tier.isEmpty ? "E" : tier
    }
    
    /// ランクティアをインデックスに変換（小さいほど上位）
    private func rankIndex(for tier: String) -> Int {
        // 上位から: S, A, B, C, D, E
        let order: [String] = ["S", "A", "B", "C", "D", "E"]
        return order.firstIndex(of: tier) ?? order.count - 1
    }
    
    /// インデックスから `"Rank X"` を生成
    private func rankString(fromIndex index: Int) -> String {
        let order: [String] = ["S", "A", "B", "C", "D", "E"]
        let safeIndex = max(0, min(index, order.count - 1))
        return "Rank \(order[safeIndex])"
    }
    
    /// 月間距離ベースの昇格判定
    ///
    /// - E -> D: 月間 100km 以上
    /// - D -> C: 月間 150km 以上
    /// - C 以上は距離のみでは昇格しない（タイムトライアルで昇格）
    private func promotedRankByDistance(currentRank: String, monthlyKm: Double) -> String {
        let tier = rankTier(from: currentRank)
        let idx = rankIndex(for: tier)
        
        // すでに C 以上なら距離では昇格しない
        if idx <= rankIndex(for: "C") {
            return currentRank
        }
        
        switch tier {
        case "E":
            if monthlyKm >= 100 {
                return "Rank D"
            }
        case "D":
            if monthlyKm >= 150 {
                return "Rank C"
            }
        default:
            break
        }
        return currentRank
    }
    
    /// タイムトライアル結果ベースの昇格判定
    ///
    /// - C -> B: 上位 30% 以内
    /// - B -> A: 上位 20% 以内
    /// - A -> S: 上位 10% 以内
    /// - D/E -> C: 上位 20% 以内
    private func promotedRankByTimeTrial(currentRank: String, entries: [TimeTrialRankingEntry], myUserId: String) -> String {
        guard !entries.isEmpty else { return currentRank }
        
        let tier = rankTier(from: currentRank)
        let total = entries.count
        guard let myEntry = entries.first(where: { $0.id == myUserId }) else {
            return currentRank
        }
        let myRankPosition = myEntry.rank
        
        func percentileThreshold(_ ratio: Double) -> Int {
            return max(1, Int(ceil(Double(total) * ratio)))
        }
        
        switch tier {
        case "E", "D":
            // 下位ランクからのジャンプアップ: 上位20%以内なら C へ
            if myRankPosition <= percentileThreshold(0.2) {
                return "Rank C"
            }
        case "C":
            if myRankPosition <= percentileThreshold(0.3) {
                return "Rank B"
            }
        case "B":
            if myRankPosition <= percentileThreshold(0.2) {
                return "Rank A"
            }
        case "A":
            if myRankPosition <= percentileThreshold(0.1) {
                return "Rank S"
            }
        default:
            break
        }
        return currentRank
    }
    
    /// 昇格が発生した場合に UserDefaults を更新
    private func applyPromotionIfNeeded(from current: String, to newRank: String, reason: String) {
        guard newRank != current else { return }
        
        let currentTier = rankTier(from: current)
        let newTier = rankTier(from: newRank)
        let currentIdx = rankIndex(for: currentTier)
        let newIdx = rankIndex(for: newTier)
        
        // 降格はしない
        guard newIdx < currentIdx else { return }
        
        UserDefaults.standard.set(newRank, forKey: "myRank")
    }
}


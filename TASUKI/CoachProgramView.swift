import SwiftUI

struct CoachProgramView: View {
    @ObservedObject private var activityStore = RunActivityStore.shared
    @ObservedObject private var planStore = TrainingPlanStore.shared

    private var recommendationText: String {
        let weeklyRuns = activityStore.weeklyRunCount()
        switch weeklyRuns {
        case 0:
            return "まずは週2回から。短時間のEASY RUNを習慣化しましょう。"
        case 1...2:
            return "頻度は良い流れです。今週は1回だけ少し強度を上げるのがおすすめです。"
        case 3...4:
            return "十分な走行頻度です。疲労管理を優先しつつ、質を上げていきましょう。"
        default:
            return "高頻度で走れています。休養日を計画的に入れて故障予防を徹底しましょう。"
        }
    }

    private var recommendedBlocks: [String] {
        switch planStore.selectedTemplate {
        case .finish:
            return [
                "フォーム基礎（接地と姿勢）",
                "EASY RUNの呼吸管理",
                "継続のための週間リズム設計"
            ]
        case .sub4:
            return [
                "テンポ走の強度調整",
                "ロング走後半の失速対策",
                "レース4週間前の調整戦略"
            ]
        case .sub3:
            return [
                "閾値走のペース精度向上",
                "高強度週の疲労マネジメント",
                "30km走の補給最適化"
            ]
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                heroCard
                recommendationCard
                blocksCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.tasukiDarkBackground.ignoresSafeArea())
        .navigationTitle("Coach Program")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COACH PROGRAM")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundColor(Color.tasukiMutedText)
            Text("プランと実績に応じた実践メニュー")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.tasukiPrimary)
            Text("現在のプラン: \(planStore.selectedTemplate.displayName)")
                .font(.footnote)
                .foregroundColor(Color.tasukiAccent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tasukiCard()
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今週のコーチコメント")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.tasukiPrimary)
            Text(recommendationText)
                .font(.system(size: 14))
                .foregroundColor(Color.tasukiMutedText)
        }
        .tasukiCard()
    }

    private var blocksCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("推奨モジュール")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.tasukiPrimary)
            ForEach(recommendedBlocks, id: \.self) { block in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color.tasukiAccent)
                    Text(block)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.tasukiPrimary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .tasukiCard()
    }
}

#Preview {
    NavigationStack {
        CoachProgramView()
    }
}

import SwiftUI

struct TrainingPlanView: View {
    @ObservedObject private var planStore = TrainingPlanStore.shared
    @ObservedObject private var activityStore = RunActivityStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard
                templatePickerCard
                weekSummaryCard
                sessionsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.tasukiDarkBackground.ignoresSafeArea())
        .navigationTitle("Training Plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PLAN")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundColor(Color.tasukiMutedText)
            Text("目標別メニューを選んで、今週の達成率を管理")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.tasukiPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tasukiCard()
    }

    private var templatePickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("テンプレート")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.tasukiPrimary)
            Picker("テンプレート", selection: $planStore.selectedTemplate) {
                ForEach(TrainingPlanTemplate.allCases) { template in
                    Text(template.displayName).tag(template)
                }
            }
            .pickerStyle(.segmented)
            Text(planStore.selectedTemplate.summary)
                .font(.footnote)
                .foregroundColor(Color.tasukiMutedText)
        }
        .tasukiCard()
    }

    private var weekSummaryCard: some View {
        let weeklyRuns = activityStore.weeklyRunCount()
        let completion = Int(planStore.completionRate * 100)
        return VStack(alignment: .leading, spacing: 8) {
            Text("今週の進捗")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.tasukiPrimary)
            HStack {
                stat(title: "プラン達成率", value: "\(completion)%")
                stat(title: "実走回数", value: "\(weeklyRuns)回")
                stat(title: "今月距離", value: String(format: "%.1fkm", activityStore.monthlyDistanceKm()))
            }
        }
        .tasukiCard()
    }

    private var sessionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今週のメニュー")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.tasukiPrimary)
            ForEach(planStore.sessions) { session in
                Button {
                    planStore.toggleCompletion(for: session)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: planStore.isCompleted(session) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(planStore.isCompleted(session) ? Color.green : Color.tasukiMutedText)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(session.dayLabel)
                                    .font(.caption)
                                    .foregroundColor(Color.tasukiMutedText)
                                Text(session.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.tasukiPrimary)
                            }
                            Text("\(session.detail) · 目安\(String(format: "%.0f", session.targetKm))km")
                                .font(.caption)
                                .foregroundColor(Color.tasukiMutedText)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
        .tasukiCard()
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(Color.tasukiMutedText)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.tasukiPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        TrainingPlanView()
    }
}

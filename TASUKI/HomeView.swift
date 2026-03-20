//
//  HomeView.swift
//  TASUKI
//
//  Created by yoshi H on 2026/01/28.
//

import SwiftUI

struct HomeView: View {
    // 目標管理用のデータ（currentDistance は HealthKit から取得）
    @State private var currentDistance: Double
    @State private var goalDistance: Double
    @State private var isHealthKitLoading: Bool
    @State private var healthKitError: String?
    
    /// プレビュー用: true のときは onAppear で HealthKit を読まない
    private let usePreviewData: Bool
    
    @State private var showRunHistory = false
    @State private var showPracticeCalendar = false
    @StateObject private var behaviorFeatureManager = BehaviorFeatureManager()
    @EnvironmentObject private var unreadProvider: UnreadCountProviderBase
    @EnvironmentObject private var joinedPracticesStore: JoinedPracticesStore
    @AppStorage("runningDataSource") private var runningDataSourceRaw: String = RunningDataSource.all.rawValue
    init(
        currentDistance: Double = 0.0,
        goalDistance: Double = 100.0,
        isHealthKitLoading: Bool = true,
        healthKitError: String? = nil,
        usePreviewData: Bool = false
    ) {
        _currentDistance = State(initialValue: currentDistance)
        _goalDistance = State(initialValue: goalDistance)
        _isHealthKitLoading = State(initialValue: isHealthKitLoading)
        _healthKitError = State(initialValue: healthKitError)
        self.usePreviewData = usePreviewData
    }
    
    // 進捗率（0.0〜1.0）
    var progress: CGFloat {
        return CGFloat(min(currentDistance / goalDistance, 1.0))
    }
    
    // 進捗率（%整数）
    var progressPercent: Int {
        return Int((currentDistance / goalDistance) * 100)
    }

    private var selectedRunningDataSource: RunningDataSource {
        RunningDataSource(rawValue: runningDataSourceRaw) ?? .all
    }
    
    var body: some View {
        ZStack {
            Color.tasukiDarkBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RUN DASHBOARD")
                            .font(.caption)
                            .fontWeight(.bold)
                            .tracking(2)
                            .foregroundColor(Color.tasukiMutedText)
                        Text("TASUKI")
                            .font(.system(size: 36, weight: .heavy))
                            .tracking(4)
                            .foregroundColor(Color.tasukiPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.tasukiSurface, Color.white],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                    Button {
                        if !isHealthKitLoading { showRunHistory = true }
                    } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("MONTHLY GOAL")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .tracking(1.5)
                                    .foregroundColor(Color.tasukiMutedText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color.tasukiMutedText)
                            }

                            HStack(spacing: 20) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                                        .frame(width: 114, height: 114)
                                    Circle()
                                        .trim(from: 0, to: progress)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.tasukiAccentOrange, Color.royalBlue],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                        )
                                        .frame(width: 114, height: 114)
                                        .rotationEffect(.degrees(-90))
                                    Text("\(progressPercent)%")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color.tasukiPrimary)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    if isHealthKitLoading {
                                        ProgressView()
                                        Text("同期中...")
                                            .font(.caption)
                                            .foregroundColor(Color.tasukiMutedText)
                                    } else {
                                        Text(String(format: "%.1fkm", currentDistance))
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(Color.tasukiPrimary)
                                        Text("目標 \(Int(goalDistance))km")
                                            .font(.subheadline)
                                            .foregroundColor(Color.tasukiMutedText)
                                        Text("ソース: \(selectedRunningDataSource.displayName)")
                                            .font(.caption2)
                                            .foregroundColor(Color.tasukiMutedText)
                                    }
                                }
                                Spacer()
                            }

                            if let error = healthKitError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(Color.tasukiAccentOrange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isHealthKitLoading)

                    HStack(spacing: 12) {
                        quickMetricCard(
                            title: "TOTAL POINTS",
                            value: "\(PointService.shared.currentTotalPoints())",
                            suffix: "pt",
                            icon: "flame.fill"
                        )
                        quickMetricCard(
                            title: "DATA SOURCE",
                            value: selectedRunningDataSource.displayName,
                            suffix: "",
                            icon: "waveform.path.ecg"
                        )
                    }

                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            NavigationLink(destination: RunRecordingView()) {
                                quickActionCard(
                                    title: "RUN RECORDER",
                                    subtitle: "走行を開始して記録",
                                    icon: "figure.run"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: ChallengeHubView()) {
                                quickActionCard(
                                    title: "CHALLENGES",
                                    subtitle: "月間目標と順位",
                                    icon: "flag.checkered.2.crossed"
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        NavigationLink(destination: TrainingPlanView()) {
                            HStack(spacing: 10) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color.tasukiAccent)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("TRAINING PLAN")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color.tasukiPrimary)
                                    Text("目標別の週間メニューを管理")
                                        .font(.caption)
                                        .foregroundColor(Color.tasukiMutedText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Color.tasukiMutedText)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    behaviorInsightsCard

                    NavigationLink(destination: RankingView()) {
                        Text("ランキングを確認する")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.tasukiPrimary)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 80)
            }
        }
        .sheet(isPresented: $showRunHistory) {
            RunHistoryListView()
        }
        .sheet(isPresented: $showPracticeCalendar) {
            PracticeScheduleCalendarView(store: joinedPracticesStore)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showPracticeCalendar = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundColor(Color.tasukiPrimary)
                        if joinedPracticesStore.scheduledCount > 0 {
                            Text("\(min(joinedPracticesStore.scheduledCount, 99))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color.tasukiAccentOrange))
                                .offset(x: 8, y: -8)
                        }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: MessageListView()) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.tasukiPrimary)
                        if unreadProvider.unreadCount > 0 {
                            Text("\(min(unreadProvider.unreadCount, 99))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color.tasukiAccentOrange))
                                .offset(x: 8, y: -8)
                        }
                    }
                }
            }
        }
        .onAppear {
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            if !usePreviewData, !isPreview {
                loadDistanceFromHealthKit()
            } else if isPreview {
                isHealthKitLoading = false
            }
            unreadProvider.refreshUnreadCount()
            behaviorFeatureManager.fetchLatestFeature()
        }
    }

    private func quickMetricCard(title: String, value: String, suffix: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(Color.tasukiAccentOrange)
            Text(title)
                .font(.caption2)
                .foregroundColor(Color.tasukiMutedText)
                .tracking(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.tasukiPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.caption)
                        .foregroundColor(Color.tasukiMutedText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
    }

    private func quickActionCard(title: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.tasukiAccent)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.tasukiPrimary)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(Color.tasukiMutedText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
    }

    private var behaviorInsightsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BEHAVIOR INSIGHTS")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundColor(Color.tasukiMutedText)

            Group {
                if behaviorFeatureManager.isLoading {
                    HStack {
                        ProgressView()
                        Text("行動特徴を読み込み中...")
                            .foregroundColor(Color.tasukiMutedText)
                    }
                } else if let feature = behaviorFeatureManager.latestFeature {
                    VStack(alignment: .leading, spacing: 6) {
                        statRow("週間ラン回数", "\(feature.weeklyRunCount) 回")
                        statRow("先週比", "\(feature.weeklyRunTrendDelta >= 0 ? "+" : "")\(feature.weeklyRunTrendDelta)")
                        statRow("継続スコア", "\(Int(feature.consistencyScore * 100))/100")
                        statRow("ソーシャル活動", "\(Int(feature.socialActivityScore * 100))/100")
                        statRow("週末アクティブ比率", "\(Int(feature.weekendActivityRatio * 100))%")
                    }
                } else if let error = behaviorFeatureManager.errorMessage {
                    Text("行動特徴の取得に失敗: \(error)")
                        .foregroundColor(Color.tasukiAccentOrange)
                } else {
                    Text("行動特徴データがまだありません")
                        .foregroundColor(Color.tasukiMutedText)
                }
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
    }

    private func statRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .foregroundColor(Color.tasukiMutedText)
            Spacer()
            Text(value)
                .foregroundColor(Color.tasukiPrimary)
                .fontWeight(.semibold)
        }
    }
    
    /// HealthKit から今月の走行距離を取得して currentDistance に反映
    private func loadDistanceFromHealthKit() {
        HealthKitManager.shared.requestAuthorization { success, error in
            if !success {
                isHealthKitLoading = false
                healthKitError = "HealthKit の利用を許可してください"
                return
            }
            HealthKitManager.shared.fetchRunningDistanceThisMonth(dataSource: selectedRunningDataSource) { result in
                isHealthKitLoading = false
                switch result {
                case .success(let km):
                    currentDistance = km
                    if km == 0, selectedRunningDataSource != .all {
                        healthKitError = "\(selectedRunningDataSource.displayName) の記録が見つかりません"
                    } else {
                        healthKitError = nil
                    }
                    // 距離ベースのランク昇格判定
                    RankPromotionManager.shared.evaluateMonthlyDistancePromotion(monthlyKm: km)
                case .failure(let err):
                    healthKitError = err.localizedDescription
                }
            }
        }
    }
}

#Preview("通常（読み込み中）") {
    NavigationStack {
        HomeView()
    }
    .environmentObject(PreviewUnreadProvider() as UnreadCountProviderBase)
    .environmentObject(JoinedPracticesStore())
}

#Preview("サンプル値") {
    NavigationStack {
        HomeView(
            currentDistance: 45.2,
            goalDistance: 100.0,
            isHealthKitLoading: false,
            usePreviewData: true
        )
    }
    .environmentObject(PreviewUnreadProvider() as UnreadCountProviderBase)
    .environmentObject(JoinedPracticesStore())
}

#Preview("未読・参加予定バッジあり") {
    let store = JoinedPracticesStore()
    store.add(JoinedPracticeItem(id: "1", practiceId: "p1", title: "皇居ラン", location: "皇居", date: Date(), chatId: nil))
    return NavigationStack {
        HomeView(
            currentDistance: 45.2,
            goalDistance: 100.0,
            isHealthKitLoading: false,
            usePreviewData: true
        )
    }
    .environmentObject(PreviewUnreadProvider(unreadCount: 3) as UnreadCountProviderBase)
    .environmentObject(store)
}

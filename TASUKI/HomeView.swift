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
    @EnvironmentObject private var unreadProvider: UnreadCountProviderBase
    @EnvironmentObject private var joinedPracticesStore: JoinedPracticesStore
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
    
    var body: some View {
        VStack(spacing: 40) {
            
            // 1. ブランドビジュアル
            ZStack {
                Image("runner")
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width * 0.9)
                    .opacity(0.15)
                
                Text("TASUKI")
                    .font(.system(size: 50, weight: .heavy))
                    .tracking(10)
                    .foregroundColor(Color(hex: "0F1A2E"))
                    .shadow(color: .white.opacity(0.8), radius: 2, x: 0, y: 0)
            }
            .padding(.top, 20)
            
            Spacer()
            
            // 2. 月間目標進捗 (％表示) — タップで走行履歴
            VStack(spacing: 15) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 250, height: 250)
                    
                    Circle()
                        .trim(from: 0.0, to: progress)
                        .stroke(Color(hex: "0F1A2E"), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .frame(width: 250, height: 250)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.0), value: progress)
                    
                    VStack(spacing: 5) {
                        if isHealthKitLoading {
                            ProgressView()
                                .scaleEffect(1.2)
                                .padding(.bottom, 8)
                            Text("読み込み中...")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            HStack(alignment: .lastTextBaseline, spacing: 5) {
                                Text("\(progressPercent)")
                                    .font(.system(size: 80, weight: .bold))
                                    .foregroundColor(Color(hex: "0F1A2E"))
                                
                                Text("%")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(Color(hex: "0F1A2E"))
                            }
                            
                            Text("\(String(format: "%.1f", currentDistance)) / \(Int(goalDistance)) km")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        }
                        if let error = healthKitError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .onTapGesture {
                    if !isHealthKitLoading { showRunHistory = true }
                }
                
                Text("MONTHLY GOAL（タップで履歴）")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .tracking(2)
            }
            .sheet(isPresented: $showRunHistory) {
                RunHistoryListView()
            }
            .sheet(isPresented: $showPracticeCalendar) {
                PracticeScheduleCalendarView(store: joinedPracticesStore)
            }
            
            Spacer()
            
            // 3. 保有ポイント（累計）表示
            VStack(spacing: 5) {
                Text("保有ポイント（累計）")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .tracking(2)
                
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text("\(PointService.shared.currentTotalPoints())")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(Color(hex: "0F1A2E"))
                    
                    Text("pt")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                }
                
                NavigationLink(destination: RankingView()) {
                    Text("ランキングを見る")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "2E5CFF"))
                        .padding(.top, 4)
                }
            }
            .padding(.bottom, 50)
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showPracticeCalendar = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "0F1A2E"))
                        if joinedPracticesStore.scheduledCount > 0 {
                            Text("\(min(joinedPracticesStore.scheduledCount, 99))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color(hex: "2E5CFF")))
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
                            .foregroundColor(Color(hex: "0F1A2E"))
                        if unreadProvider.unreadCount > 0 {
                            Text("\(min(unreadProvider.unreadCount, 99))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color.red))
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
            HealthKitManager.shared.fetchRunningDistanceThisMonth { result in
                isHealthKitLoading = false
                switch result {
                case .success(let km):
                    currentDistance = km
                    healthKitError = nil
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

//
//  TimeTrialView.swift
//  TASUKI
//
//  タイムトライアル: 5〜15km・同ランク20名・1週間で1回走ってタイムで順位・ポイント（EKIDENとは別）
//

import SwiftUI

// MARK: - エントリ（距離選択 → マッチング）
struct TimeTrialEntryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = TimeTrialManager.shared
    @AppStorage("myName") private var myName = "Runner"
    @AppStorage("myRank") private var myRank = "Rank B"
    
    @State private var selectedDistance: TimeTrialDistance = .fiveK
    @State private var isMatching = false
    @State private var matchedRoomId: String?
    @State private var matchError: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("距離を選んで同ランクの20名とマッチング")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                ForEach(TimeTrialDistance.allCases) { dist in
                    Button(action: {
                        selectedDistance = dist
                        startMatching()
                    }) {
                        HStack {
                            Text(dist.displayName)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: "0F1A2E"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedDistance == dist ? Color(hex: "2E5CFF").opacity(0.15) : Color(hex: "F5F7FA"))
                        )
                    }
                    .disabled(isMatching)
                }
                
                if isMatching {
                    ProgressView("マッチング中...")
                        .padding()
                }
                if let err = matchError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("タイムトライアル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(Color(hex: "0F1A2E"))
                }
            }
            .navigationDestination(item: $matchedRoomId) { roomId in
                TimeTrialRoomView(roomId: roomId, onDismiss: { dismiss() })
            }
        }
        .onAppear { matchError = nil }
    }
    
    private func startMatching() {
        isMatching = true
        matchError = nil
        manager.createOrJoinRoom(distance: selectedDistance, userRank: myRank, userName: myName) { result in
            isMatching = false
            switch result {
            case .success(let roomId):
                matchedRoomId = roomId
            case .failure(let e):
                matchError = e.localizedDescription
            }
        }
    }
}

// MARK: - 部屋画面（期間・参加者・タイム提出 or 結果）
struct TimeTrialRoomView: View {
    let roomId: String
    var onDismiss: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = TimeTrialManager.shared
    
    @State private var showSubmitSheet = false
    @State private var showResults = false
    @State private var inputMinutes = ""
    @State private var inputSeconds = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var ranking: [TimeTrialRankingEntry] = []
    
    enum RecordSource { case choose, healthKit, manual }
    @State private var recordSource: RecordSource = .choose
    @State private var healthKitWorkouts: [RunningWorkoutInfo] = []
    @State private var healthKitLoading = false
    @State private var healthKitError: String?
    
    private var myParticipant: TimeTrialParticipant? {
        manager.participants.first { $0.id == manager.currentUserId }
    }
    
    private var hasSubmitted: Bool {
        myParticipant?.isSubmitted ?? false
    }
    
    var body: some View {
        Group {
            if let room = manager.currentRoom {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 期間・距離・ランク
                        VStack(alignment: .leading, spacing: 8) {
                            Text(room.periodLabel)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("\(room.distanceKm.clean) km · Rank \(room.rankTier)")
                                .font(.headline)
                                .foregroundColor(Color(hex: "0F1A2E"))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(hex: "F5F7FA"))
                        .cornerRadius(12)
                        
                        Text("参加者 \(manager.participants.count) / 20 名")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        if hasSubmitted {
                            Button(action: { loadRanking(); showResults = true }) {
                                HStack {
                                    Text("結果を見る")
                                    Image(systemName: "chart.bar.fill")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "2E5CFF"))
                                .cornerRadius(12)
                            }
                        } else {
                            Button(action: { showSubmitSheet = true }) {
                                HStack {
                                    Text("タイムを記録する")
                                    Image(systemName: "stopwatch.fill")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "0F1A2E"))
                                .cornerRadius(12)
                            }
                        }
                        
                        Divider()
                        Text("参加者一覧")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "0F1A2E"))
                        ForEach(manager.participants) { p in
                            HStack {
                                Text(p.name)
                                    .font(.body)
                                Spacer()
                                if let label = p.timeLabel {
                                    Text(label)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                } else {
                                    Text("未記録")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                }
            } else {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("タイムトライアル")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("閉じる") {
                    manager.stopListening()
                    onDismiss?()
                    dismiss()
                }
                .foregroundColor(Color(hex: "0F1A2E"))
            }
        }
        .onAppear {
            manager.startListening(roomId: roomId)
        }
        .onDisappear {
            manager.stopListening()
        }
        .sheet(isPresented: $showSubmitSheet) {
            timeSubmitSheet(room: manager.currentRoom)
                .onDisappear { recordSource = .choose }
        }
        .sheet(isPresented: $showResults) {
            rankingSheet
        }
    }
    
    private func timeSubmitSheet(room: TimeTrialRoom?) -> some View {
        NavigationStack {
            Group {
                if recordSource == .choose {
                    recordSourceChoiceView(room: room)
                } else if recordSource == .healthKit {
                    healthKitWorkoutListView(room: room)
                } else {
                    manualTimeInputView(room: room)
                }
            }
            .navigationTitle("タイム記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if recordSource != .choose {
                        Button("戻る") { recordSource = .choose }
                            .foregroundColor(Color(hex: "0F1A2E"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("キャンセル") {
                        showSubmitSheet = false
                    }
                    .foregroundColor(Color(hex: "0F1A2E"))
                }
            }
        }
        .onAppear {
            inputMinutes = ""
            inputSeconds = ""
            submitError = nil
        }
    }
    
    private func recordSourceChoiceView(room: TimeTrialRoom?) -> some View {
        VStack(spacing: 20) {
            Text("記録方法を選んでください")
                .font(.headline)
                .foregroundColor(Color(hex: "0F1A2E"))
                .padding(.top, 24)
            Button(action: {
                HealthKitManager.shared.requestAuthorization { success, _ in
                    if success {
                        recordSource = .healthKit
                        loadHealthKitWorkouts(room: room)
                    } else {
                        healthKitError = "HealthKit の利用を許可してください"
                        recordSource = .healthKit
                    }
                }
            }) {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("ランの記録から選ぶ")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "2E5CFF"))
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            Button(action: { recordSource = .manual }) {
                HStack {
                    Image(systemName: "keyboard")
                    Text("手入力で記録")
                }
                .font(.headline)
                .foregroundColor(Color(hex: "0F1A2E"))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "F5F7FA"))
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
    
    private func loadHealthKitWorkouts(room: TimeTrialRoom?) {
        guard let room = room else { return }
        healthKitLoading = true
        healthKitError = nil
        let targetKm = room.distanceKm
        let minKm = targetKm * 0.9
        HealthKitManager.shared.fetchRunningWorkouts(from: room.periodStart, to: room.periodEnd, minDistanceKm: minKm, targetDistanceKm: targetKm) { result in
            healthKitLoading = false
            switch result {
            case .success(let list):
                healthKitWorkouts = list
                if list.isEmpty { healthKitError = "この期間に条件を満たすランがありません" }
            case .failure(let e):
                healthKitError = e.localizedDescription
                healthKitWorkouts = []
            }
        }
    }
    
    private func canSubmitWorkout(_ info: RunningWorkoutInfo, targetKm: Double) -> Bool {
        if info.timeAtTargetSeconds != nil { return true }
        let low = targetKm * 0.95
        let high = targetKm * 1.05
        return info.totalDistanceKm >= low && info.totalDistanceKm <= high
    }
    
    private func submitTimeSeconds(for info: RunningWorkoutInfo, targetKm: Double) -> Double? {
        if let t = info.timeAtTargetSeconds { return t }
        let low = targetKm * 0.95
        let high = targetKm * 1.05
        if info.totalDistanceKm >= low && info.totalDistanceKm <= high { return info.durationSeconds }
        return nil
    }
    
    private func healthKitWorkoutListView(room: TimeTrialRoom?) -> some View {
        let targetKm = room?.distanceKm ?? 5.0
        return VStack(spacing: 0) {
            if healthKitLoading {
                ProgressView("ランの記録を取得中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = healthKitError, healthKitWorkouts.isEmpty {
                Text(err)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach(healthKitWorkouts) { info in
                        let canSubmit = canSubmitWorkout(info, targetKm: targetKm)
                        let timeLabel: String = {
                            if let t = info.timeAtTargetFormatted {
                                return "\(targetKm.clean)km 時点: \(t)"
                            }
                            if canSubmit {
                                return "全体: \(info.durationFormatted)"
                            }
                            return "全体: \(info.durationFormatted) (ルートなし)"
                        }()
                        Button(action: {
                            guard let sec = submitTimeSeconds(for: info, targetKm: targetKm) else { return }
                            submitTimeWithSeconds(sec)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatWorkoutDate(info.startDate))
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Text("\(String(format: "%.2f", info.totalDistanceKm)) km")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text(timeLabel)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(canSubmit ? Color(hex: "0F1A2E") : .gray)
                                if canSubmit {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(!canSubmit)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private func formatWorkoutDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d HH:mm"
        return f.string(from: date)
    }
    
    private func manualTimeInputView(room: TimeTrialRoom?) -> some View {
        VStack(spacing: 24) {
            Text("\(room?.distanceKm.clean ?? "0") km のタイムを入力")
                .font(.headline)
            HStack {
                TextField("分", text: $inputMinutes)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("分")
                TextField("秒", text: $inputSeconds)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("秒")
            }
            .padding(.horizontal)
            if let err = submitError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            Button(action: submitTime) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("記録する")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(hex: "2E5CFF"))
            .cornerRadius(12)
            .disabled(isSubmitting)
            Spacer()
        }
        .padding()
    }
    
    private func submitTimeWithSeconds(_ totalSeconds: Double) {
        isSubmitting = true
        submitError = nil
        manager.submitTime(roomId: roomId, timeSeconds: totalSeconds) { result in
            isSubmitting = false
            switch result {
            case .success:
                showSubmitSheet = false
            case .failure(let e):
                submitError = e.localizedDescription
            }
        }
    }
    
    private var rankingSheet: some View {
        NavigationStack {
            List {
                ForEach(ranking) { entry in
                    HStack {
                        Text("\(entry.rank)位")
                            .font(.headline)
                            .frame(width: 36, alignment: .leading)
                        Text(entry.name)
                        Spacer()
                        Text(entry.timeLabel)
                            .foregroundColor(.gray)
                        Text("+\(entry.points)pt")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "2E5CFF"))
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
            .navigationTitle("結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { showResults = false }
                        .foregroundColor(Color(hex: "0F1A2E"))
                }
            }
        }
    }
    
    private func submitTime() {
        guard let m = Int(inputMinutes.trimmingCharacters(in: .whitespaces)),
              let s = Int(inputSeconds.trimmingCharacters(in: .whitespaces)),
              m >= 0, s >= 0, s < 60 else {
            submitError = "分・秒を正しく入力してください"
            return
        }
        submitTimeWithSeconds(Double(m * 60 + s))
    }
    
    private func loadRanking() {
        manager.fetchRanking(roomId: roomId) { result in
            switch result {
            case .success(let list):
                ranking = list
            case .failure:
                ranking = []
            }
        }
    }
}

extension Double {
    var clean: String {
        if self == Double(Int(self)) { return "\(Int(self))" }
        return String(format: "%.1f", self)
    }
}

#if DEBUG
#Preview("タイムトライアル エントリ") {
    TimeTrialEntryView()
}
#endif

//
//  EkidenLegSubmitSheet.swift
//  TASUKI
//
//  区間提出シート: アプリ記録 or HealthKit から選択して提出
//

import SwiftUI
import MapKit
import HealthKit
import FirebaseAuth

// MARK: - 提出ソース
enum EkidenSubmitSource: String, CaseIterable {
    case appRecord = "アプリで記録する"
    case healthKit = "HealthKitから選ぶ"
}

// MARK: - EkidenLegSubmitSheet
struct EkidenLegSubmitSheet: View {
    let leg: EkidenLeg
    let state: EkidenViewState
    let teamId: String
    let isSampleTeam: Bool
    let onDismiss: () -> Void
    let onSuccess: () -> Void

    @State private var phase: Phase = .sourcePicker
    @State private var selectedRunActivityId: String? = nil  // HealthKit workout UUID
    @State private var healthKitWorkouts: [RunningWorkoutInfo] = []
    @State private var healthKitLoading = false
    @State private var healthKitError: String?
    @State private var confirmDistanceKm: Double = 0
    @State private var confirmElapsedSeconds: Double = 0
    @State private var confirmIsUnderTarget: Bool = false
    @State private var confirmSplitAtTargetSeconds: Double?
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var showRecorder = false

    @ObservedObject private var tracker = RunTracker.shared

    private let elapsedTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var recorderNow = Date()

    enum Phase {
        case sourcePicker
        case healthKitList
        case confirm
    }

    private var targetKm: Double { leg.targetKm }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tasukiDarkBackground.ignoresSafeArea()
                switch phase {
                case .sourcePicker:
                    sourcePickerView
                case .healthKitList:
                    healthKitListView
                case .confirm:
                    confirmView
                }
            }
            .navigationTitle("区間提出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onDismiss()
                    }
                    .foregroundColor(Color.tasukiMutedText)
                }
            }
        }
        .fullScreenCover(isPresented: $showRecorder) {
            ekidenRecorderView
                .onReceive(elapsedTimer) { recorderNow = $0 }
        }
        .onAppear {
            if phase == .healthKitList && healthKitWorkouts.isEmpty {
                loadHealthKitWorkouts()
            }
        }
    }

    // MARK: - Source Picker
    private var sourcePickerView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(leg.id + 1)区（目標 \(String(format: "%.1f", targetKm)) km）")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.tasukiPrimary)
                Text("記録方法を選んでください")
                    .font(.caption)
                    .foregroundColor(Color.tasukiMutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .tasukiCard()

            Button {
                tracker.start()
                recorderNow = Date()
                showRecorder = true
            } label: {
                HStack {
                    Image(systemName: "location.fill")
                    Text(EkidenSubmitSource.appRecord.rawValue)
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.tasukiPrimary))
            }
            .buttonStyle(.plain)

            Button {
                phase = .healthKitList
                loadHealthKitWorkouts()
            } label: {
                HStack {
                    Image(systemName: "heart.fill")
                    Text(EkidenSubmitSource.healthKit.rawValue)
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.tasukiAccentOrange))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(16)
    }

    // MARK: - HealthKit List
    private var healthKitListView: some View {
        VStack(spacing: 0) {
            if healthKitLoading {
                ProgressView("ランの記録を取得中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = healthKitError, healthKitWorkouts.isEmpty {
                VStack(spacing: 12) {
                    Text(err)
                        .font(.subheadline)
                        .foregroundColor(Color.tasukiMutedText)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("戻る") { phase = .sourcePicker }
                        .foregroundColor(Color.tasukiAccent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(healthKitWorkouts) { info in
                        Button {
                            applyHealthKitWorkout(info)
                            phase = .confirm
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatWorkoutDate(info.startDate))
                                        .font(.subheadline)
                                        .foregroundColor(Color.tasukiMutedText)
                                    Text("\(String(format: "%.2f", info.totalDistanceKm)) km")
                                        .font(.caption)
                                        .foregroundColor(Color.tasukiMutedText)
                                }
                                Spacer()
                                Text(info.durationFormatted)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color.tasukiPrimary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Color.tasukiMutedText)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.tasukiDarkBackground)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("戻る") { phase = .sourcePicker }
                    .foregroundColor(Color.tasukiMutedText)
            }
        }
    }

    // MARK: - Confirm View
    private var confirmView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("提出内容を確認")
                    .font(.caption)
                    .foregroundColor(Color.tasukiMutedText)
                Text("問題なければ提出してください")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.tasukiPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .tasukiCard()

            VStack(alignment: .leading, spacing: 10) {
                confirmRow("距離", "\(String(format: "%.2f", confirmDistanceKm)) km")
                confirmRow("区間タイム", EkidenViewState.formatElapsed(confirmElapsedSeconds))
                if confirmIsUnderTarget {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color.tasukiAccentOrange)
                        Text("目標距離未達で提出します")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.tasukiAccentOrange)
                    }
                }
            }
            .tasukiCard()

            if let err = submitError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack(spacing: 12) {
                Button {
                    phase = .sourcePicker
                    submitError = nil
                    selectedRunActivityId = nil
                } label: {
                    Text("戻る")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.tasukiPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.tasukiDarkCardSecondary, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)

                Button {
                    submitLeg()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("提出する")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.tasukiPrimary))
                .disabled(isSubmitting)
                .buttonStyle(.plain)
            }
            .tasukiCard()

            Spacer()
        }
        .padding(16)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("戻る") {
                    phase = .sourcePicker
                    submitError = nil
                    selectedRunActivityId = nil
                }
                .foregroundColor(Color.tasukiMutedText)
            }
        }
    }

    // MARK: - Recorder View
    private var ekidenRecorderView: some View {
        ZStack {
            Color.tasukiDarkBackground.ignoresSafeArea()
            if tracker.isTracking {
                VStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text("記録中")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color.tasukiPrimary)
                        Text(formatDuration(recorderElapsedSeconds))
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .foregroundColor(Color.tasukiPrimary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    .background(Color.tasukiSurface)

                    Spacer(minLength: 18)

                    Text(String(format: "%.2f", tracker.distanceKm))
                        .font(.system(size: 80, weight: .heavy, design: .rounded))
                        .foregroundColor(Color.tasukiPrimary)
                        .monospacedDigit()
                    Text("km")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Color.tasukiMutedText)

                    Spacer(minLength: 24)

                    HStack(spacing: 16) {
                        recorderValueCard(value: String(format: "%.0f", tracker.elevationGainMeters), title: "獲得標高 (m)")
                        recorderValueCard(value: String(format: "%.0f", tracker.currentAltitudeMeters), title: "現在の標高 (m)")
                    }

                    Spacer()

                    HStack(spacing: 14) {
                        Button {
                            if tracker.isPaused { tracker.resume() } else { tracker.pause() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: tracker.isPaused ? "play.fill" : "pause.fill")
                                Text(tracker.isPaused ? "再開" : "一時停止")
                            }
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Capsule().fill(Color.tasukiAccentOrange))
                        }
                        .buttonStyle(.plain)

                        Button {
                            finishRecorderAndPrepareSubmission()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "flag.checkered")
                                Text("終了して提出")
                            }
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Capsule().fill(Color.tasukiPrimary))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            } else {
                VStack(spacing: 14) {
                    Text("ランニングを記録して区間を提出")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.tasukiPrimary)
                    Button {
                        tracker.start()
                        recorderNow = Date()
                    } label: {
                        Text("記録を開始")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.tasukiPrimary))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                tracker.stop()
                tracker.reset()
                showRecorder = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color.tasukiMutedText)
            }
            .padding()
        }
    }

    // MARK: - Helpers
    private var recorderElapsedSeconds: Double {
        tracker.elapsedSeconds(now: recorderNow)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        if m >= 60 {
            let h = m / 60
            let mm = m % 60
            return String(format: "%d:%02d:%02d", h, mm, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func formatWorkoutDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d HH:mm"
        return f.string(from: date)
    }

    private func confirmRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Color.tasukiMutedText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color.tasukiPrimary)
        }
    }

    private func recorderValueCard(value: String, title: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundColor(Color.tasukiPrimary)
                .monospacedDigit()
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.tasukiMutedText)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadHealthKitWorkouts() {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthKitError = "HealthKit の利用を許可してください"
            healthKitLoading = false
            return
        }
        healthKitLoading = true
        healthKitError = nil
        HealthKitManager.shared.fetchRunningWorkouts(
            from: state.event.startAt,
            to: state.event.endAt,
            minDistanceKm: 0,
            targetDistanceKm: targetKm,
            dataSource: .all
        ) { result in
            healthKitLoading = false
            switch result {
            case .success(let list):
                healthKitWorkouts = list
                if list.isEmpty { healthKitError = "イベント期間内のラン記録がありません" }
            case .failure(let e):
                healthKitError = e.localizedDescription
                healthKitWorkouts = []
            }
        }
    }

    private func applyHealthKitWorkout(_ info: RunningWorkoutInfo) {
        confirmDistanceKm = info.totalDistanceKm
        confirmIsUnderTarget = info.totalDistanceKm < targetKm
        selectedRunActivityId = info.id.uuidString
        if info.totalDistanceKm >= targetKm, let t = info.timeAtTargetSeconds {
            confirmElapsedSeconds = t
            confirmSplitAtTargetSeconds = t
        } else {
            confirmElapsedSeconds = info.durationSeconds
            confirmSplitAtTargetSeconds = nil
        }
    }

    private func finishRecorderAndPrepareSubmission() {
        tracker.stop()
        confirmDistanceKm = tracker.distanceKm
        confirmElapsedSeconds = recorderElapsedSeconds
        confirmIsUnderTarget = confirmDistanceKm < targetKm
        selectedRunActivityId = nil  // アプリ記録には外部IDなし
        // 超過時: アプリ記録ではルート補間がないため elapsed をそのまま使用。splitAtTargetSeconds は nil
        confirmSplitAtTargetSeconds = nil
        tracker.reset()
        showRecorder = false
        phase = .confirm
    }

    private func submitLeg() {
        let submittedByUid: String
        if isSampleTeam {
            submittedByUid = leg.assignedUid ?? "sample_owner"
        } else {
            submittedByUid = Auth.auth().currentUser?.uid ?? ""
        }
        guard !submittedByUid.isEmpty else {
            submitError = "ログインが必要です"
            return
        }

        isSubmitting = true
        submitError = nil
        let source: String = selectedRunActivityId != nil ? "health_kit" : "app_record"
        Task {
            let result = await EkidenDataService.shared.submitLeg(
                teamId: teamId,
                entryId: state.entry.id,
                eventId: state.event.id,
                legIndex: leg.id,
                actualDistanceKm: confirmDistanceKm,
                elapsedSeconds: confirmElapsedSeconds,
                isUnderTarget: confirmIsUnderTarget,
                splitAtTargetSeconds: confirmSplitAtTargetSeconds,
                submittedByUid: submittedByUid,
                isSampleTeam: isSampleTeam,
                source: source,
                runActivityId: selectedRunActivityId
            )
            await MainActor.run {
                isSubmitting = false
                switch result {
                case .success:
                    onSuccess()
                    onDismiss()
                case .failure(let e):
                    submitError = e.localizedDescription
                }
            }
        }
    }
}

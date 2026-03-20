import SwiftUI
import MapKit
import Combine

struct RunRecordingView: View {
    @ObservedObject private var tracker = RunTracker.shared
    @ObservedObject private var activityStore = RunActivityStore.shared

    @State private var now = Date()
    @State private var latestSaved: RunActivity?
    @State private var showSavedToast = false

    private let elapsedTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var elapsedSeconds: TimeInterval {
        guard tracker.isTracking, let startedAt = tracker.trackingStartedAt else { return 0 }
        return max(0, now.timeIntervalSince(startedAt))
    }

    private var currentPaceText: String {
        guard tracker.distanceKm > 0 else { return "--:--/km" }
        let secPerKm = elapsedSeconds / tracker.distanceKm
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d/km", m, s)
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        tracker.routeCoordinates
    }

    private var mapRegion: MKCoordinateRegion {
        guard let first = routeCoordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.68, longitude: 139.76),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
        let lats = routeCoordinates.map(\.latitude)
        let lons = routeCoordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.5, 0.008),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.5, 0.008)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                titleCard
                metricCard
                mapCard
                actionButtons
                recentActivitiesCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.tasukiDarkBackground.ignoresSafeArea())
        .navigationTitle("Run")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(elapsedTimer) { now = $0 }
        .onAppear {
            activityStore.refreshFromRemote()
        }
        .overlay(alignment: .top) {
            if showSavedToast, let latestSaved {
                Text("保存完了: \(String(format: "%.1f", latestSaved.distanceKm))km")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.tasukiPrimary))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RUN RECORDER")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(Color.tasukiMutedText)
                .tracking(1.5)
            Text("GPSで記録して履歴・チャレンジに反映")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.tasukiPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tasukiCard()
    }

    private var metricCard: some View {
        HStack(spacing: 12) {
            metricItem(title: "距離", value: String(format: "%.2f", tracker.distanceKm), unit: "km")
            metricItem(title: "時間", value: formatDuration(elapsedSeconds), unit: "")
            metricItem(title: "ペース", value: currentPaceText.replacingOccurrences(of: "/km", with: ""), unit: "/km")
        }
        .tasukiCard()
    }

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ルート")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.tasukiPrimary)
            Map(initialPosition: .region(mapRegion), interactionModes: .all) {
                if routeCoordinates.count >= 2 {
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(Color.tasukiAccent, lineWidth: 4)
                }
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .tasukiCard()
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if tracker.isTracking {
                Button {
                    finishAndSave()
                } label: {
                    Text("走行を終了して保存")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.tasukiAccent))
                }
                .buttonStyle(.plain)

                Button {
                    tracker.stop()
                    tracker.reset()
                } label: {
                    Text("保存せずに破棄")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.tasukiPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.tasukiDarkCardSecondary, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    tracker.start()
                    now = Date()
                } label: {
                    Text("走行を開始")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.tasukiPrimary))
                }
                .buttonStyle(.plain)
            }
        }
        .tasukiCard()
    }

    private var recentActivitiesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近のアクティビティ")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.tasukiPrimary)
                Spacer()
                NavigationLink(destination: RunHistoryListView()) {
                    Text("すべて見る")
                        .font(.caption)
                        .foregroundColor(Color.tasukiAccent)
                }
            }
            if activityStore.activities.isEmpty {
                Text("まだ記録がありません。走行を開始して最初のアクティビティを作成しましょう。")
                    .font(.footnote)
                    .foregroundColor(Color.tasukiMutedText)
            } else {
                ForEach(Array(activityStore.activities.prefix(3))) { activity in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(formatDate(activity.startedAt))
                                .font(.caption)
                                .foregroundColor(Color.tasukiMutedText)
                            Text("\(String(format: "%.1f", activity.distanceKm))km · \(activity.paceLabel)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.tasukiPrimary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .tasukiCard()
    }

    private func metricItem(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(Color.tasukiMutedText)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.tasukiPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(Color.tasukiMutedText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func finishAndSave() {
        tracker.stop()
        guard tracker.distanceKm >= 0.05 else {
            tracker.reset()
            return
        }
        let activity = activityStore.addActivity(
            distanceKm: tracker.distanceKm,
            durationSeconds: max(elapsedSeconds, 1),
            routeCoordinates: tracker.routeCoordinates,
            source: "run_recorder"
        )
        let earnedPoints = max(20, Int(activity.distanceKm * 12))
        PointService.shared.addPointsToCurrentUser(amount: earnedPoints)
        tracker.reset()
        latestSaved = activity
        withAnimation(.easeInOut(duration: 0.2)) {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSavedToast = false
            }
        }
    }

    private func formatDuration(_ sec: TimeInterval) -> String {
        let total = Int(sec)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d HH:mm"
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack {
        RunRecordingView()
    }
}

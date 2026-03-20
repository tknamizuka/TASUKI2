import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MyProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.openURL) private var openURL

    @AppStorage("myName") private var name: String = "Hiro"
    @AppStorage("myArea") private var area: String = "Tokyo, Setagaya"
    @AppStorage("myRank") private var rank: String = "Rank A"
    @AppStorage("myPurpose") private var purpose: String = "サブ3, 健康維持"
    @AppStorage("myRunningSpots") private var runningSpots: String = "皇居, 代々木公園"
    @AppStorage("mySchedule") private var schedule: String = "平日夜, 土日午前"
    @AppStorage("myPersonalBest") private var personalBest: String = "Full 3:10:00"
    @AppStorage("myTargetTime") private var targetTime: String = "Full 2:59:00"
    @AppStorage("myNextRace") private var nextRace: String = "東京マラソン2026"
    @AppStorage("myAvgPace") private var avgPace: String = "5:30/km"
    @AppStorage("myMonthlyDist") private var monthlyDist: String = "150km"
    @AppStorage("myTotalPoints") private var myTotalPoints: Int = 0
    @AppStorage("realityMiningConsentEnabled") private var realityMiningConsentEnabled: Bool = false
    @AppStorage("runningDataSource") private var runningDataSourceRaw: String = RunningDataSource.all.rawValue
    @AppStorage("myBio") private var bio: String = "平日は仕事終わりに5-10km走ってます！週末は距離走やりたいです。"

    @State private var userUUID: String = ""
    @State private var showCopiedToast: Bool = false
    @State private var integrationNotice: String?

    private var myBadgeTier: PointBadgeTier? {
        PointBadgeHelper.tier(forTotalPoints: myTotalPoints)
    }

    private var selectedRunningDataSource: RunningDataSource {
        RunningDataSource(rawValue: runningDataSourceRaw) ?? .all
    }

    private var runningSpotTags: [String] {
        runningSpots.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var companionSources: [RunningDataSource] {
        RunningDataSource.allCases.filter { $0 != .all }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tasukiBase.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: TasukiUI.sectionSpacing) {
                        heroCard
                        statsCard
                        profileCard
                        aboutCard
                        realityMiningCard
                        integrationCard
                        logoutButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileEditView()) {
                        Image(systemName: "pencil")
                            .foregroundColor(Color.tasukiPrimary)
                    }
                }
            }
            .task { loadUserUUID() }
            .onChange(of: realityMiningConsentEnabled) { newValue in
                RealityMiningManager.shared.updateConsent(enabled: newValue)
            }
            .overlay(alignment: .top) {
                if showCopiedToast {
                    Text("UUIDをコピーしました")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.8)))
                        .foregroundColor(.white)
                        .padding(.top, 60)
                        .transition(.opacity)
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 96))
                .foregroundColor(Color.tasukiPrimary)
                .frame(width: 140, height: 140)
                .background(Circle().fill(Color.tasukiSurface))

            HStack(spacing: 8) {
                Text(name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.tasukiPrimary)
                if let tier = myBadgeTier {
                    HStack(spacing: 4) {
                        Image(systemName: tier.iconName)
                        Text(tier.displayName)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.tasukiAccent))
                }
            }

            Text(rank)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.tasukiPrimary))

            HStack(spacing: 5) {
                Text("保有ポイント")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.tasukiMutedText)
                Text("\(PointService.shared.currentTotalPoints())pt")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.tasukiPrimary)
            }

            HStack(spacing: 8) {
                Text(userUUID.isEmpty ? "—" : userUUID)
                    .font(.system(size: 12))
                    .foregroundColor(Color.tasukiMutedText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button {
                    guard !userUUID.isEmpty else { return }
                    UIPasteboard.general.string = userUUID
                    withAnimation(.easeInOut(duration: 0.2)) { showCopiedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.2)) { showCopiedToast = false }
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(Color.tasukiPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .tasukiCard(corner: 20)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Running Stats")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.tasukiPrimary)

            HStack(spacing: 12) {
                statItem(title: "Avg Pace", value: avgPace)
                statItem(title: "Monthly Dist", value: monthlyDist)
            }
        }
        .tasukiCard()
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                Text(area)
            }
            .font(.subheadline)
            .foregroundColor(Color.tasukiMutedText)

            if !purpose.isEmpty {
                tagView(text: purpose, isPrimary: true)
            }

            if !runningSpotTags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(runningSpotTags, id: \.self) { spot in
                        tagView(text: spot, isPrimary: false)
                    }
                }
            }

            infoRow(icon: "trophy.fill", title: "Personal Best", value: personalBest)
            infoRow(icon: "calendar", title: "Schedule", value: schedule)
            if !nextRace.isEmpty {
                infoRow(icon: "flag.fill", title: "Next Race", value: nextRace)
            }
            if !targetTime.isEmpty {
                infoRow(icon: "scope", title: "Target", value: targetTime)
            }
        }
        .tasukiCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About Me")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.tasukiPrimary)
            Text(bio)
                .font(.system(size: 15))
                .foregroundColor(Color.tasukiMutedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.tasukiSurface))
        }
        .tasukiCard()
    }

    private var realityMiningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reality Mining")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.tasukiPrimary)
            Toggle(isOn: $realityMiningConsentEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("行動データ収集を許可")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.tasukiPrimary)
                    Text("推奨精度向上のために、画面利用やランニング関連イベントを収集します。")
                        .font(.system(size: 12))
                        .foregroundColor(Color.tasukiMutedText)
                }
            }
            .tint(Color.tasukiAccent)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.tasukiSurface))
        }
        .tasukiCard()
    }

    private var integrationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("デバイス連携")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.tasukiPrimary)

            Text("走行距離・ワークアウト取得元")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.tasukiPrimary)

            Picker("取得元", selection: Binding(
                get: { selectedRunningDataSource },
                set: { newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        runningDataSourceRaw = newValue.rawValue
                    }
                    RealityMiningManager.shared.trackEvent(
                        name: "running_data_source_changed",
                        properties: ["source": newValue.rawValue]
                    )
                })
            ) {
                ForEach(RunningDataSource.allCases) { source in
                    Text(source.displayName).tag(source)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.tasukiPrimary)

            Text("選択したサービスの記録がAppleヘルスへ同期されている場合、TASUKIで読み取りできます。")
                .font(.system(size: 12))
                .foregroundColor(Color.tasukiMutedText)

            let columns = [GridItem(.adaptive(minimum: 120), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(companionSources) { source in
                    integrationButton(title: source.displayName, source: source)
                }
            }

            if let integrationNotice {
                Text(integrationNotice)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.tasukiAccent)
            }
        }
        .tasukiCard()
    }

    private var logoutButton: some View {
        Button {
            authManager.signOut { result in
                if case let .failure(error) = result {
                    print("Sign out failed: \(error.localizedDescription)")
                }
            }
        } label: {
            Text("ログアウト")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.tasukiPrimary)
                .cornerRadius(12)
        }
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color.tasukiMutedText)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.tasukiPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.tasukiSurface))
    }

    private func tagView(text: String, isPrimary: Bool) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(isPrimary ? .white : Color.tasukiPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(isPrimary ? Color.tasukiAccent : Color.tasukiSurface))
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.tasukiAccent)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(Color.tasukiMutedText)
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.tasukiPrimary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.tasukiSurface))
    }

    private func integrationButton(title: String, source: RunningDataSource) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                runningDataSourceRaw = source.rawValue
            }
            openCompanionApp(for: source)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selectedRunningDataSource == source ? .white : Color.tasukiPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedRunningDataSource == source ? Color.tasukiAccent : Color.tasukiSurface)
                )
        }
    }

    private func loadUserUUID() {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        db.collection("users").document(firebaseUser.uid).getDocument { snapshot, _ in
            if let data = snapshot?.data(), let idString = data["id"] as? String {
                DispatchQueue.main.async {
                    self.userUUID = idString
                }
            }
        }
    }

    private func openCompanionApp(for source: RunningDataSource) {
        if source == .appleHealth {
            withAnimation(.easeInOut(duration: 0.2)) {
                integrationNotice = "Apple Health を取得元に設定しました"
            }
            return
        }

        let links = source.deepLinks
        guard !links.isEmpty else {
            withAnimation(.easeInOut(duration: 0.2)) {
                integrationNotice = "\(source.displayName) の起動リンクが未設定です"
            }
            return
        }

        func tryOpen(_ index: Int) {
            if index >= links.count {
                if let appStore = source.appStoreURL {
                    openURL(appStore)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        integrationNotice = "\(source.displayName) アプリが未インストールのためApp Storeを開きました"
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        integrationNotice = "\(source.displayName) を開けませんでした"
                    }
                }
                return
            }
            openURL(links[index]) { accepted in
                if accepted {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        integrationNotice = "\(source.displayName) を開きました"
                    }
                } else {
                    tryOpen(index + 1)
                }
            }
        }
        tryOpen(0)
    }
}

#Preview {
    MyProfileView()
        .environmentObject(AuthManager())
}

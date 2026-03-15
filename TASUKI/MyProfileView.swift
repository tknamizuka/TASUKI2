import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MyProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    // 保存データを読み込み
    @AppStorage("myName") private var name: String = "Hiro"
    @AppStorage("myAge") private var age: String = "29"
    @AppStorage("myArea") private var area: String = "Tokyo, Setagaya"
    @AppStorage("myRank") private var rank: String = "Rank A"
    @AppStorage("myGender") private var gender: String = "male"
    
    // Running Style
    @AppStorage("myPurpose") private var purpose: String = "サブ3, 健康維持"
    @AppStorage("myRunningSpots") private var runningSpots: String = "皇居, 代々木公園"
    @AppStorage("mySchedule") private var schedule: String = "平日夜, 土日午前"
    
    // Records & Goals
    @AppStorage("myPersonalBest") private var personalBest: String = "Full 3:10:00"
    @AppStorage("myTargetTime") private var targetTime: String = "Full 2:59:00"
    @AppStorage("myNextRace") private var nextRace: String = "東京マラソン2026"
    
    // Stats
    @AppStorage("myAvgPace") private var avgPace: String = "5:30/km"
    @AppStorage("myMonthlyDist") private var monthlyDist: String = "150km"
    @AppStorage("myTotalPoints") private var myTotalPoints: Int = 0
    
    // Bio
    @AppStorage("myBio") private var bio: String = "平日は仕事終わりに5-10km走ってます！週末は距離走やりたいです。"
    @State private var userUUID: String = ""
    @State private var showCopiedToast: Bool = false

    private var myBadgeTier: PointBadgeTier? {
        PointBadgeHelper.tier(forTotalPoints: myTotalPoints)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色: White
                Color.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // A. ヘッダー
                        VStack(spacing: 16) {
                            // アバター画像（大）
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 120))
                                .foregroundColor(Color(hex: "0F1A2E"))
                                .saturation(0)
                                .frame(width: 180, height: 180)
                                .background(
                                    Circle()
                                        .fill(Color(hex: "F5F7FA"))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.royalBlue.opacity(0.3), lineWidth: 3)
                                )
                            
                            // 名前、バッジ名・ランク、UUID
                            VStack(spacing: 12) {
                                // 名前 + カラーのカプセルバッジ
                                HStack(spacing: 10) {
                                    Text(name)
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(Color(hex: "0F1A2E"))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    if let tier = myBadgeTier {
                                        HStack(spacing: 5) {
                                            Image(systemName: tier.iconName)
                                                .font(.system(size: 12, weight: .semibold))
                                            Text(tier.displayName)
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(tier.color))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)

                                // ランク（カプセル）
                                Text(rank)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.royalBlue))
                                    .frame(maxWidth: .infinity, alignment: .center)

                                // 保有ポイント（累計）
                                HStack(spacing: 4) {
                                    Text("保有ポイント（累計）")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: "0F1A2E").opacity(0.6))
                                    Text("\(PointService.shared.currentTotalPoints())")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color(hex: "0F1A2E"))
                                    Text("pt")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "0F1A2E").opacity(0.6))
                                }

                                // UUID + コピー
                                HStack(spacing: 8) {
                                    Spacer(minLength: 0)
                                    Text(userUUID.isEmpty ? "—" : userUUID)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(Color(hex: "0F1A2E").opacity(0.8))
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    // コピーボタン（テキストのすぐ右）
                                    Button(action: {
                                        guard !userUUID.isEmpty else { return }
                                        UIPasteboard.general.string = userUUID
                                        showCopiedToast = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            showCopiedToast = false
                                        }
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(Color(hex: "0F1A2E"))
                                    }
                                    Spacer(minLength: 40)
                                }

                                // エリア（従来の表示）
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 12))
                                    Text(area)
                                        .font(.system(size: 14, weight: .regular))
                                }
                                .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                        
                        // B. タグセクション
                        VStack(alignment: .leading, spacing: 12) {
                            // Purpose タグ
                            HStack {
                                Text("目的")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
                                Spacer()
                            }
                            
                            HStack(spacing: 8) {
                                tagView(text: purpose, isPrimary: true)
                                Spacer()
                            }
                            
                            // Running Spots タグ
                            if !runningSpots.isEmpty {
                                HStack {
                                    Text("Run Spots")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
                                    Spacer()
                                }
                                .padding(.top, 8)
                                
                                let spots = runningSpots.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(spots, id: \.self) { spot in
                                        tagView(text: spot, isPrimary: false)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // C. メイン情報グリッド (Info Cards)
                        VStack(spacing: 12) {
                            infoCardView(
                                icon: "trophy.fill",
                                title: "Personal Best",
                                value: personalBest
                            )
                            
                            infoCardView(
                                icon: "calendar",
                                title: "Schedule",
                                value: schedule
                            )
                            
                            if !nextRace.isEmpty {
                                infoCardView(
                                    icon: "flag.fill",
                                    title: "Next Race",
                                    value: nextRace
                                )
                            }
                            
                            if !targetTime.isEmpty {
                                infoCardView(
                                    icon: "scope",
                                    title: "Target",
                                    value: targetTime
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // D. ランニング統計 (Stats)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Running Stats")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "0F1A2E"))
                                .padding(.horizontal, 20)
                            
                            HStack(spacing: 12) {
                                statCardView(title: "Avg Pace", value: avgPace)
                                statCardView(title: "Monthly Dist", value: monthlyDist)
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 8)
                        
                        // E. 自己紹介 (About Me)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About Me")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "0F1A2E"))
                                .padding(.horizontal, 20)
                            
                            Text(bio)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "F5F7FA"))
                                )
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 8)
                        
                        // F. ログアウトボタン
                        Button(action: {
                            authManager.signOut { result in
                                if case let .failure(error) = result {
                                    print("Sign out failed: \(error.localizedDescription)")
                                }
                            }
                        }) {
                            Text("ログアウト")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileEditView()) {
                        Image(systemName: "pencil")
                            .foregroundColor(Color(hex: "2E5CFF"))
                    }
                }
            }
            .task {
                loadUserUUID()
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

    private func loadUserUUID() {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        db.collection("users").document(firebaseUser.uid).getDocument { snapshot, error in
            if let data = snapshot?.data(), let idString = data["id"] as? String {
                DispatchQueue.main.async {
                    self.userUUID = idString
                }
            }
        }
    }
    
    // MARK: - Tag View
    private func tagView(text: String, isPrimary: Bool) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isPrimary ? .white : Color(hex: "0F1A2E"))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isPrimary ? Color.royalBlue : Color(uiColor: .systemGray6))
            )
    }
    
    // MARK: - Info Card View
    private func infoCardView(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color.royalBlue)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.royalBlue.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.6))
                
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "0F1A2E"))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Stat Card View
    private func statCardView(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(Color(hex: "0F1A2E").opacity(0.6))
                .tracking(0.5)
            
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .default))
                .foregroundColor(Color(hex: "0F1A2E"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

#Preview {
    MyProfileView()
        .environmentObject(AuthManager())
}
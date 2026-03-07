import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct TeamDetailView: View {
    let teamId: String
    var onJoined: ((String?) -> Void)? = nil   // 呼び出し元へ参加結果を返す

    @State private var teamData: [String: Any]? = nil
    @State private var memberUIDs: [String] = []
    @State private var membersInfo: [String] = []
    @State private var ownerUid: String? = nil
    @State private var showingShare: Bool = false
    @State private var shareText: String = ""
    @State private var showManage: Bool = false
    @State private var alertMessage: String? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            if let data = teamData {
                Text(data["name"] as? String ?? "Team")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "0F1A2E"))

                HStack {
                    Text("招待コード: ")
                    Text(data["inviteCode"] as? String ?? "—")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button(action: {
                        let code = data["inviteCode"] as? String ?? ""
                        shareText = "チームに参加する招待コード: \(code)"
                        showingShare = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 20)

                HStack {
                    Text("承認制: ")
                    Text((data["requiresApproval"] as? Bool ?? false) ? "あり" : "なし")
                    Spacer()
                }
                .padding(.horizontal, 20)

                Divider()

                Text("メンバー")
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                if membersInfo.isEmpty {
                    Text("メンバー情報を取得中…")
                        .foregroundColor(.gray)
                } else {
                    List(membersInfo, id: \.self) { info in
                        Text(info)
                    }
                }

                // 参加ボタン（自分がメンバーでもオーナーでもない場合のみ）
                if let currentUid = Auth.auth().currentUser?.uid,
                   !memberUIDs.contains(currentUid),
                   ownerUid != currentUid {
                    Button(action: { Task { await joinCurrentTeam() } }) {
                        HStack {
                            Spacer()
                            Text("このチームに参加する")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "2E5CFF")))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            } else {
                Text("チーム情報を読み込み中…")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("チーム詳細")
        .toolbar {
            if ownerUid == Auth.auth().currentUser?.uid {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: TeamManageView(teamId: teamId)) {
                        Text("参加申請")
                    }
                }
            }
        }
        .alert(alertMessage ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .task {
            await loadTeam()
        }
        .sheet(isPresented: $showingShare) {
            ShareSheet(activityItems: [shareText])
        }
    }

    // MARK: - チーム参加処理
    private func joinCurrentTeam() async {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            alertMessage = "ログインユーザーが見つかりません。"
            return
        }
        let db = Firestore.firestore()
        let teamRef = db.collection("teams").document(teamId)
        do {
            let snap = try await teamRef.getDocument()
            guard let data = snap.data() else {
                alertMessage = "チームが見つかりません。"
                return
            }
            let requiresApproval = data["requiresApproval"] as? Bool ?? false
            if requiresApproval {
                // 申請を送る
                let reqRef = teamRef.collection("joinRequests").document(currentUid)
                try await reqRef.setData([
                    "uid": currentUid,
                    "requestedAt": Timestamp(date: Date())
                ])
                alertMessage = "参加申請を送信しました。"
                onJoined?(nil)
            } else {
                // 直接参加
                let userRef = db.collection("users").document(currentUid)
                try await userRef.setData(["teamId": teamId], merge: true)
                try await teamRef.updateData(["members": FieldValue.arrayUnion([currentUid])])
                alertMessage = "チームに参加しました。"
                onJoined?(teamId)
            }
        } catch {
            alertMessage = "参加に失敗しました: \(error.localizedDescription)"
        }
    }

    private func loadTeam() async {
        // プレビュー/サンプル用
        if teamId == "example" {
            await MainActor.run {
                self.teamData = [
                    "name": "皇居ランナーズ",
                    "inviteCode": "EX1234",
                    "requiresApproval": true,
                    "members": ["u_kenji", "u_sacchan", "u_taka"]
                ]
                self.memberUIDs = ["u_kenji", "u_sacchan", "u_taka"]
                self.ownerUid = "u_owner"
                self.membersInfo = ["Kenji_Run", "さっちゃん", "Taka@Sub3"]
            }
            return
        }

        let db = Firestore.firestore()
        let doc = try? await db.collection("teams").document(teamId).getDocument()
        if let data = doc?.data() {
            await MainActor.run {
                self.teamData = data
                self.memberUIDs = data["members"] as? [String] ?? []
                self.ownerUid = data["ownerUid"] as? String
            }

            // 簡易的に各UIDからユーザー名を読み取る
            var infos: [String] = []
            for uid in memberUIDs {
                if let userDoc = try? await db.collection("users").document(uid).getDocument(), let udata = userDoc.data() {
                    let name = udata["name"] as? String ?? uid
                    infos.append(name)
                } else {
                    infos.append(uid)
                }
            }
            await MainActor.run {
                self.membersInfo = infos
            }
        }
    }

    struct ShareSheet: UIViewControllerRepresentable {
        let activityItems: [Any]
        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        }
        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }
}

#Preview {
    NavigationStack {
        TeamDetailView(teamId: "example")
            .onAppear {
                // プレビュー時は未ログインのため UID が nil。
                // Anonymous login でダミーUIDを作成するとボタンが見える。
                if Auth.auth().currentUser == nil {
                    Auth.auth().signInAnonymously { _, _ in }
                }
            }
    }
}

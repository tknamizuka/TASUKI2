//
//  TeamView.swift
//  TASUKI
//
//  Created by yoshi H on 2026/01/28.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Team Member Model
struct TeamMember: Identifiable {
    let id = UUID()
    let name: String
    let avatarImage: String?
    let currentDistance: Double  // km
    let targetDistance: Double  // km
    let condition: Condition
    let statusMessage: String
}

// MARK: - Team Chat Model
struct TeamChatMessage: Identifiable {
    let id = UUID()
    let memberName: String
    let message: String
    let timestamp: Date
}

// MARK: - Team View
struct TeamView: View {
    var useMockTeamFlow: Bool = false
    @State private var userTeamId: String? = nil
    @State private var selectedTeamId: String = ""
    @State private var showTeamDetail: Bool = false
    @State private var showJoinCreate: Bool = false
    
    // 自分のデータ管理
    @AppStorage("myCondition") private var myConditionRaw: String = Condition.good.rawValue
    @AppStorage("myStatusMessage") private var myStatusMessage: String = "今月も頑張ります！"
    @AppStorage("myName") private var myName: String = "Hiro"
    
    // コンディション更新シート
    @State private var showConditionSheet = false
    @State private var selectedCondition: Condition = .good
    
    // チームチャットシート
    @State private var showTeamChatSheet = false
    
    // オーナーかどうか（メンバー管理の表示用）
    @State private var isTeamOwner: Bool = false
    
    // チーム情報
    @State private var teamName: String = "皇居ランナーズ"
    @State private var league: String = "Gold League"
    @State private var rank: String = "3rd Place"
    
    // 目標と進捗
    @State private var targetDistance: Double = 500.0  // km
    @State private var currentDistance: Double = 325.0  // km
    
    // 自分のコンディションを取得
    private var myCondition: Condition {
        Condition(rawValue: myConditionRaw) ?? .good
    }
    
    // メンバー（自分を含む）
    private var members: [TeamMember] {
        var allMembers: [TeamMember] = [
            TeamMember(name: "Kenji_Run", avatarImage: "person.circle.fill", currentDistance: 85.0, targetDistance: 100.0, condition: .excellent, statusMessage: "調子が良い！今月は200km走る目標です🔥"),
            TeamMember(name: "さっちゃん", avatarImage: "person.circle.fill", currentDistance: 72.0, targetDistance: 100.0, condition: .good, statusMessage: "今月も頑張ります！週3回のペースで走ってます"),
            TeamMember(name: "Taka@Sub3", avatarImage: "person.circle.fill", currentDistance: 68.0, targetDistance: 100.0, condition: .good, statusMessage: "週末の朝ランが楽しみです！"),
            TeamMember(name: "Momo", avatarImage: "person.circle.fill", currentDistance: 65.0, targetDistance: 100.0, condition: .tired, statusMessage: "最近忙しくて疲れ気味...でも走りたい！"),
            TeamMember(name: "Runner123", avatarImage: "person.circle.fill", currentDistance: 35.0, targetDistance: 100.0, condition: .sos, statusMessage: "足を痛めてしまいました...しばらく休みます💦")
        ]
        
        // 自分を先頭に追加
        let myMember = TeamMember(
            name: myName,
            avatarImage: "person.circle.fill",
            currentDistance: 80.0,
            targetDistance: 100.0,
            condition: myCondition,
            statusMessage: myStatusMessage
        )
        allMembers.insert(myMember, at: 0)
        
        return allMembers
    }
    
    // チームチャット
    // 注: TeamMessageモデルが別ファイルで定義されている前提です。mockTeamMessagesがない場合は空配列で初期化します。
    @State private var teamMessages: [TeamMessage] = []
    
    var progressPercentage: Double {
        guard targetDistance > 0 else { return 0 }
        return min(currentDistance / targetDistance, 1.0) * 100
    }
    
    // 今月の月末日を取得
    var monthEndDate: Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        var dateComponents = DateComponents()
        dateComponents.year = components.year
        dateComponents.month = components.month
        dateComponents.day = calendar.range(of: .day, in: .month, for: now)?.count
        return calendar.date(from: dateComponents) ?? now
    }
    
    // 残り日数を計算
    var remainingDays: Int {
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: now, to: monthEndDate).day ?? 0
        return max(0, days)
    }
    
    // 日付フォーマット
    var monthEndDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: monthEndDate)
    }
    
    /// 本番かつ未ログインでは EKIDEN チームフローをサンプル（モック）で動かす
    private var isSampleTeamFlow: Bool {
        useMockTeamFlow || Auth.auth().currentUser == nil
    }
    
    var body: some View {
        NavigationStack {
            if userTeamId == nil {
                // 未所属の場合、チーム参加/作成画面を表示
                TeamJoinCreateView(onComplete: { teamId in
                    if isSampleTeamFlow {
                        self.userTeamId = teamId
                        if let id = teamId {
                            UserDefaults.standard.set(id, forKey: "myTeamId")
                        }
                    } else {
                        loadUserTeamId()
                    }
                    if let id = teamId {
                        self.selectedTeamId = id
                        self.showTeamDetail = true
                    }
                }, useMockFlow: isSampleTeamFlow)
                .navigationTitle("EKIDEN MODE")
                .navigationBarTitleDisplayMode(.large)
            } else {
                ZStack {
                    Color.white
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            progressView
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                            
                            slimMemberListView
                                .padding(.horizontal, 20)
                            
                            // オーナーのみ: メンバー管理（参加申請・チーム詳細）へ
                            if isTeamOwner {
                                Button(action: { showTeamDetail = true }) {
                                    HStack {
                                        Spacer()
                                        Text("メンバー管理")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .frame(height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(hex: "0F1A2E"))
                                    )
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            Button(action: {
                                showTeamChatSheet = true
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Team Chat")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "2E5CFF"))
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                    
                    NavigationLink(destination: TeamDetailView(teamId: selectedTeamId), isActive: $showTeamDetail) {
                        EmptyView()
                    }
                }
                .navigationTitle("EKIDEN MODE")
                .navigationBarTitleDisplayMode(.large)
                .sheet(isPresented: $showConditionSheet) {
                    ConditionUpdateSheet(
                        selectedCondition: $selectedCondition,
                        onSave: {
                            let oldCondition = myCondition
                            myConditionRaw = selectedCondition.rawValue
                            
                            if oldCondition != selectedCondition {
                                addSystemMessage(condition: selectedCondition)
                            }
                            
                            showConditionSheet = false
                        },
                        onCancel: {
                            showConditionSheet = false
                        }
                    )
                }
                .sheet(isPresented: $showTeamChatSheet) {
                    TeamChatSheetView(
                        teamId: selectedTeamId,
                        isSampleTeam: isSampleTeamFlow || selectedTeamId.hasPrefix("example_"),
                        teamMessages: $teamMessages,
                        myName: myName,
                        myCondition: myCondition,
                        myStatusMessage: myStatusMessage
                    )
                }
                .onAppear {
                    selectedCondition = myCondition
                    if !isSampleTeamFlow {
                        loadUserTeamId()
                    }
                    if let tid = userTeamId, !tid.isEmpty {
                        loadTeamOwner(teamId: tid)
                    }
                }
                .onChange(of: userTeamId) { _, newId in
                    if let tid = newId, !tid.isEmpty {
                        loadTeamOwner(teamId: tid)
                    } else {
                        isTeamOwner = false
                    }
                }
            }
        }
        .onAppear {
            if userTeamId == nil, isSampleTeamFlow, let savedId = UserDefaults.standard.string(forKey: "myTeamId"), !savedId.isEmpty {
                userTeamId = savedId
                selectedTeamId = savedId
            }
        }
    } // body の閉じ (修正箇所)

    private func loadUserTeamId() {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        db.collection("users").document(firebaseUser.uid).getDocument { snapshot, error in
            if let data = snapshot?.data(), let teamId = data["teamId"] as? String {
                DispatchQueue.main.async {
                    self.userTeamId = teamId
                }
            } else {
                DispatchQueue.main.async {
                    self.userTeamId = nil
                }
            }
        }
    }
    
    /// チームのオーナーかどうかを取得（メンバー管理ボタン表示用）
    private func loadTeamOwner(teamId: String) {
        // サンプルチーム: example_owner のときだけオーナー
        if teamId == "example_owner" || teamId == "example_member" {
            isTeamOwner = (teamId == "example_owner")
            return
        }
        guard let currentUid = Auth.auth().currentUser?.uid else {
            isTeamOwner = false
            return
        }
        let db = Firestore.firestore()
        db.collection("teams").document(teamId).getDocument { snapshot, _ in
            guard let data = snapshot?.data(), let ownerUid = data["ownerUid"] as? String else {
                DispatchQueue.main.async { self.isTeamOwner = false }
                return
            }
            DispatchQueue.main.async {
                self.isTeamOwner = (ownerUid == currentUid)
            }
        }
    }
    
    // MARK: - Slim Member List View
    private var slimMemberListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("メンバー")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "0F1A2E"))
                .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                ForEach(members) { member in
                    slimMemberRowView(member: member)
                }
            }
            
            Button(action: {
                selectedCondition = myCondition
                showConditionSheet = true
            }) {
                HStack {
                    Spacer()
                    Text("調子を記録する")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "2E5CFF"))
                )
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Slim Member Row View
    private func slimMemberRowView(member: TeamMember) -> some View {
        HStack(spacing: 12) {
            if let avatarImage = member.avatarImage {
                Image(systemName: avatarImage)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "0F1A2E"))
                    .saturation(0)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color(hex: "F5F7FA"))
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: member.condition.colorHex), lineWidth: member.condition == .sos ? 3 : 2)
                            )
                    )
            } else {
                Circle()
                    .fill(Color(hex: "F5F7FA"))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: member.condition.colorHex), lineWidth: member.condition == .sos ? 3 : 2)
                    )
            }
            
            Text(member.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "0F1A2E"))
                .frame(width: 70, alignment: .leading)
            
            HStack(spacing: 4) {
                Text("\(Int(member.currentDistance))km")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "0F1A2E"))
                
                Text("/")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.5))
                
                Text("\(Int(member.targetDistance))km")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: member.condition.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: member.condition.colorHex))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(member.condition == .sos ? Color(hex: member.condition.colorHex).opacity(0.1) : Color(hex: "F5F7FA").opacity(0.3))
        )
    }
    
    // MARK: - Progress View (The Tasuki Bar)
    private var progressView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Text(teamName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "0F1A2E"))
                if !selectedTeamId.isEmpty {
                    let total = PointService.shared.teamTotalPoints(teamId: selectedTeamId)
                    let tier = TeamRankTier.tier(forTeamPoints: total)
                    Text(tier.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(tier.color.opacity(0.2)))
                        .foregroundColor(tier.color)
                }
                Spacer()
                if !selectedTeamId.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(PointService.shared.teamTotalPoints(teamId: selectedTeamId))pt")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "0F1A2E"))
                        Text("累計")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.bottom, 4)
            
            Text("\(Int(progressPercentage))%")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(Color(hex: "2E5CFF"))
            
            Text("\(monthEndDateString)まで（あと\(remainingDays)日）")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "F5F7FA"))
                        .frame(height: 24)
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "2E5CFF"),
                                    Color(hex: "0F1A2E")
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(progressPercentage / 100), height: 24)
                }
            }
            .frame(height: 24)
            
            HStack {
                Text("\(Int(currentDistance))km")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "0F1A2E"))
                
                Text("/")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.5))
                
                Text("\(Int(targetDistance))km")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func addSystemMessage(condition: Condition) {
        // 注: PartnerUserモデルが定義されている必要があります。
        // ここでは便宜上、最小限の初期化を想定しています。
        let systemUser = PartnerUser(
            name: "System",
            rank: "S",
            avatarImage: nil,
            isOnline: false,
            bestCategory: .full,
            bestTime: "0:00:00",
            age: 0,
            runningSchedule: .flexible,
            purpose: "",
            nextRace: nil,
            targetTime: nil,
            runningSpots: [],
            prefecture: "Tokyo",
            gender: .male,
            condition: .good,
            statusMessage: "",
            ageGroup: "",
            runningGoal: "",
            personalBest: nil,
            activeTime: "",
            easyPace: "0:00/km",
            connectionStyle: .both
        )
        
        let systemMessage = TeamMessage(
            user: systemUser,
            content: "\(myName)さんが「\(condition.rawValue)」に変更しました。",
            timestamp: Date(),
            isSystem: true
        )
        
        teamMessages.append(systemMessage)
    }
}

// MARK: - Team Chat Sheet View（TeamView 内専用。HomeView のメッセージとは連携しない）
struct TeamChatSheetView: View {
    let teamId: String
    /// サンプルチームのときはローカルの Binding のみ使用。本番チームでは Firestore teams/{teamId}/teamChat を使用
    var isSampleTeam: Bool = false
    @Binding var teamMessages: [TeamMessage]
    let myName: String
    let myCondition: Condition
    let myStatusMessage: String
    
    @State private var messageText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.dismiss) var dismiss
    
    /// 本番チーム用: Firestore から取得したメッセージ（HomeView の会話とは別コレクション）
    @State private var firestoreMessages: [TeamMessage] = []
    @State private var chatListener: ListenerRegistration?
    
    private var displayedMessages: [TeamMessage] {
        isSampleTeam ? teamMessages : firestoreMessages
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(displayedMessages) { message in
                                    messageBubbleView(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                        .onChange(of: displayedMessages.count) { _ in
                            if let lastMessage = displayedMessages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 12) {
                        TextField("メッセージを入力...", text: $messageText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "0F1A2E"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "F5F7FA"))
                            )
                            .focused($isTextFieldFocused)
                            .lineLimit(1...4)
                        
                        Button(action: {
                            sendMessage()
                        }) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(messageText.isEmpty ? Color.gray : Color(hex: "2E5CFF"))
                                )
                        }
                        .disabled(messageText.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                }
            }
            .navigationTitle("チームチャット")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "2E5CFF"))
                }
            }
        }
        .onAppear {
            if !isSampleTeam && !teamId.isEmpty {
                startTeamChatListener()
            }
        }
        .onDisappear {
            chatListener?.remove()
            chatListener = nil
        }
    }
    
    /// 本番チーム用: teams/{teamId}/teamChat を監視（HomeView メッセージとは別）
    private func startTeamChatListener() {
        chatListener?.remove()
        let db = Firestore.firestore()
        chatListener = db.collection("teams").document(teamId).collection("teamChat")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else { return }
                let list = docs.compactMap { doc -> TeamMessage? in
                    let data = doc.data()
                    let senderName = data["senderName"] as? String ?? ""
                    let content = data["content"] as? String ?? ""
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let isSystem = data["isSystem"] as? Bool ?? false
                    let id = UUID(uuidString: doc.documentID) ?? UUID()
                    let user = minimalPartnerUser(name: senderName)
                    return TeamMessage(id: id, user: user, content: content, timestamp: timestamp, isSystem: isSystem)
                }
                DispatchQueue.main.async {
                    firestoreMessages = list
                }
            }
    }
    
    private func minimalPartnerUser(name: String) -> PartnerUser {
        PartnerUser(
            name: name,
            rank: "—",
            avatarImage: "person.circle.fill",
            isOnline: false,
            bestCategory: .fiveKm,
            bestTime: "—",
            age: 0,
            runningSchedule: .flexible,
            purpose: "",
            nextRace: nil,
            targetTime: nil,
            runningSpots: [],
            prefecture: "",
            gender: .other,
            condition: .good,
            statusMessage: "",
            ageGroup: "",
            runningGoal: "",
            personalBest: nil,
            activeTime: "",
            easyPace: "—",
            connectionStyle: .both
        )
    }
    
    @ViewBuilder
    private func messageBubbleView(message: TeamMessage) -> some View {
        if message.isSystem {
            HStack {
                Spacer()
                Text("--- \(message.content) ---")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.4))
                Spacer()
            }
            .padding(.vertical, 8)
        } else {
            let isFromMe = message.user.name == myName
            
            HStack(alignment: .top, spacing: 8) {
                if !isFromMe {
                    if let avatarImage = message.user.avatarImage {
                        Image(systemName: avatarImage)
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "0F1A2E"))
                            .saturation(0)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color(hex: "F5F7FA"))
                            )
                    }
                }
                
                VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                    if !isFromMe {
                        Text(message.user.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "0F1A2E").opacity(0.6))
                    }
                    
                    Text(message.content)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(isFromMe ? .white : Color(hex: "0F1A2E"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isFromMe ? Color(hex: "2E5CFF") : Color(hex: "F5F7FA"))
                        )
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isFromMe ? .trailing : .leading)
                
                if isFromMe {
                    Spacer()
                }
            }
        }
    }
    
    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        if isSampleTeam {
            let myUser = PartnerUser(
                name: myName,
                rank: "A",
                avatarImage: "person.circle.fill",
                isOnline: true,
                bestCategory: .full,
                bestTime: "3:10:00",
                age: 29,
                runningSchedule: .weekdayEvening,
                purpose: "サブ3目標",
                nextRace: nil,
                targetTime: nil,
                runningSpots: [],
                prefecture: "Tokyo",
                gender: .male,
                condition: myCondition,
                statusMessage: myStatusMessage,
                ageGroup: "20s",
                runningGoal: "Sub3",
                personalBest: "3:10:00",
                activeTime: "Night",
                easyPace: "5:00/km",
                connectionStyle: .both
            )
            let newMessage = TeamMessage(user: myUser, content: content, timestamp: Date(), isSystem: false)
            teamMessages.append(newMessage)
        } else {
            // 本番チーム: Firestore に保存（HomeView のメッセージとは連携しない）
            let senderId = Auth.auth().currentUser?.uid ?? "anonymous"
            let db = Firestore.firestore()
            db.collection("teams").document(teamId).collection("teamChat").addDocument(data: [
                "senderId": senderId,
                "senderName": myName,
                "content": content,
                "timestamp": Timestamp(date: Date()),
                "isSystem": false
            ]) { _ in }
        }
        messageText = ""
        isTextFieldFocused = false
    }
}

// MARK: - Condition Update Sheet
struct ConditionUpdateSheet: View {
    @Binding var selectedCondition: Condition
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("調子")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "0F1A2E"))
                            
                            Picker("調子", selection: $selectedCondition) {
                                ForEach(Condition.allCases, id: \.self) { condition in
                                    HStack {
                                        Image(systemName: condition.icon)
                                            .foregroundColor(Color(hex: condition.colorHex))
                                        Text(condition.rawValue)
                                    }
                                    .tag(condition)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("調子を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        onCancel()
                    }
                    .foregroundColor(Color(hex: "0F1A2E"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave()
                    }
                    .foregroundColor(Color(hex: "2E5CFF"))
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    TeamView(useMockTeamFlow: true)
}

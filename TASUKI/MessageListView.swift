//
//  MessageListView.swift
//  TASUKI
//
//  Created by yoshi H on 2026/01/28.
//

import SwiftUI

// MARK: - Message Conversation Model（バックエンドで一意の conversationId を持つ。既読・未読フラグ付き）
struct MessageConversation: Identifiable {
    /// バックエンド（Firestore）で発行された一意の会話ID
    let conversationId: String
    let partnerName: String
    let avatarImage: String?
    let lastMessage: String
    let timestamp: Date
    /// 未読があるか（lastMessageAt > 自分の lastReadAt）
    let hasUnread: Bool
    
    var id: String { conversationId }
    
    init(conversationId: String, partnerName: String, avatarImage: String? = "person.circle.fill", lastMessage: String, timestamp: Date = Date(), hasUnread: Bool = false) {
        self.conversationId = conversationId
        self.partnerName = partnerName
        self.avatarImage = avatarImage
        self.lastMessage = lastMessage
        self.timestamp = timestamp
        self.hasUnread = hasUnread
    }
}

// MARK: - チャット / メッセージ タブ
enum MessageListTab: String, CaseIterable {
    case chat = "チャット"
    case message = "メッセージ"
}

// MARK: - Message List View
struct MessageListView: View {
    @State private var selectedTab: MessageListTab = .chat
    @State private var conversations: [MessageConversation] = []
    @State private var isLoading = true
    @StateObject private var conversationManager = ConversationManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // チャット / メッセージ 切り替えタブ
                Picker("", selection: $selectedTab) {
                    ForEach(MessageListTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                
                ZStack {
                    Color.white
                        .ignoresSafeArea()
                    
                    if isLoading {
                        ProgressView()
                    } else if conversations.isEmpty {
                        VStack {
                            Text(selectedTab == .chat ? "チャットがありません" : "メッセージがありません")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color(hex: "0F1A2E").opacity(0.6))
                        }
                    } else {
                        List {
                            ForEach(conversations) { conversation in
                                NavigationLink(destination: ChatView(conversationId: conversation.conversationId, partnerName: conversation.partnerName)) {
                                    conversationRowView(conversation: conversation)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(selectedTab == .chat ? "チャット" : "メッセージ")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadConversations()
            }
        }
    }
    
    // MARK: - Conversation Row View
    private func conversationRowView(conversation: MessageConversation) -> some View {
        HStack(spacing: 12) {
            // アバター画像（左）
            if let avatarImage = conversation.avatarImage {
                Image(systemName: avatarImage)
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "0F1A2E"))
                    .saturation(0)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(Color(hex: "F5F7FA"))
                    )
            } else {
                Circle()
                    .fill(Color(hex: "F5F7FA"))
                    .frame(width: 56, height: 56)
            }
            
            // 中央: 名前と最新メッセージ（未読時は名前を太字＋青ドット）
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if conversation.hasUnread {
                        Circle()
                            .fill(Color(hex: "2E5CFF"))
                            .frame(width: 8, height: 8)
                    }
                    Text(conversation.partnerName)
                        .font(.system(size: 16, weight: conversation.hasUnread ? .bold : .semibold))
                        .foregroundColor(Color(hex: "0F1A2E"))
                        .lineLimit(1)
                }
                
                Text(conversation.lastMessage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(conversation.hasUnread ? Color(hex: "0F1A2E").opacity(0.8) : Color(hex: "0F1A2E").opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 右: 送信時間
            Text(formatTime(conversation.timestamp))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(hex: "0F1A2E").opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Methods
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func loadConversations() {
        isLoading = true
        conversationManager.fetchMyConversations { result in
            isLoading = false
            switch result {
            case .success(let list):
                conversations = list
            case .failure:
                // 未ログインや取得失敗時はサンプル表示（ローカル用の仮ID）
                loadDummyConversations()
            }
        }
    }
    
    private func loadDummyConversations() {
        let calendar = Calendar.current
        let now = Date()
        conversations = [
            MessageConversation(
                conversationId: "dummy-tanaka",
                partnerName: "Tanaka-san",
                avatarImage: "person.circle.fill",
                lastMessage: "週末の朝が良いです。6時頃からいかがでしょうか？",
                timestamp: calendar.date(byAdding: .minute, value: -30, to: now) ?? now,
                hasUnread: true
            ),
            MessageConversation(
                conversationId: "dummy-sato",
                partnerName: "Sato-san",
                avatarImage: "person.circle.fill",
                lastMessage: "明日の練習会、参加します！",
                timestamp: calendar.date(byAdding: .hour, value: -1, to: now) ?? now,
                hasUnread: true
            ),
            MessageConversation(
                conversationId: "dummy-yamada",
                partnerName: "Yamada-san",
                avatarImage: "person.circle.fill",
                lastMessage: "了解しました。では明日の朝6時に待ち合わせましょう。",
                timestamp: calendar.date(byAdding: .hour, value: -2, to: now) ?? now,
                hasUnread: true
            ),
            MessageConversation(
                conversationId: "dummy-suzuki",
                partnerName: "Suzuki-san",
                avatarImage: "person.circle.fill",
                lastMessage: "ありがとうございます！一緒に走りましょう！",
                timestamp: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                hasUnread: false
            ),
            MessageConversation(
                conversationId: "dummy-watanabe",
                partnerName: "Watanabe-san",
                avatarImage: "person.circle.fill",
                lastMessage: "ハーフマラソン、完走お疲れ様でした！",
                timestamp: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                hasUnread: false
            ),
        ]
    }
}

#Preview {
    MessageListView()
}

//
//  MessageListView.swift
//  TASUKI
//
//  Created by yoshi H on 2026/01/28.
//

import SwiftUI

// MARK: - Message Conversation Model
struct MessageConversation: Identifiable {
    let id = UUID()
    let partnerName: String
    let avatarImage: String?
    let lastMessage: String
    let timestamp: Date
    
    init(partnerName: String, avatarImage: String? = "person.circle.fill", lastMessage: String, timestamp: Date = Date()) {
        self.partnerName = partnerName
        self.avatarImage = avatarImage
        self.lastMessage = lastMessage
        self.timestamp = timestamp
    }
}

// MARK: - Message List View
struct MessageListView: View {
    @State private var conversations: [MessageConversation] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色: White
                Color.white
                    .ignoresSafeArea()
                
                if conversations.isEmpty {
                    // 空の状態
                    VStack {
                        Text("メッセージがありません")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color(hex: "0F1A2E").opacity(0.6))
                    }
                } else {
                    // メッセージリスト
                    List {
                        ForEach(conversations) { conversation in
                            NavigationLink(destination: ChatView(partnerName: conversation.partnerName)) {
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
            .navigationTitle("メッセージ")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadDummyConversations()
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
            
            // 中央: 名前と最新メッセージ
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.partnerName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "0F1A2E"))
                    .lineLimit(1)
                
                Text(conversation.lastMessage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.6))
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
    
    private func loadDummyConversations() {
        let calendar = Calendar.current
        let now = Date()
        
        conversations = [
            MessageConversation(
                partnerName: "Tanaka-san",
                avatarImage: "person.circle.fill",
                lastMessage: "週末の朝が良いです。6時頃からいかがでしょうか？",
                timestamp: calendar.date(byAdding: .minute, value: -30, to: now) ?? now
            ),
            MessageConversation(
                partnerName: "Sato-san",
                avatarImage: "person.circle.fill",
                lastMessage: "ありがとうございます！一緒に走りましょう！",
                timestamp: calendar.date(byAdding: .hour, value: -2, to: now) ?? now
            ),
            MessageConversation(
                partnerName: "Yamada-san",
                avatarImage: "person.circle.fill",
                lastMessage: "了解しました。では明日の朝6時に待ち合わせましょう。",
                timestamp: calendar.date(byAdding: .day, value: -1, to: now) ?? now
            ),
        ]
    }
}

#Preview {
    MessageListView()
}

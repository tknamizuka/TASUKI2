//
//  ChatView.swift
//  TASUKI
//
//  Created by yoshi H on 2026/01/28.
//

import SwiftUI

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromMe: Bool
    let timestamp: Date
    
    init(text: String, isFromMe: Bool, timestamp: Date = Date()) {
        self.text = text
        self.isFromMe = isFromMe
        self.timestamp = timestamp
    }
}

// MARK: - Chat View
struct ChatView: View {
    let partnerName: String
    @Environment(\.dismiss) var dismiss
    
    @State private var messages: [ChatMessage] = []
    @State private var messageText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    init(partnerName: String = "Tanaka-san") {
        self.partnerName = partnerName
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 安全対策ヘッダー
            safetyHeaderView
            
            // メッセージエリア
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            messageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // 入力エリア（画面最下部に固定）
            inputAreaView
        }
        .background(Color.white)
        .navigationTitle(partnerName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "2E5CFF"))
                }
            }
        }
        .onAppear {
            loadDummyMessages()
        }
    }
    
    // MARK: - Safety Header View
    private var safetyHeaderView: some View {
        HStack {
            Text("トラブル防止のため、金銭のやり取りやLINE交換は禁止されています")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
    }
    
    // MARK: - Message Bubble View
    @ViewBuilder
    private func messageBubbleView(message: ChatMessage) -> some View {
        HStack {
            if message.isFromMe {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(message.isFromMe ? .white : .black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isFromMe ? Color.royalBlue : Color.gray.opacity(0.2))
                    )
            }
            
            if !message.isFromMe {
                Spacer(minLength: 60)
            }
        }
    }
    
    // MARK: - Input Area View
    private var inputAreaView: some View {
        HStack(spacing: 12) {
            TextField("メッセージを入力", text: $messageText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                )
                .focused($isTextFieldFocused)
            
            Button(action: {
                sendMessage()
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(messageText.isEmpty ? Color.gray : Color.royalBlue)
                    )
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    // MARK: - Helper Methods
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let newMessage = ChatMessage(text: messageText, isFromMe: true)
        messages.append(newMessage)
        messageText = ""
        isTextFieldFocused = false
        
        // ダミー: 相手からの返信をシミュレート（1秒後）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let replyMessage = ChatMessage(
                text: "ありがとうございます！",
                isFromMe: false
            )
            messages.append(replyMessage)
        }
    }
    
    private func loadDummyMessages() {
        messages = [
            ChatMessage(text: "こんにちは！ランニングパートナーを探しています。", isFromMe: false),
            ChatMessage(text: "こんにちは！私も探していました。一緒に走りましょう！", isFromMe: true),
            ChatMessage(text: "ありがとうございます！いつ頃が都合よろしいですか？", isFromMe: false),
            ChatMessage(text: "週末の朝が良いです。6時頃からいかがでしょうか？", isFromMe: true),
        ]
    }
}

#Preview {
    NavigationStack {
        ChatView(partnerName: "Tanaka-san")
    }
}

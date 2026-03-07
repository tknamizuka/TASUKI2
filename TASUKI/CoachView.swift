//
//  CoachView.swift
//  TASUKI
//
//  Created by yoshi H on 2026/01/28.
//

import SwiftUI

struct CoachView: View {
    @State private var selectedCategory: String = "すべて"
    @State private var showQuestionSheet = false
    @State private var qaItems: [QAItem] = mockQAItems
    
    private let categories = ["すべて", "トレーニング", "ケア", "食事", "ギア"]
    
    // フィルタリングされたQ&Aリスト
    private var filteredQAItems: [QAItem] {
        if selectedCategory == "すべて" {
            return qaItems
        }
        return qaItems.filter { $0.category == selectedCategory }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色: White
                Color.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // ヘッダー
                        headerView
                            .padding(.horizontal, 20)
                            .padding(.top, 32)   // EKIDEN MODE と同程度の位置に調整
                            .padding(.bottom, 16)
                        
                        // カテゴリフィルタ
                        categoryFilterView
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        
                        // Q&Aリスト
                        VStack(spacing: 16) {
                            ForEach(filteredQAItems) { item in
                                qaCardView(item: item)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)  // フローティングボタンのスペース
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottomTrailing) {
                // 質問ボタン（フローティング）
                Button(action: {
                    showQuestionSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 56, weight: .regular))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(Color(hex: "2E5CFF"))
                                .frame(width: 56, height: 56)
                        )
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .sheet(isPresented: $showQuestionSheet) {
                QuestionPostSheet(
                    onPost: { question, category in
                        // 新しい質問を追加
                        let newItem = QAItem(
                            question: question,
                            answer: nil,
                            askerName: "Hiro",  // 自分のニックネーム（AppStorageから取得する想定）
                            coachName: nil,     // 回答待ち状態なのでnil
                            category: category,
                            postedDate: Date()
                        )
                        qaItems.insert(newItem, at: 0)
                        showQuestionSheet = false
                    },
                    onCancel: {
                        showQuestionSheet = false
                    }
                )
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coach")
                .font(.system(size: 34, weight: .bold)) // Find / EKIDEN MODE に揃えたタイトルサイズ
                .foregroundColor(Color(hex: "0F1A2E"))
            
            Text("元箱根駅伝ランナーや実業団選手があなたの疑問に答えます")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Category Filter View
    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    categoryButton(category: category)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func categoryButton(category: String) -> some View {
        Button(action: {
            selectedCategory = category
        }) {
            Text(category)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(selectedCategory == category ? .white : Color(hex: "0F1A2E"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selectedCategory == category ? Color(hex: "2E5CFF") : Color(hex: "F5F7FA"))
                )
        }
    }
    
    // MARK: - Q&A Card View
    private func qaCardView(item: QAItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // カテゴリと投稿日
            HStack {
                Text(item.category)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(hex: "2E5CFF"))
                    )
                
                Spacer()
                
                Text(formatDate(item.postedDate))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.5))
            }
            
            // 質問
            VStack(alignment: .leading, spacing: 4) {
                Text("Q")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "2E5CFF"))
                
                Text(item.question)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "0F1A2E"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // 質問者
            HStack(spacing: 4) {
                Text("質問者:")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.6))
                Text(item.askerName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.8))
            }
            
            Divider()
                .background(Color(hex: "F5F7FA"))
            
            // 回答
            if let answer = item.answer {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("A")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
                        
                        if let coachName = item.coachName {
                            NavigationLink(destination: CoachProfileView(coachName: coachName)) {
                                Text(coachName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "2E5CFF"))
                            }
                        }
                    }
                    
                    Text(answer)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(hex: "0F1A2E"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "F5F7FA"))
                )
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("A")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "0F1A2E").opacity(0.5))
                    
                    Text("Coachが回答を作成中...")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(hex: "0F1A2E").opacity(0.5))
                        .italic()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "F5F7FA").opacity(0.5))
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Date Formatter
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

// MARK: - Question Post Sheet
struct QuestionPostSheet: View {
    let onPost: (String, String) -> Void
    let onCancel: () -> Void
    
    @State private var questionText: String = ""
    @State private var selectedCategory: String = "トレーニング"
    @Environment(\.dismiss) var dismiss
    
    private let categories = ["トレーニング", "ケア", "食事", "ギア"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // カテゴリ選択
                        VStack(alignment: .leading, spacing: 12) {
                            Text("カテゴリ")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "0F1A2E"))
                            
                            Picker("カテゴリ", selection: $selectedCategory) {
                                ForEach(categories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // 質問入力
                        VStack(alignment: .leading, spacing: 12) {
                            Text("質問内容")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "0F1A2E"))
                            
                            TextEditor(text: $questionText)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "0F1A2E"))
                                .frame(height: 200)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "F5F7FA"))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("質問を投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        onCancel()
                    }
                    .foregroundColor(Color(hex: "0F1A2E"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("投稿") {
                        if !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onPost(questionText, selectedCategory)
                        }
                    }
                    .foregroundColor(questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color(hex: "2E5CFF"))
                    .fontWeight(.semibold)
                    .disabled(questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    CoachView()
}

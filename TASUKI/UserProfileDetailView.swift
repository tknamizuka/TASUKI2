import SwiftUI
import UIKit

struct UserProfileDetailView: View {
    let user: User
    @State private var showRequestAlert = false
    @State private var showRequestSent = false
    @Environment(\.dismiss) var dismiss
    
    // 月間進捗率の計算
    private var monthlyProgress: Double {
        min(user.monthlyDistance / user.monthlyTarget, 1.0)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ヘッダーエリア
                VStack(spacing: 12) {
                    // プロフィール画像（丸型）
                    if UIImage(named: user.profileImage) != nil {
                        Image(user.profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "0F1A2E").opacity(0.1), lineWidth: 2)
                            )
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 120))
                            .foregroundColor(Color(hex: "0F1A2E").opacity(0.2))
                            .frame(width: 120, height: 120)
                    }
                    
                    // 名前
                    Text(user.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "0F1A2E"))
                    
                    // 年齢・性別
                    Text("\(user.age)歳 / \(user.gender)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // マッチ度バッジ
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("マッチ度: \(user.matchRate)%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Color(hex: "0F1A2E"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "0F1A2E").opacity(0.1))
                    )
                }
                .padding(.top, 20)
                
                // タグエリア
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Rankタグ
                        Text(user.rank)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "0F1A2E"))
                            )
                        
                        // Purposeタグ
                        Text(user.purpose)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color(hex: "0F1A2E"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "0F1A2E").opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 20)
                }
                
                // 情報カードエリア
                VStack(spacing: 12) {
                    // Personal Best カード
                    if !user.personalBest.isEmpty {
                        infoCard(
                            icon: "trophy.fill",
                            title: "Personal Best",
                            value: user.personalBest,
                            iconColor: Color(hex: "FFD60A")
                        )
                    }
                    
                    // Schedule カード
                    infoCard(
                        icon: "calendar",
                        title: "Schedule",
                        value: user.schedule,
                        iconColor: Color(hex: "0F1A2E")
                    )
                    
                    // Next Race カード
                    if !user.nextRace.isEmpty {
                        infoCard(
                            icon: "flag.fill",
                            title: "Next Race",
                            value: user.nextRace,
                            iconColor: Color(hex: "2E5CFF")
                        )
                    }
                    
                    // Target カード
                    if !user.targetTime.isEmpty {
                        infoCard(
                            icon: "target",
                            title: "Target",
                            value: user.targetTime,
                            iconColor: Color(hex: "FF453A")
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                // Running Stats セクション
                VStack(alignment: .leading, spacing: 16) {
                    Text("Running Stats")
                        .font(.headline)
                        .foregroundColor(Color(hex: "0F1A2E"))
                        .padding(.horizontal, 20)
                    
                    // Avg Pace
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Avg Pace")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(user.avgPace)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(hex: "0F1A2E"))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal, 20)
                    
                    // Monthly Distance (進捗付き)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Monthly Dist")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(user.monthlyDistance))km / \(Int(user.monthlyTarget))km (\(Int(monthlyProgress * 100))%)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: "0F1A2E"))
                        }
                        
                        // 進捗バー
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // 背景バー
                                RoundedRectangle(cornerRadius: 8)
                                    .frame(height: 12)
                                    .foregroundColor(Color.gray.opacity(0.1))
                                
                                // 進捗バー
                                RoundedRectangle(cornerRadius: 8)
                                    .frame(width: geometry.size.width * monthlyProgress, height: 12)
                                    .foregroundColor(Color(hex: "0F1A2E"))
                                    .animation(.easeOut, value: monthlyProgress)
                            }
                        }
                        .frame(height: 12)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal, 20)
                }
                
                // 自己紹介 (Bio)
                VStack(alignment: .leading, spacing: 8) {
                    Text("自己紹介")
                        .font(.headline)
                        .foregroundColor(Color(hex: "0F1A2E"))
                    
                    Text(user.bio)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 20)
                
                Spacer(minLength: 100) // ボタン分の余白
            }
            .padding(.bottom, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
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
        .overlay(alignment: .bottom) {
            // マッチングリクエストボタン
            Button(action: {
                showRequestAlert = true
            }) {
                Text("マッチングのリクエストを送る")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "0F1A2E"))
                    .cornerRadius(30)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            .padding()
            .background(
                LinearGradient(colors: [.white.opacity(0), .white], startPoint: .top, endPoint: .bottom)
                    .frame(height: 100)
            )
        }
        .alert("リクエスト送信", isPresented: $showRequestAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("送る") {
                // マッチングリクエスト送信処理
                print("\(user.name)さんにマッチングリクエストを送信しました")
                showRequestSent = true
            }
        } message: {
            Text("\(user.name)さんにマッチングリクエストを送りますか？")
        }
        .alert("送信完了", isPresented: $showRequestSent) {
            Button("OK") { }
        } message: {
            Text("\(user.name)さんにマッチングリクエストを送信しました")
        }
    }
    
    // MARK: - Info Card Helper
    private func infoCard(icon: String, title: String, value: String, iconColor: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "0F1A2E"))
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

#Preview {
    NavigationView {
        UserProfileDetailView(user: mockUsers[0])
    }
}

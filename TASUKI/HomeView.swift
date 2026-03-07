//
//  HomeView.swift
//  TASUKI
//
//  Created by yoshi H on 2026/01/28.
//

import SwiftUI

struct HomeView: View {
    // 目標管理用のデータ
    @State private var currentDistance: Double = 45.2
    @State private var goalDistance: Double = 100.0
    
    // 進捗率（0.0〜1.0）
    var progress: CGFloat {
        return CGFloat(min(currentDistance / goalDistance, 1.0))
    }
    
    // 進捗率（%整数）
    var progressPercent: Int {
        return Int((currentDistance / goalDistance) * 100)
    }
    
    var body: some View {
        VStack(spacing: 40) {
            
            // 1. ブランドビジュアル
            ZStack {
                Image("runner")
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width * 0.9)
                    .opacity(0.15)
                
                Text("TASUKI")
                    .font(.system(size: 50, weight: .heavy))
                    .tracking(10)
                    .foregroundColor(Color(hex: "0F1A2E"))
                    .shadow(color: .white.opacity(0.8), radius: 2, x: 0, y: 0)
            }
            .padding(.top, 20)
            
            Spacer()
            
            // 2. 月間目標進捗 (％表示)
            VStack(spacing: 15) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 250, height: 250)
                    
                    Circle()
                        .trim(from: 0.0, to: progress)
                        .stroke(Color(hex: "0F1A2E"), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .frame(width: 250, height: 250)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.0), value: progress)
                    
                    VStack(spacing: 5) {
                        HStack(alignment: .lastTextBaseline, spacing: 5) {
                            Text("\(progressPercent)")
                                .font(.system(size: 80, weight: .bold))
                                .foregroundColor(Color(hex: "0F1A2E"))
                            
                            Text("%")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(Color(hex: "0F1A2E"))
                        }
                        
                        Text("\(String(format: "%.1f", currentDistance)) / \(Int(goalDistance)) km")
                             .font(.subheadline)
                             .fontWeight(.bold)
                             .foregroundColor(.gray)
                    }
                }
                
                Text("MONTHLY GOAL")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .tracking(2)
            }
            
            Spacer()
            
            // 3. 通貨表示 (pt)
            VStack(spacing: 5) {
                Text("TOTAL POINTS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .tracking(2)
                
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text("12,500")
                        .font(.system(size: 44, weight: .bold)) 
                        .foregroundColor(Color(hex: "0F1A2E"))
                    
                    Text("pt") // 小文字に変更
                        .font(.title3) // サイズ調整
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .padding(.bottom, 4) // ベースライン微調整
                }
            }
            .padding(.bottom, 50)
        }
        .background(Color.white)
    }
}

#Preview {
    HomeView()
}

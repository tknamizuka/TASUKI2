//
//  SoloRunHubView.swift
//  TASUKI
//
//  一人で走る: Run（記録）と Time Trial（タイムトライアル）をまとめたハブ画面
//

import SwiftUI

struct SoloRunHubView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.tasukiDarkBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Text("Solo Run Mode")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.tasukiMutedText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        NavigationLink(destination: RunRecordingView()) {
                            soloOptionCard(
                                title: "Run",
                                subtitle: "走行を記録して保存",
                                icon: "figure.run"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: TimeTrialEntryView()) {
                            soloOptionCard(
                                title: "タイムトライアル",
                                subtitle: "距離を選んで同ランクと競う",
                                icon: "stopwatch.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Solo Running Mode")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func soloOptionCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Color.tasukiAccentOrange)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.tasukiAccentOrange.opacity(0.15))
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.tasukiPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color.tasukiMutedText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.tasukiMutedText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
    }
}

#Preview {
    SoloRunHubView()
}

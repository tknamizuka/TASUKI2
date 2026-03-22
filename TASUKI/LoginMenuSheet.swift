//
//  LoginMenuSheet.swift
//  TASUKI
//
//  ログイン画面右上メニュー（利用規約・プライバシーポリシー・お問い合わせ・アカウント管理）
//

import SwiftUI

enum LoginMenuAction {
    case terms
    case privacy
    case contact
    case account
}

struct LoginMenuSheet: View {
    @Environment(\.dismiss) var dismiss
    let onSelect: (LoginMenuAction) -> Void

    private func menuRow(icon: String, label: String, action: LoginMenuAction) -> some View {
        Button {
            onSelect(action)
            switch action {
            case .terms, .privacy:
                break
            case .contact, .account:
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.tasukiPrimary)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.tasukiPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.tasukiMutedText)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.tasukiSurface)
            )
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("メニュー")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.tasukiPrimary)

            VStack(spacing: 10) {
                menuRow(icon: "info.circle", label: "利用規約", action: .terms)
                menuRow(icon: "lock.shield", label: "プライバシーポリシー", action: .privacy)
                menuRow(icon: "headphones", label: "お問い合わせ", action: .contact)
                menuRow(icon: "person.crop.circle", label: "アカウント管理", action: .account)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.tasukiPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.tasukiSurface))
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 4)
        )
    }
}

#Preview {
    LoginMenuSheet(onSelect: { _ in })
}

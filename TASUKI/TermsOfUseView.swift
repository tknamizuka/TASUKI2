//
//  TermsOfUseView.swift
//  TASUKI
//
//  利用規約全文表示画面
//

import SwiftUI

struct TermsOfUseView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(LegalTexts.termsOfServiceText)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("利用規約")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TermsOfUseView()
}

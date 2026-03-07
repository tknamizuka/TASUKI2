import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // ロゴ / タイトル
                VStack(spacing: 8) {
                    Text("TASUKI")
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundColor(Color(hex: "0F1A2E"))
                        .tracking(6)
                    
                    Text("ログインして、仲間と走ろう")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                // 入力フォーム
                VStack(spacing: 16) {
                    TextField("メールアドレス", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textContentType(.emailAddress)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "F5F7FA"))
                        )
                    
                    SecureField("パスワード", text: $password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textContentType(.password)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "F5F7FA"))
                        )
                }
                .padding(.horizontal, 24)
                
                // ボタン
                VStack(spacing: 12) {
                    Button(action: {
                        handleSignIn()
                    }) {
                        Text("ログイン")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "0F1A2E"))
                            .cornerRadius(24)
                    }
                    .disabled(authManager.isLoading)
                    
                    Button(action: {
                        handleSignUp()
                    }) {
                        Text("新規登録")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "0F1A2E"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color(hex: "0F1A2E"), lineWidth: 1)
                            )
                    }
                    .disabled(authManager.isLoading)
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            
            // ローディング表示
            if authManager.isLoading {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleSignIn() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください。"
            showError = true
            return
        }
        authManager.signIn(email: email, password: password) { result in
            switch result {
            case .success:
                break
            case .failure:
                errorMessage = authManager.errorMessage
                showError = true
            }
        }
    }
    
    private func handleSignUp() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください。"
            showError = true
            return
        }
        authManager.signUp(email: email, password: password) { result in
            switch result {
            case .success:
                break
            case .failure:
                errorMessage = authManager.errorMessage
                showError = true
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}


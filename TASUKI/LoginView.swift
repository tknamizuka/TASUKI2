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

                socialLoginSection
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

    private var socialLoginSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
                Text("または")
                    .font(.caption)
                    .foregroundColor(.gray)
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
            }

            socialButton(provider: .apple, icon: "apple.logo")
            socialButton(provider: .line, icon: "message.fill")
            socialButton(provider: .google, icon: "globe")
            socialButton(provider: .facebook, icon: "person.crop.square.fill")
        }
    }

    private func socialButton(provider: SocialAuthProvider, icon: String) -> some View {
        Button {
            handleSocialSignIn(provider)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 20)
                Text(provider.displayName)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .foregroundColor(Color(hex: "0F1A2E"))
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "F5F7FA"))
            )
        }
        .disabled(authManager.isLoading)
    }

    private func handleSocialSignIn(_ provider: SocialAuthProvider) {
        authManager.signIn(with: provider) { result in
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


import Foundation
import FirebaseAuth
import FirebaseCore
import Combine

enum SocialAuthProvider: CaseIterable, Identifiable {
    case apple
    case line
    case google
    case facebook

    var id: String { providerID }

    var providerID: String {
        switch self {
        case .apple:
            return "apple.com"
        case .line:
            // Firebase Authentication の OIDC で LINE を設定した場合の一般的な provider ID
            return "oidc.line"
        case .google:
            return "google.com"
        case .facebook:
            return "facebook.com"
        }
    }

    var displayName: String {
        switch self {
        case .apple: return "Apple IDで続行"
        case .line: return "LINEで続行"
        case .google: return "Googleで続行"
        case .facebook: return "Facebookで続行"
        }
    }

    var scopes: [String] {
        switch self {
        case .apple:
            return ["email", "name"]
        default:
            return []
        }
    }
}

final class AuthManager: ObservableObject {
    @Published var isUserLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    /// 本番用
    convenience init() {
        self.init(forPreview: false)
    }
    
    /// プレビュー用: forPreview == true のときは Firebase に触れずクラッシュを防ぐ
    init(forPreview: Bool) {
        if forPreview {
            isUserLoggedIn = false
            authStateListener = nil
            return
        }
        FirebaseBootstrap.configureIfNeeded()
        isUserLoggedIn = Auth.auth().currentUser != nil
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isUserLoggedIn = (user != nil)
            }
        }
    }
    
    deinit {
        if let handle = authStateListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Auth Actions
    
    func signUp(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let error = error as NSError? {
                    if let authError = AuthErrorCode(rawValue: error.code) {
                        switch authError.code {
                        case .invalidEmail:
                            self.errorMessage = "メールアドレスの形式が正しくありません。"
                        case .emailAlreadyInUse:
                            self.errorMessage = "このメールアドレスは既に使用されています。"
                        case .weakPassword:
                            self.errorMessage = "パスワードは6文字以上にしてください。"
                        default:
                            self.errorMessage = "エラーが発生しました。もう一度お試しください。"
                        }
                    } else {
                        self.errorMessage = "エラーが発生しました。もう一度お試しください。"
                    }
                    completion(.failure(error))
                } else {
                    self.errorMessage = ""
                    completion(.success(()))
                }
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let error = error as NSError? {
                    if let authError = AuthErrorCode(rawValue: error.code) {
                        switch authError.code {
                        case .invalidEmail:
                            self.errorMessage = "メールアドレスの形式が正しくありません。"
                        case .wrongPassword:
                            self.errorMessage = "パスワードが間違っています。"
                        case .userNotFound:
                            self.errorMessage = "このメールアドレスは登録されていません。"
                        default:
                            self.errorMessage = "エラーが発生しました。もう一度お試しください。"
                        }
                    } else {
                        self.errorMessage = "エラーが発生しました。もう一度お試しください。"
                    }
                    completion(.failure(error))
                } else {
                    self.errorMessage = ""
                    completion(.success(()))
                }
            }
        }
    }

    func signIn(with provider: SocialAuthProvider, completion: @escaping (Result<Void, Error>) -> Void) {
        isLoading = true
        errorMessage = ""

        let oauthProvider = OAuthProvider(providerID: provider.providerID)
        if !provider.scopes.isEmpty {
            oauthProvider.scopes = provider.scopes
        }

        Auth.auth().signIn(with: oauthProvider, uiDelegate: nil) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let error = error as NSError? {
                    self.errorMessage = self.socialAuthErrorMessage(error, provider: provider)
                    completion(.failure(error))
                } else {
                    self.errorMessage = ""
                    completion(.success(()))
                }
            }
        }
    }
    
    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.isUserLoggedIn = false
            }
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }

    private func socialAuthErrorMessage(_ error: NSError, provider: SocialAuthProvider) -> String {
        if let authError = AuthErrorCode(rawValue: error.code) {
            switch authError.code {
            case .operationNotAllowed:
                return "\(provider.displayName) は現在利用できません。Firebase Console の認証設定を確認してください。"
            case .webContextAlreadyPresented:
                return "別のログイン画面が開いています。閉じてから再度お試しください。"
            case .webContextCancelled:
                return "ログインがキャンセルされました。"
            case .webNetworkRequestFailed:
                return "ネットワークエラーが発生しました。通信環境を確認してください。"
            case .accountExistsWithDifferentCredential:
                return "別のログイン方法で登録済みのアカウントです。既存の方法でログインしてください。"
            default:
                return "\(provider.displayName) でログインできませんでした。設定または通信状況を確認してください。"
            }
        }
        return "\(provider.displayName) でログインできませんでした。"
    }
}


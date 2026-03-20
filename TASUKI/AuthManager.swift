import Foundation
import FirebaseAuth
import FirebaseCore
import Combine

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
}


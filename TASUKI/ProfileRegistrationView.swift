import SwiftUI
import FirebaseAuth
import PhotosUI

struct ProfileRegistrationView: View {
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var userManager: UserManager
    @AppStorage("skipProfileRegistration") private var skipProfileRegistration: Bool = false
    
    // 完了時のコールバック
    var onComplete: (() -> Void)? = nil
    
    // 入力値
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil
    @State private var username: String = ""
    @State private var selectedGender: String? = nil
    @State private var birthDate: Date = Calendar.current.date(from: DateComponents(year: 1998, month: 1, day: 1)) ?? Date()
    @State private var selectedPrefecture: String = allPrefectures.first ?? "東京都"
    @State private var activityArea: String = ""
    @State private var selectedRunCategory: String? = nil  // ビギナー, 5k, 10k, ハーフ, フル
    @State private var runMinutes: String = ""            // カテゴリがビギナー以外のときの所要時間（分）
    @State private var selectedPurposes: [String] = []
    
    // ステップ管理
    @State private var currentStep: Int = 0
    
    // 利用規約同意
    @State private var termsAgreed: Bool = false
    @State private var showTermsDetail: Bool = false
    
    // 保存状態
    @State private var isSaving: Bool = false
    @State private var saveErrorMessage: String?
    @State private var showSkipAlert: Bool = false
    
    private let genders = ["男性", "女性", "無回答"]
    private let runCategories = ["ビギナー", "5k", "10k", "ハーフ", "フル"]
    private let purposes = ["サブ3", "サブ3.5", "サブ4", "サブ5", "健康維持", "ダイエット", "完走", "自己ベスト更新", "その他"]
    // よく走るエリアの候補（予測用）
    private let areaSuggestions = ["皇居", "代々木公園", "駒沢公園", "多摩川", "大阪城公園", "中之島公園", "大濠公園", "名古屋城", "みなとみらい"]
    
    private var totalSteps: Int { 10 }
    private var progress: CGFloat {
        CGFloat(currentStep + 1) / CGFloat(totalSteps)
    }
    
    var body: some View {
        NavigationStack {
                    ZStack {
                        Color.white.ignoresSafeArea()
                        
                        VStack(spacing: 32) {
                            // プログレスバー
                            progressBar
                                .padding(.top, 24)
                                .padding(.horizontal, 20)
                            
                            Spacer()
                            
                            // 質問カード
                            ZStack {
                                stepView()
                                    .padding(.horizontal, 20)
                                    .transition(.asymmetric(insertion: .move(edge: .trailing),
                                                            removal: .move(edge: .leading)))
                            }
                            .animation(.easeInOut, value: currentStep)
                            
                            Spacer()
                            
                            if let message = saveErrorMessage {
                                Text(message)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 20)
                            }
                            
                            // アクションボタン
                            Button(action: {
                                handleNext()
                            }) {
                                Text(isSaving ? "保存中..." : (isLastStep ? "はじめる" : "次へ"))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isCurrentStepValid ? Color(hex: "0F1A2E") : Color.gray.opacity(0.4))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                            .disabled(!isCurrentStepValid || isSaving)
                        }
                    }
                    .navigationTitle("プロフィール登録")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        // キーボード用ツールバー
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("閉じる") {
                                hideKeyboard()
                            }
                        }
                        // ナビゲーション戻るボタン（ログイン画面へ戻る）
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                if currentStep == 0 {
                                    showSkipAlert = true
                                } else {
                                    withAnimation {
                                        if currentStep == 9, skipsTimeStep {
                                            currentStep = 7  // ビギナー選択時はカテゴリへ
                                        } else {
                                            currentStep = max(currentStep - 1, 0)
                                        }
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.left")
                            }
                        }
                    }
                    .onTapGesture {
                        hideKeyboard()
                    }
                    .alert("登録せずに利用しますか？", isPresented: $showSkipAlert) {
                        Button("キャンセル", role: .cancel) { }
                        Button("登録せずに利用する", role: .destructive) {
                            skipProfileRegistration = true
                            onComplete?()
                        }
                    } message: {
                        Text("プロフィールを登録せずにアプリを利用します。一部機能が制限される場合があります。")
                    }
        }
    }
    
    // MARK: - Subviews / Logic
    
    private var isLastStep: Bool {
        currentStep == totalSteps - 1
    }
    
    /// カテゴリでビギナーを選んだ場合はタイム入力ステップをスキップ
    private var skipsTimeStep: Bool {
        selectedRunCategory == "ビギナー"
    }
    
    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 0:
            return termsAgreed // 規約に同意しているかどうか
        case 1:
            return profileImage != nil // プロフィール写真が必須
        case 2:
            return !username.trimmingCharacters(in: .whitespaces).isEmpty
        case 3:
            return selectedGender != nil
        case 4:
            // 生年月日が18〜80歳の範囲かどうか
            let now = Date()
            let calendar = Calendar.current
            guard let minDate = calendar.date(byAdding: .year, value: -80, to: now),
                  let maxDate = calendar.date(byAdding: .year, value: -18, to: now) else {
                return true
            }
            return (minDate...maxDate).contains(birthDate)
        case 5:
            return !selectedPrefecture.isEmpty
        case 6:
            return !activityArea.trimmingCharacters(in: .whitespaces).isEmpty
        case 7:
            return selectedRunCategory != nil
        case 8:
            // ビギナー以外のときのみこのステップに来る。分で入力（数値・1以上）
            guard let minVal = Int(runMinutes.trimmingCharacters(in: .whitespaces)), minVal > 0 else { return false }
            return true
        case 9:
            return !selectedPurposes.isEmpty
        default:
            return false
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color(hex: "0F1A2E"))
                    .frame(width: geometry.size.width * progress, height: 6)
            }
        }
        .frame(height: 6)
    }
    
    @ViewBuilder
    private func stepView() -> some View {
        VStack(spacing: 24) {
            switch currentStep {
            case 0:
                // 規約同意画面
                termsOfServiceView
            case 1:
                questionTitle("プロフィール写真を選択してください")
                profilePhotoPicker
            case 2:
                questionTitle("お名前を教えてください")
                TextField("例）Hiro", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
            case 3:
                questionTitle("性別を教えてください")
                HStack(spacing: 12) {
                    ForEach(genders, id: \.self) { gender in
                        selectableChip(title: gender, isSelected: selectedGender == gender) {
                            selectedGender = gender
                        }
                    }
                }
            case 4:
                questionTitle("生年月日を教えてください")
                DatePicker(
                    "生年月日",
                    selection: $birthDate,
                    in: allowedBirthDateRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .frame(height: 150)
            case 5:
                questionTitle("お住まいの都道府県を教えてください")
                Picker("都道府県", selection: $selectedPrefecture) {
                    ForEach(allPrefectures, id: \.self) { prefecture in
                        Text(prefecture).tag(prefecture)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 180)
            case 6:
                questionTitle("よく走るエリアを教えてください")
                VStack(alignment: .leading, spacing: 16) {
                    TextField("例）皇居、代々木公園", text: $activityArea)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    // エリアの予測候補（チップ）: 横並びで自動折り返し
                    let columns = [
                        GridItem(.adaptive(minimum: 90), spacing: 10)
                    ]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(areaSuggestions, id: \.self) { spot in
                            selectableChip(title: spot, isSelected: activityArea.components(separatedBy: "、").contains(spot)) {
                                toggleActivityArea(spot: spot)
                            }
                        }
                    }
                }
            case 7:
                questionTitle("走るカテゴリを教えてください")
                VStack(alignment: .leading, spacing: 16) {
                    let columns = [
                        GridItem(.adaptive(minimum: 90), spacing: 12)
                    ]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(runCategories, id: \.self) { category in
                            selectableChip(title: category, isSelected: selectedRunCategory == category) {
                                selectedRunCategory = category
                            }
                        }
                    }
                }
            case 8:
                questionTitle("その距離を何分で走りますか？")
                VStack(alignment: .leading, spacing: 16) {
                    Text("目安のタイム（分）で入力してください")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    TextField("例）25", text: $runMinutes)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
            case 9:
                questionTitle("ランニングの目的を教えてください（複数選択可）")
                // 画面内で折り返す横並びレイアウト（グリッド）
                let columns = [
                    GridItem(.adaptive(minimum: 90), spacing: 12)
                ]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(purposes, id: \.self) { purpose in
                        let isSelected = selectedPurposes.contains(purpose)
                        selectableChip(title: purpose, isSelected: isSelected) {
                            togglePurpose(purpose)
                        }
                    }
                }
            default:
                EmptyView()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        )
    }
    
    private var profilePhotoPicker: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                if let profileImage = profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(hex: "0F1A2E"), lineWidth: 3))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(hex: "0F1A2E").opacity(0.3))
                        Text("タップして写真を選択")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(width: 200, height: 200)
                    .background(Circle().fill(Color.gray.opacity(0.1)))
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "0F1A2E").opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    )
                }
            }
        }
        .onChange(of: selectedPhoto) { oldValue, newValue in
            Task {
                if let newValue = newValue {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            self.profileImage = image
                        }
                    }
                }
            }
        }
    }
    
    private var termsOfServiceView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("TASUKI（タスキ）利用規約")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "0F1A2E"))
                
                // 規約内容を表示
                ScrollView {
                    Text(termsOfServiceText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 220)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
            
            // チェックボックスと同意テキスト
            HStack(spacing: 12) {
                Image(systemName: termsAgreed ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(termsAgreed ? Color(hex: "0F1A2E") : .gray)
                    .onTapGesture {
                        termsAgreed.toggle()
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("TASUKI利用規約に同意する")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "0F1A2E"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture {
                    termsAgreed.toggle()
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private var termsOfServiceText: String {
        """
        TASUKI（タスキ）利用規約

        この規約（以下「本規約」といいます）は、TASUKIプロジェクト（以下「当社」といいます）が提供するランニングアプリ「TASUKI」（以下「本サービス」といいます）の利用条件を定めるものです。利用者の皆様（以下「ユーザー」といいます）には、本規約に従って本サービスをご利用いただきます。

        第1条（規約への同意）
        ユーザーは、本規約に同意した上で、本サービスを利用するものとします。
        ユーザーが本アプリをダウンロードし、会員登録を完了した時点で、本規約を内容とする利用契約が成立したものとみなします。
        本サービスは、18歳以上（高校生を除く）の方を対象としており、18歳未満の方の利用を禁止します。

        第2条（定義）
        本規約において、次の用語は以下の意味を有します。
        「コンテンツ」：本サービスを通じて投稿、アップロードされたテキスト、画像、ランニングログ、音声等の一切の情報。
        「ランニングデータ」：GPSを利用して記録された走行距離、時間、ルート、ペース等のデータ。
        「TASUKIポイント」：アプリ内のイベントや走行によって付与される、サービス内専用のスコア。
        「襷（たすき）システム」：ユーザー間でパートナーを組み、継続を支援し合う本サービス独自の機能。

        第3条（利用資格および自己責任）
        本サービスは、18歳以上（高校生を除く）で、健康状態に問題がなく、激しい運動を行うことに支障がない方を対象としています。
        ユーザーは、自身の健康状態を適切に管理し、無理のない範囲でランニングを行うものとします。
        本サービスを利用したランニング中に発生した交通事故、怪我、体調悪化、その他のトラブルについて、当社は当社の過失による場合を除き、一切の責任を負いません。
        GPS機能の利用により、自宅付近などの位置情報が他者に推測される可能性があることを理解し、プライバシー設定をユーザー自身の責任で行うものとします。

        第4条（禁止事項）
        ユーザーは、本サービスの利用にあたり、以下の行為を行ってはなりません。
        法令、公序良俗、または本規約に違反する行為。
        18歳未満（高校生を含む）が会員登録または本サービスを利用する行為。
        自転者、自動車、その他交通機関を利用してランニングデータを偽装する行為。
        走行中、または交通の頻繁な場所でのスマートフォン操作、および周囲の安全を阻害する形での利用。
        本サービスを本来の目的（ランニングを通じた健康増進・交流）以外の目的（性的な出会い目的、宗教勧誘、営業活動等）で利用する行為。
        他のユーザーに対する誹謗中傷、ストーカー行為、ハラスメント行為。
        走行禁止エリアや私有地への無断立ち入り。
        反社会的勢力への利益供与。

        第5条（有料サービスおよび料金）
        本サービスは一部有料のサブスクリプションプラン（以下「有料プラン」といいます）を提供します。
        有料プランの料金、期間、特典の内容は、アプリ内の購入画面に準じます。
        有料プランは、ユーザーが自ら解約手続きを行わない限り、同一条件で自動更新されます。
        Apple IDやGoogle Play等の外部決済サービスを利用している場合、解約は各プラットフォームの定めに従ってユーザー自身が行う必要があります。

        第6条（返金規定）
        購入済みの有料プラン料金、およびポイントについては、原則として返金を行いません。

        第7条（利用制限および強制退会）
        当社は、ユーザーが本規約の禁止事項に違反した場合、事前の通知なくデータの削除、利用停止、または強制退会処分を行うことができます。

        第8条（免責事項）
        当社は、本サービスの内容の正確性、有用性、および特定の目的への適合性について保証しません。

        第9条（権利帰属）
        本サービスに関する知的財産権は、すべて当社または権利者に帰属します。

        第10条（規約の変更）
        当社は、必要と判断した場合、ユーザーへの事前告知を行うことで、いつでも本規約を変更できるものとします。

        第11条（準拠法および裁判管轄）
        本規約の解釈にあたっては、日本法を準拠法とします。
        本サービスに関して紛争が生じた場合には、東京地方裁判所を第一審の専属的合意管轄裁判所とします。
        """
    }
    
    private func questionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(Color(hex: "0F1A2E"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func selectableChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : Color(hex: "0F1A2E"))
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: "0F1A2E") : Color.gray.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
    
    /// 「よく走るエリア」の文字列に対して、候補スポットをトグル追加・削除する
    private func toggleActivityArea(spot: String) {
        var items = activityArea
            .split(separator: "、")
            .map { String($0) }
        
        if let index = items.firstIndex(of: spot) {
            // すでに含まれていれば削除
            items.remove(at: index)
        } else {
            // 含まれていなければ追加
            items.append(spot)
        }
        
        activityArea = items.joined(separator: "、")
    }
    
    /// ランニング目的の複数選択トグル
    private func togglePurpose(_ purpose: String) {
        if let index = selectedPurposes.firstIndex(of: purpose) {
            selectedPurposes.remove(at: index)
        } else {
            selectedPurposes.append(purpose)
        }
    }
    
    /// 登録タイムからランク（S,A,B,C,D）を算出
    private func computeRank(category: String?, minutes: Int?) -> String {
        guard let cat = category, cat != "ビギナー" else { return "Rank D" }
        guard let min = minutes, min > 0 else { return "Rank D" }
        switch cat {
        case "5k":
            if min < 16 { return "Rank S" }
            if min < 20 { return "Rank A" }
            if min < 24 { return "Rank B" }
            if min < 28 { return "Rank C" }
            return "Rank D"
        case "10k":
            if min < 32 { return "Rank S" }
            if min < 40 { return "Rank A" }
            if min < 50 { return "Rank B" }
            if min < 60 { return "Rank C" }
            return "Rank D"
        case "ハーフ":
            if min < 85 { return "Rank S" }
            if min < 100 { return "Rank A" }
            if min < 120 { return "Rank B" }
            if min < 150 { return "Rank C" }
            return "Rank D"
        case "フル":
            if min < 180 { return "Rank S" }
            if min < 210 { return "Rank A" }
            if min < 240 { return "Rank B" }
            if min < 300 { return "Rank C" }
            return "Rank D"
        default:
            return "Rank D"
        }
    }
    
    /// 分を "3:30:00" / "1:25:00" 形式のラベルに変換
    private func formatMinutesToTimeLabel(_ totalMinutes: Int) -> String {
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h > 0 {
            return String(format: "%d:%02d:00", h, m)
        }
        return String(format: "%d:00", m)
    }
    
    /// 生年月日の選択可能範囲（18〜80歳）
    private var allowedBirthDateRange: ClosedRange<Date> {
        let now = Date()
        let calendar = Calendar.current
        let maxDate = calendar.date(byAdding: .year, value: -18, to: now) ?? now
        let minDate = calendar.date(byAdding: .year, value: -80, to: now) ?? now
        return minDate...maxDate
    }

    // 生年月日を日本語表記で返す（例: 1998年1月1日）
    private var birthDateFormatted: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateFormat = "yyyy年MM月dd日"
        return df.string(from: birthDate)
    }
    
    private func handleNext() {
        guard isCurrentStepValid else { return }
        
        if isLastStep {
            saveProfile()
        } else {
            withAnimation {
                if currentStep == 7, skipsTimeStep {
                    currentStep = 9  // ビギナー選択時はタイム入力をスキップして目的へ
                } else {
                    currentStep = min(currentStep + 1, totalSteps - 1)
                }
            }
        }
    }
    
    private func saveProfile() {
        guard let profileImage = profileImage else {
            saveErrorMessage = "プロフィール写真を選択してください。"
            return
        }
        
        isSaving = true
        saveErrorMessage = nil
        
        Task {
            // 1. ログインユーザーを確保（いなければ匿名ログイン）
            let firebaseUser: FirebaseAuth.User
            if let current = Auth.auth().currentUser {
                firebaseUser = current
            } else {
                do {
                    let result = try await Auth.auth().signInAnonymously()
                    firebaseUser = result.user
                } catch {
                    await MainActor.run {
                        self.isSaving = false
                        self.saveErrorMessage = "ログイン情報の取得に失敗しました。時間をおいて再度お試しください。"
                    }
                    return
                }
            }
            
            // 2. 画像アップロードを最大15秒でタイムアウト（それ以上待たず登録を続行）
            var imageUrl: String? = nil
            await withTaskGroup(of: String?.self) { group in
                group.addTask {
                    try? await StorageManager.shared.uploadProfileImage(profileImage, uid: firebaseUser.uid)
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    return nil
                }
                let first = await group.next() ?? nil
                group.cancelAll()
                imageUrl = first ?? nil
            }
            
            // 3. プロフィール情報を保存（画像URLは取得できた場合のみ設定）
            let gender = selectedGender ?? "無回答"
            let purpose = selectedPurposes.isEmpty ? "その他" : selectedPurposes.joined(separator: ", ")
            
            // 生年月日から年齢を計算
            let calendar = Calendar.current
            let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
            let computedAge = ageComponents.year ?? 0
            
            let runMinutesInt = Int(runMinutes.trimmingCharacters(in: .whitespaces))
            let computedRank = computeRank(category: selectedRunCategory, minutes: runMinutesInt)
            
            // 登録タイムをフィルター用に保存（ベストフル/ハーフ）
            UserDefaults.standard.set(computedRank, forKey: "myRank")
            if selectedRunCategory == "フル", let min = runMinutesInt {
                UserDefaults.standard.set(formatMinutesToTimeLabel(min), forKey: "myBestFull")
            }
            if selectedRunCategory == "ハーフ", let min = runMinutesInt {
                UserDefaults.standard.set(formatMinutesToTimeLabel(min), forKey: "myBestHalf")
            }
            
            let user = User(
                id: UUID(),
                name: username,
                profileImage: "runner",
                profileImageUrl: imageUrl,
                bio: "",
                rank: computedRank,
                age: computedAge,
                gender: gender,
                purpose: purpose,
                prefecture: selectedPrefecture,
                area: activityArea,
                pace: "",
                runningFrequency: "",
                personalBest: "",
                schedule: "",
                nextRace: "",
                targetTime: "",
                monthlyDistance: 0,
                monthlyTarget: 0,
                avgPace: "",
                matchRate: 0,
                lastLogin: Date(),
                spotName: activityArea,
                latitude: 0,
                longitude: 0,
                distanceFromUserMock: 0
            )
            
            await MainActor.run {
                userManager.saveUserProfile(user: user) { result in
                    DispatchQueue.main.async {
                        self.isSaving = false
                        switch result {
                        case .success:
                            self.onComplete?()
                        case .failure(let error):
                            self.saveErrorMessage = "保存に失敗しました。時間をおいて再度お試しください。（\(error.localizedDescription)）"
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Keyboard Dismiss Helper
private extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

#Preview {
    ProfileRegistrationView()
        .environmentObject(AuthManager())
        .environmentObject(UserManager())
}


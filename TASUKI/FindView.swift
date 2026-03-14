//
//  FindView.swift
//  TASUKI
//
//  Created by yoshi H on 2026/01/28.
//

import SwiftUI
import FirebaseAuth

// MARK: - Sort Option
enum SortOption: String, CaseIterable {
    case recommend = "おすすめ順"
    case login = "ログイン順"
    case distance = "距離が近い順"
}

// MARK: - Rank Order (S=0 が最上)
private func rankOrderIndex(_ rankLabel: String) -> Int {
    let r = rankLabel.replacingOccurrences(of: "Rank ", with: "").uppercased()
    switch r {
    case "S": return 0
    case "A": return 1
    case "B": return 2
    case "C": return 3
    case "D": return 4
    default: return 5
    }
}

struct FindView: View {
    @State private var selectedMode: String = "Runners"  // "Runners" or "Practices"
    @State private var searchText: String = ""
    @State private var showRecruitmentSheet = false
    @State private var showFilterSheet = false  // 詳細フィルターシートの表示状態
    
    // ソート機能
    @State private var sortOption: SortOption = .recommend
    
    // フィルター用のState
    @State private var selectedRunnerFilter: String = "すべて"
    @State private var selectedPracticeFilter: String = "すべて" // 旧ロジック互換用（UI表示のみ）
    @State private var selectedPracticeCategory: PracticeCategory? = nil
    
    // 詳細フィルター用のState
    @State private var filterPrefecture: String = "指定なし"
    @State private var filterAgeGroup: String = "指定なし"
    @State private var filterAgeMin: Int = 20
    @State private var filterAgeMax: Int = 80
    @State private var filterRankMode: String = "すべて"  // すべて / 自分より上のみ / 自分と同じ以上 / 自分より下のみ
    @State private var filterActiveTime: String = "指定なし"
    @State private var filterRunningGoal: String = "指定なし"
    @State private var filterPersonalBest: String = "指定なし"
    @State private var filterBestFull: String = "指定なし"
    @State private var filterBestHalf: String = "指定なし"
    @State private var filterEasyPace: String = "5:30/km"  // サンプル初期値
    @State private var filterRunSpot: String = ""
    
    // 登録時の値（フィルター初期値・表示用）
    @AppStorage("myRank") private var myRank: String = "Rank B"
    @AppStorage("myBestFull") private var myBestFull: String = ""
    @AppStorage("myBestHalf") private var myBestHalf: String = ""
    @AppStorage("myAvgPace") private var myAvgPace: String = "5:30/km"
    
    // Practices用 詳細フィルター
    @State private var practiceFilterDay: String = "指定なし"
    @State private var practiceFilterSpot: String = ""
    @State private var practiceFilterCapacity: String = "指定なし"
    @State private var practiceFilterStartTime: String = "指定なし"
    
    // Runnersモード用のフィルター項目
    private let runnerFilters = ["すべて", "Rank S", "Rank A", "Rank B", "Rank C", "エリア未設定"]
    
    // Practicesモード用のフィルター項目（カテゴリー）
    private let practiceFilters: [PracticeCategory] = PracticeCategory.allCases
    
    // ダミーデータ（PartnerViewと同じ）
    @State private var partnerMockUsers: [PartnerUser] = [
        PartnerUser(
            name: "Kenji_Run",
            rank: "S",
            avatarImage: "person.circle.fill",
            isOnline: true,
            bestCategory: .half,
            bestTime: "1:25:00",
            age: 28,
            runningSchedule: .weekendMorning,
            purpose: "サブ3目標",
            nextRace: "東京マラソン2025",
            targetTime: "フル 2:55:00",
            runningSpots: ["皇居", "代々木公園", "多摩川"],
            prefecture: "Tokyo",
            gender: .male,
            condition: .excellent,
            statusMessage: "調子が良い！今月は200km走る目標です🔥",
            ageGroup: "20s",
            runningGoal: "Sub3",
            personalBest: "2:58:00",
            activeTime: "Morning",
            easyPace: "4:30/km",
            connectionStyle: .real
        ),
        PartnerUser(
            name: "さっちゃん",
            rank: "A",
            avatarImage: "person.circle.fill",
            isOnline: true,
            bestCategory: .full,
            bestTime: "3:15:00",
            age: 32,
            runningSchedule: .weekdayEvening,
            purpose: "サブ3目標",
            nextRace: "横浜マラソン2025",
            targetTime: "フル 2:58:00",
            runningSpots: ["お台場", "多摩川", "駒沢公園"],
            prefecture: "Kanagawa",
            gender: .female,
            condition: .good,
            statusMessage: "今月も頑張ります！週3回のペースで走ってます",
            ageGroup: "30s",
            runningGoal: "Sub3",
            personalBest: "3:15:00",
            activeTime: "Night",
            easyPace: "5:00/km",
            connectionStyle: .real
        ),
        PartnerUser(
            name: "Taka@Sub3",
            rank: "B",
            avatarImage: "person.circle.fill",
            isOnline: false,
            bestCategory: .tenKm,
            bestTime: "35:00",
            age: 25,
            runningSchedule: .weekendMorning,
            purpose: "健康維持",
            nextRace: "東京10kmロードレース",
            targetTime: "10km 33:00",
            runningSpots: ["皇居", "代々木公園"],
            prefecture: "Tokyo",
            gender: .male,
            condition: .good,
            statusMessage: "週末の朝ランが楽しみです！",
            ageGroup: "20s",
            runningGoal: "健康維持",
            personalBest: nil,
            activeTime: "Morning",
            easyPace: "5:30/km",
            connectionStyle: .both
        ),
        PartnerUser(
            name: "Momo",
            rank: "C",
            avatarImage: "person.circle.fill",
            isOnline: true,
            bestCategory: .half,
            bestTime: "1:35:00",
            age: 29,
            runningSchedule: .flexible,
            purpose: "ダイエット",
            nextRace: nil,
            targetTime: nil,
            runningSpots: ["大阪城公園", "中之島公園"],
            prefecture: "Osaka",
            gender: .female,
            condition: .tired,
            statusMessage: "最近忙しくて疲れ気味...でも走りたい！",
            ageGroup: "20s",
            runningGoal: "ダイエット",
            personalBest: nil,
            activeTime: "Holiday",
            easyPace: "6:00/km",
            connectionStyle: .virtual
        ),
        PartnerUser(
            name: "Runner123",
            rank: "D",
            avatarImage: "person.circle.fill",
            isOnline: false,
            bestCategory: .tenKm,
            bestTime: "42:00",
            age: 24,
            runningSchedule: .weekdayEvening,
            purpose: "ダイエット",
            nextRace: nil,
            targetTime: nil,
            runningSpots: ["代々木公園"],
            prefecture: "Tokyo",
            gender: .female,
            condition: .sos,
            statusMessage: "足を痛めてしまいました...しばらく休みます💦",
            ageGroup: "20s",
            runningGoal: "ダイエット",
            personalBest: nil,
            activeTime: "Night",
            easyPace: "6:30/km",
            connectionStyle: .both
        ),
        PartnerUser(
            name: "マラソン太郎",
            rank: "S",
            avatarImage: "person.circle.fill",
            isOnline: true,
            bestCategory: .full,
            bestTime: "2:45:00",
            age: 35,
            runningSchedule: .weekdayMorning,
            purpose: "自己ベスト更新",
            nextRace: "大阪マラソン2025",
            targetTime: "フル 2:40:00",
            runningSpots: ["大阪城公園", "中之島公園"],
            prefecture: "Osaka",
            gender: .male,
            condition: .excellent,
            statusMessage: "朝ランで気持ちいい！PB更新に向けて頑張ります",
            ageGroup: "30s",
            runningGoal: "Sub3",
            personalBest: "2:45:00",
            activeTime: "Morning",
            easyPace: "4:00/km",
            connectionStyle: .real
        ),
        PartnerUser(
            name: "みか",
            rank: "A",
            avatarImage: "person.circle.fill",
            isOnline: false,
            bestCategory: .half,
            bestTime: "1:30:00",
            age: 27,
            runningSchedule: .weekendMorning,
            purpose: "ファンラン",
            nextRace: "名古屋ウィメンズマラソン2025",
            targetTime: "ハーフ 1:25:00",
            runningSpots: ["名古屋城", "名城公園"],
            prefecture: "Aichi",
            gender: .female,
            condition: .good,
            statusMessage: "週末のランニングが楽しみ！一緒に走りましょう",
            ageGroup: "20s",
            runningGoal: "完走",
            personalBest: "3:45:00",
            activeTime: "Morning",
            easyPace: "5:15/km",
            connectionStyle: .both
        ),
        PartnerUser(
            name: "Hiro_Runner",
            rank: "B",
            avatarImage: "person.circle.fill",
            isOnline: true,
            bestCategory: .tenKm,
            bestTime: "38:00",
            age: 42,
            runningSchedule: .weekdayEvening,
            purpose: "健康維持",
            nextRace: "福岡マラソン2025",
            targetTime: "10km 36:00",
            runningSpots: ["大濠公園", "福岡タワー"],
            prefecture: "Fukuoka",
            gender: .male,
            condition: .good,
            statusMessage: "仕事終わりのランでリフレッシュ！",
            ageGroup: "40s",
            runningGoal: "健康維持",
            personalBest: "3:30:00",
            activeTime: "Night",
            easyPace: "5:45/km",
            connectionStyle: .virtual
        ),
        PartnerUser(
            name: "あきこ",
            rank: "C",
            avatarImage: "person.circle.fill",
            isOnline: true,
            bestCategory: .half,
            bestTime: "1:40:00",
            age: 38,
            runningSchedule: .weekendAfternoon,
            purpose: "ダイエット",
            nextRace: nil,
            targetTime: nil,
            runningSpots: ["大通公園", "円山公園"],
            prefecture: "Hokkaido",
            gender: .female,
            condition: .tired,
            statusMessage: "最近体重が落ちてきて嬉しい！でも少し疲れ気味...",
            ageGroup: "30s",
            runningGoal: "ダイエット",
            personalBest: nil,
            activeTime: "Holiday",
            easyPace: "6:15/km",
            connectionStyle: .virtual
        ),
        PartnerUser(
            name: "RunTaka",
            rank: "D",
            avatarImage: "person.circle.fill",
            isOnline: false,
            bestCategory: .fiveKm,
            bestTime: "22:00",
            age: 22,
            runningSchedule: .flexible,
            purpose: "ファンラン",
            nextRace: nil,
            targetTime: nil,
            runningSpots: ["皇居", "新宿御苑"],
            prefecture: "Tokyo",
            gender: .male,
            condition: .good,
            statusMessage: "ランニング始めたばかり！一緒に楽しみましょう",
            ageGroup: "20s",
            runningGoal: "完走",
            personalBest: nil,
            activeTime: "Holiday",
            easyPace: "6:45/km",
            connectionStyle: .both
        )
    ]
    
    @State private var recruitments: [PracticeRecruitment] = mockRecruitments
    
    // User型のマッチング用データ（Models.swiftのmockUsersを使用）
    @State private var matchingUsers: [User] = []
    
    // フィルタリング＆ソートされたユーザーリスト
    private var filteredUsers: [User] {
        var filtered = matchingUsers
        
        // 検索テキストフィルター
        if !searchText.isEmpty {
            filtered = filtered.filter { user in
                let q = searchText
                // ユーザーのID（UUID文字列）
                let idString = user.id.uuidString
                return
                    idString.localizedCaseInsensitiveContains(q) ||          // 固有ID
                    user.name.localizedCaseInsensitiveContains(q) ||         // ニックネーム
                    user.spotName.localizedCaseInsensitiveContains(q) ||     // よく走るエリア（表示用スポット）
                    user.area.localizedCaseInsensitiveContains(q) ||         // 活動エリア
                    user.prefecture.localizedCaseInsensitiveContains(q) ||   // 都道府県
                    user.purpose.localizedCaseInsensitiveContains(q) ||      // ランニングの目的
                    user.schedule.localizedCaseInsensitiveContains(q) ||     // よく走る日時
                    user.runningFrequency.localizedCaseInsensitiveContains(q) || // 頻度
                    user.personalBest.localizedCaseInsensitiveContains(q) || // 自己ベスト
                    user.nextRace.localizedCaseInsensitiveContains(q) ||     // 次のレース
                    user.targetTime.localizedCaseInsensitiveContains(q) ||   // 目標タイム
                    user.avgPace.localizedCaseInsensitiveContains(q) ||      // 平均ペース
                    user.bio.localizedCaseInsensitiveContains(q)             // 自己紹介・タグ的テキスト
            }
        }
        
        // ソート機能（おすすめ＝matchRate 高い順）
        switch sortOption {
        case .recommend:
            filtered = filtered.sorted { $0.matchRate > $1.matchRate }
        case .login:
            filtered = filtered.sorted { $0.lastLogin > $1.lastLogin }
        case .distance:
            filtered = filtered.sorted { $0.distanceFromUserMock < $1.distanceFromUserMock }
        }
        
        return filtered
    }
    
    // 既存のPartnerUser用のフィルタリング（Practicesモード用に保持）
    private var filteredPartnerUsers: [PartnerUser] {
        var filtered = partnerMockUsers
        
        // ランクフィルター
        if selectedRunnerFilter != "すべて" {
            if selectedRunnerFilter == "エリア未設定" {
                // エリア未設定の場合は、runningSpotsが空のユーザーを表示
                filtered = filtered.filter { $0.runningSpots.isEmpty }
            } else {
                let rank = selectedRunnerFilter.replacingOccurrences(of: "Rank ", with: "")
                filtered = filtered.filter { $0.rank == rank }
            }
        }
        
        // 詳細フィルター適用
        if filterPrefecture != "指定なし" {
            filtered = filtered.filter { $0.prefecture.contains(filterPrefecture) }
        }
        
        // ランク階層フィルター（自分より上/同じ以上/下のみ）
        if filterRankMode != "すべて" {
            let myRankIndex = rankOrderIndex(myRank)
            filtered = filtered.filter { user in
                let userIndex = rankOrderIndex("Rank \(user.rank)")
                switch filterRankMode {
                case "自分より上のみ": return userIndex < myRankIndex
                case "自分と同じ以上": return userIndex <= myRankIndex
                case "自分より下のみ": return userIndex > myRankIndex
                default: return true
                }
            }
        }
        
        // 年齢範囲フィルター（20〜80）
        filtered = filtered.filter { filterAgeMin <= $0.age && $0.age <= filterAgeMax }
        
        if filterAgeGroup != "指定なし" {
            filtered = filtered.filter { $0.ageGroup == filterAgeGroup }
        }
        
        if filterActiveTime != "指定なし" {
            let scheduleMap: [String: String] = [
                "平日 朝": "Morning",
                "平日 夜": "Night",
                "土日 朝": "Morning",
                "土日 午前": "Morning",
                "土日 午後": "Holiday",
                "土日 夜": "Night",
                "不定期": "Holiday"
            ]
            if let mappedTime = scheduleMap[filterActiveTime] {
                filtered = filtered.filter { $0.activeTime == mappedTime }
            }
        }
        
        if filterRunningGoal != "指定なし" {
            filtered = filtered.filter { $0.runningGoal.contains(filterRunningGoal) }
        }
        
        if filterPersonalBest != "指定なし" {
            // ベストタイムの範囲でフィルタリング
            filtered = filtered.filter { user in
                guard let pb = user.personalBest else {
                    return filterPersonalBest == "未計測"
                }
                if filterPersonalBest == "未計測" {
                    return false
                }
                // ベストタイムの文字列に目標タイムが含まれるかチェック
                // 例: "サブ3" なら "2:" で始まるタイムを検索
                let bestTimeMap: [String: String] = [
                    "サブ2.5": "2:",
                    "サブ3": "2:",
                    "サブ3.5": "3:",
                    "サブ4": "3:",
                    "サブ5": "4:",
                    "完走": ""
                ]
                if let prefix = bestTimeMap[filterPersonalBest] {
                    if prefix.isEmpty {
                        return true  // 完走はすべて
                    }
                    return pb.hasPrefix(prefix)
                }
                return true
            }
        }
        
        if filterEasyPace != "指定なし" {
            // ペースのフィルタリング（30秒刻み）
            filtered = filtered.filter { user in
                let pace = user.easyPace
                // 選択されたペースと一致するかチェック
                // 例: "4:00/km" なら "4:00" を含む
                if filterEasyPace == "4:00/km未満" {
                    // 4:00未満の処理（簡易版）
                    return pace.contains("3:") || pace.contains("2:") || pace.contains("1:")
                } else if filterEasyPace == "7:00/km〜" {
                    // 7:00以上の処理
                    return pace.contains("7:") || pace.contains("8:") || pace.contains("9:")
                } else {
                    // その他のペース（3:00, 3:30, 4:00など）
                    return pace.contains(filterEasyPace.replacingOccurrences(of: "/km", with: ""))
                }
            }
        }
        
        if filterBestFull != "指定なし" {
            filtered = filtered.filter { user in
                user.bestCategory == .full || (user.personalBest != nil && (user.personalBest ?? "").contains(":"))
            }
        }
        if filterBestHalf != "指定なし" {
            filtered = filtered.filter { user in
                user.bestCategory == .half || (user.personalBest != nil && (user.personalBest ?? "").contains("1:"))
            }
        }
        
        if !filterRunSpot.isEmpty {
            filtered = filtered.filter { user in
                user.runningSpots.contains { $0.contains(filterRunSpot) }
            }
        }
        
        // 検索テキストフィルター
        if !searchText.isEmpty {
            filtered = filtered.filter { user in
                user.name.localizedCaseInsensitiveContains(searchText) ||
                user.statusMessage.localizedCaseInsensitiveContains(searchText) ||
                user.prefecture.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    // フィルタリングされた募集リスト
    private var filteredRecruitments: [PracticeRecruitment] {
        var filtered = recruitments
        
        // カテゴリーフィルター適用
        if let category = selectedPracticeCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // 詳細フィルター（Practices用）
        if practiceFilterDay != "指定なし" {
            filtered = filtered.filter { recruitment in
                switch practiceFilterDay {
                case "平日":
                    return ["月", "火", "水", "木", "金"].contains(recruitment.dayOfWeek)
                case "土日":
                    return ["土", "日"].contains(recruitment.dayOfWeek)
                default:
                    return recruitment.dayOfWeek == practiceFilterDay
                }
            }
        }
        
        if !practiceFilterSpot.isEmpty {
            filtered = filtered.filter { $0.location.localizedCaseInsensitiveContains(practiceFilterSpot) }
        }
        
        if practiceFilterCapacity != "指定なし" {
            filtered = filtered.filter { recruitment in
                switch practiceFilterCapacity {
                case "〜5名":
                    return recruitment.maxParticipants <= 5
                case "〜10名":
                    return recruitment.maxParticipants <= 10
                case "11名〜":
                    return recruitment.maxParticipants >= 11
                default:
                    return true
                }
            }
        }
        
        if practiceFilterStartTime != "指定なし" {
            let calendar = Calendar.current
            filtered = filtered.filter { recruitment in
                let hour = calendar.component(.hour, from: recruitment.date)
                switch practiceFilterStartTime {
                case "朝 (〜9:00)":
                    return hour < 9
                case "昼 (9〜17時)":
                    return (9..<17).contains(hour)
                case "夜 (17時〜)":
                    return hour >= 17
                default:
                    return true
                }
            }
        }
        
        // 検索テキストフィルター
        if !searchText.isEmpty {
            filtered = filtered.filter { recruitment in
                recruitment.title.localizedCaseInsensitiveContains(searchText) ||
                recruitment.location.localizedCaseInsensitiveContains(searchText) ||
                recruitment.description.localizedCaseInsensitiveContains(searchText) ||
                recruitment.host.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色: White
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    // 1. メインモード切り替え
                    Picker("Mode", selection: $selectedMode) {
                        Text("Runners").tag("Runners")
                        Text("Practices").tag("Practices")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // 2. 検索バーエリア
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color(hex: "0F1A2E").opacity(0.5))
                                .padding(.leading, 12)
                            
                            TextField("検索...", text: $searchText)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "0F1A2E"))
                                .padding(.vertical, 12)
                                .padding(.trailing, 12)
                                .onTapGesture {
                                    // 検索窓タップで詳細フィルターを開く（Runners / Practices 共通）
                                    showFilterSheet = true
                                }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "F5F7FA"))
                        )
                        
                        // 詳細フィルターボタン（アイコンからも開ける）
                        Button(action: {
                            showFilterSheet = true
                        }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "0F1A2E"))
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // 4. クイックフィルター（横スクロール）
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            if selectedMode == "Runners" {
                                ForEach(runnerFilters, id: \.self) { filter in
                                    filterButton(
                                        title: filter,
                                        isSelected: selectedRunnerFilter == filter,
                                        action: {
                                            selectedRunnerFilter = filter
                                        }
                                    )
                                }
                            } else {
                                // Practices: カテゴリフィルタ
                                filterButton(
                                    title: "すべて",
                                    isSelected: selectedPracticeCategory == nil,
                                    action: {
                                        selectedPracticeCategory = nil
                                        selectedPracticeFilter = "すべて"
                                    }
                                )
                                
                                ForEach(practiceFilters, id: \.self) { category in
                                    filterButton(
                                        title: category.rawValue,
                                        isSelected: selectedPracticeCategory == category,
                                        action: {
                                            selectedPracticeCategory = category
                                            selectedPracticeFilter = category.rawValue
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // 5. リスト表示エリア
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if selectedMode == "Runners" {
                                // Runnersモード: 自分のプロフィールに近い同性のユーザー（サンプル）をおすすめ順で表示
                                ForEach(filteredUsers) { user in
                                    NavigationLink(destination: UserProfileDetailView(user: user)) {
                                        runnerCardView(user: user)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                // Practicesモード: 募集リスト（掲示板 + 詳細画面への遷移）
                                ForEach(filteredRecruitments) { recruitment in
                                    VStack(spacing: 8) {
                                        NavigationLink(
                                            destination: PracticeDetailView(practice: recruitment.toPractice())
                                        ) {
                                            practiceCardView(recruitment: recruitment)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Divider()
                                            .background(Color(hex: "E5E7EB"))
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)  // フローティングボタンのスペース
                    }
                }
            }
            .navigationTitle("Find")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedMode == "Runners" {
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: {
                                    sortOption = option
                                }) {
                                    HStack {
                                        Text(option.rawValue)
                                        if sortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(Color(hex: "0F1A2E"))
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterDetailSheet(
                    selectedMode: selectedMode,
                    prefecture: $filterPrefecture,
                    ageGroup: $filterAgeGroup,
                    ageMin: $filterAgeMin,
                    ageMax: $filterAgeMax,
                    rankMode: $filterRankMode,
                    activeTime: $filterActiveTime,
                    runningGoal: $filterRunningGoal,
                    personalBest: $filterPersonalBest,
                    bestFull: $filterBestFull,
                    bestHalf: $filterBestHalf,
                    easyPace: $filterEasyPace,
                    runSpot: $filterRunSpot,
                    myRank: myRank,
                    myBestFull: myBestFull,
                    myBestHalf: myBestHalf,
                    myJogPace: myAvgPace.isEmpty ? "5:30/km" : myAvgPace,
                    practiceCategory: $selectedPracticeCategory,
                    practiceDay: $practiceFilterDay,
                    practiceSpot: $practiceFilterSpot,
                    practiceCapacity: $practiceFilterCapacity,
                    practiceStartTime: $practiceFilterStartTime,
                    onApply: {
                        showFilterSheet = false
                    },
                    onClear: {
                        filterPrefecture = "指定なし"
                        filterAgeGroup = "指定なし"
                        filterAgeMin = 20
                        filterAgeMax = 80
                        filterRankMode = "すべて"
                        filterActiveTime = "指定なし"
                        filterRunningGoal = "指定なし"
                        filterPersonalBest = "指定なし"
                        filterBestFull = "指定なし"
                        filterBestHalf = "指定なし"
                        filterEasyPace = "5:30/km"
                        filterRunSpot = ""
                        selectedPracticeCategory = nil
                        practiceFilterDay = "指定なし"
                        practiceFilterSpot = ""
                        practiceFilterCapacity = "指定なし"
                        practiceFilterStartTime = "指定なし"
                    }
                )
            }
            .onAppear {
                // User型のマッチング用データを初期化（Models.swiftのmockUsersを使用）
                if matchingUsers.isEmpty {
                    // Models.swiftで定義されたmockUsersを参照（型を明示して確実に参照）
                    // ローカルのpartnerMockUsersは[PartnerUser]型なので、[User]型のmockUsersはModels.swiftのものを参照
                    matchingUsers = mockUsers as [User]
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // 新規募集ボタン（Practicesモードの時だけ表示）
                if selectedMode == "Practices" {
                    Button(action: {
                        showRecruitmentSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 56, weight: .regular))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color(hex: "2E5CFF"))
                                    .frame(width: 56, height: 56)
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .sheet(isPresented: $showRecruitmentSheet) {
                RecruitmentPostSheet(
                    onPost: { title, date, pace, location, description in
                        let practiceId = UUID().uuidString
                        let myUser = PartnerUser(
                            name: "Hiro",
                            rank: "A",
                            avatarImage: "person.circle.fill",
                            isOnline: true,
                            bestCategory: .full,
                            bestTime: "3:10:00",
                            age: 29,
                            runningSchedule: .weekdayEvening,
                            purpose: "サブ3目標",
                            nextRace: nil,
                            targetTime: nil,
                            runningSpots: [],
                            prefecture: "Tokyo",
                            gender: .male,
                            condition: .good,
                            statusMessage: "今月も頑張ります！",
                            ageGroup: "20s",
                            runningGoal: "Sub3",
                            personalBest: "3:10:00",
                            activeTime: "Night",
                            easyPace: "5:00/km",
                            connectionStyle: .both
                        )
                        guard let hostUid = Auth.auth().currentUser?.uid else {
                            let newRecruitment = PracticeRecruitment(
                                practiceId: practiceId,
                                chatId: nil,
                                host: myUser,
                                title: title,
                                location: location,
                                date: date,
                                category: .other,
                                pace: pace,
                                distance: "",
                                description: description,
                                applicants: [],
                                participantUserIds: [],
                                maxParticipants: 10
                            )
                            recruitments.insert(newRecruitment, at: 0)
                            showRecruitmentSheet = false
                            return
                        }
                        ConversationManager.shared.createPracticeConversation(practiceId: practiceId, hostUserId: hostUid, practiceTitle: title) { result in
                            DispatchQueue.main.async {
                                let chatId: String? = (try? result.get())
                                let newRecruitment = PracticeRecruitment(
                                    practiceId: practiceId,
                                    chatId: chatId,
                                    host: myUser,
                                    title: title,
                                    location: location,
                                    date: date,
                                    category: .other,
                                    pace: pace,
                                    distance: "",
                                    description: description,
                                    applicants: [],
                                    participantUserIds: [hostUid],
                                    maxParticipants: 10
                                )
                                recruitments.insert(newRecruitment, at: 0)
                                showRecruitmentSheet = false
                            }
                        }
                    },
                    onCancel: {
                        showRecruitmentSheet = false
                    }
                )
            }
        }
    }
    
    // MARK: - Runner Card View
    // MARK: - Runner Card View (User型用)
    private func runnerCardView(user: User) -> some View {
        HStack(spacing: 15) {
            // 丸型プロフィール画像（名前の左側に配置）
            if UIImage(named: user.profileImage) != nil {
                Image(user.profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            } else {
                // プレースホルダー
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.2))
                    .frame(width: 60, height: 60)
            }
            
            // 情報詳細
            VStack(alignment: .leading, spacing: 6) {
                // 名前 + オンラインステータス
                HStack(spacing: 6) {
                    Text(user.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "0F1A2E"))
                    
                    if user.isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
                
                // マッチ度表示
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("マッチ度：\(user.matchRate)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color(hex: "0F1A2E"))
                
                // ログイン状況
                let hoursSinceLogin = Int(Date().timeIntervalSince(user.lastLogin) / 3600)
                let daysSinceLogin = Int(Date().timeIntervalSince(user.lastLogin) / 86400)
                Text(user.isOnline ? "オンライン" : (daysSinceLogin > 0 ? "最終ログイン: \(daysSinceLogin)日前" : "最終ログイン: \(hoursSinceLogin)時間前"))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // 活動場所と距離
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
                    Text(user.spotName)
                    Text("(\(String(format: "%.1f", user.distanceFromUserMock))km)")
                        .foregroundColor(.gray)
                }
                .font(.caption)
                
                // ペース
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.caption)
                        .foregroundColor(Color(hex: "0F1A2E"))
                    Text(user.pace)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "0F1A2E"))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Partner User Card View (既存のPartnerUser用、互換性のため保持)
    private func partnerUserCardView(user: PartnerUser) -> some View {
        HStack(spacing: 16) {
            // アバター画像
            if let avatarImage = user.avatarImage {
                Image(systemName: avatarImage)
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "0F1A2E"))
                    .saturation(0)
                    .frame(width: 56, height: 56)
            } else {
                Circle()
                    .fill(Color(hex: "F5F7FA"))
                    .frame(width: 56, height: 56)
            }
            
            // ユーザー情報
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(user.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "0F1A2E"))
                    
                    Text("Rank \(user.rank)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
                }
                
                Text(user.statusMessage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // ステータスインジケーター
            Circle()
                .fill(user.isOnline ? Color(hex: "2E5CFF") : Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Practice Card View
    private func practiceCardView(recruitment: PracticeRecruitment) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // カテゴリバッジ + タイトル
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(recruitment.category.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(hex: recruitment.category.colorHex))
                    )
                
                Text(recruitment.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "0F1A2E"))
                    .lineLimit(2)
            }
            
            // 場所・曜日・時間・定員
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(recruitment.location)
                    Text("•")
                    Text(recruitment.dayOfWeek)
                    Text("•")
                    Text("\(recruitment.startTimeString)〜")
                    Text("•")
                    Text("定員\(recruitment.maxParticipants)名")
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
                
                // ペース・距離
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                        Text(recruitment.pace)
                    }
                    if !recruitment.distance.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.run")
                            Text(recruitment.distance)
                        }
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "2E5CFF"))
            }
            
            // 区切り
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .background(Color(hex: "F5F7FA"))
            }
            
            // 詳細
            Text(recruitment.description)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(hex: "0F1A2E").opacity(0.8))
                .lineLimit(3)
            
            // 募集主
            HStack(spacing: 8) {
                if let avatarImage = recruitment.host.avatarImage {
                    Image(systemName: avatarImage)
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "0F1A2E"))
                        .saturation(0)
                        .frame(width: 24, height: 24)
                }
                
                Text("募集主: \(recruitment.host.name)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "0F1A2E").opacity(0.7))
                
                Spacer()
                
                Text("\(recruitment.applicants.count)人が参加希望")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "2E5CFF"))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "F9FAFB"))
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        )
    }
    
    // MARK: - Filter Button
    private func filterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : Color(hex: "0F1A2E"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: "0F1A2E") : Color.clear)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.clear : Color(hex: "0F1A2E").opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
    
    // MARK: - Date Formatter
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E) HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Recruitment Post Sheet
struct RecruitmentPostSheet: View {
    let onPost: (String, Date, String, String, String) -> Void
    let onCancel: () -> Void
    
    @State private var title: String = ""
    @State private var selectedDate: Date = Date().addingTimeInterval(86400)
    @State private var pace: String = ""
    @State private var location: String = ""
    @State private var description: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // タイトル
                        VStack(alignment: .leading, spacing: 12) {
                            Text("タイトル")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "0F1A2E"))
                            
                            TextField("例: 来週皇居で20km走！", text: $title)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "0F1A2E"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "F5F7FA"))
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // 日時
                        VStack(alignment: .leading, spacing: 12) {
                            Text("開催日時")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "0F1A2E"))
                            
                            DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "F5F7FA"))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // ペース
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ペース")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "0F1A2E"))
                            
                            TextField("例: 4:30/km, LSD", text: $pace)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "0F1A2E"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "F5F7FA"))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // 場所
                        VStack(alignment: .leading, spacing: 12) {
                            Text("場所")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "0F1A2E"))
                            
                            TextField("例: 代々木公園", text: $location)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "0F1A2E"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "F5F7FA"))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // 詳細
                        VStack(alignment: .leading, spacing: 12) {
                            Text("詳細")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "0F1A2E"))
                            
                            TextEditor(text: $description)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "0F1A2E"))
                                .frame(height: 150)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "F5F7FA"))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .environment(\.locale, Locale(identifier: "ja_JP"))
            .navigationTitle("募集を作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        onCancel()
                    }
                    .foregroundColor(Color(hex: "0F1A2E"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("投稿") {
                        if !title.isEmpty && !pace.isEmpty && !location.isEmpty {
                            onPost(title, selectedDate, pace, location, description)
                        }
                    }
                    .foregroundColor(isValid ? Color(hex: "2E5CFF") : Color.gray)
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !title.isEmpty && !pace.isEmpty && !location.isEmpty
    }
}

// MARK: - Age Range Slider（1本のバーで最小・最大を指定）
private struct AgeRangeSlider: View {
    @Binding var ageMin: Int
    @Binding var ageMax: Int
    let range: ClosedRange<Int>
    
    private let trackHeight: CGFloat = 8
    private let thumbSize: CGFloat = 24
    
    private var rangeSpan: Int { range.upperBound - range.lowerBound }
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let minFraction = CGFloat(ageMin - range.lowerBound) / CGFloat(rangeSpan)
            let maxFraction = CGFloat(ageMax - range.lowerBound) / CGFloat(rangeSpan)
            let minX = minFraction * w
            let maxX = maxFraction * w
            
            ZStack(alignment: .leading) {
                // 背景バー
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: trackHeight)
                
                // 選択範囲（青い部分）
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color(hex: "2E5CFF"))
                    .frame(width: max(0, maxX - minX), height: trackHeight)
                    .offset(x: minX)
                
                // 左つまみ（最小）— 指の位置でバー上の位置を計算
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .overlay(Circle().stroke(Color(hex: "2E5CFF"), lineWidth: 2))
                    .offset(x: minX - thumbSize / 2)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fingerXInBar = (minX - thumbSize / 2) + value.location.x
                                let fraction = max(0, min(1, fingerXInBar / w))
                                let newMin = range.lowerBound + Int(fraction * CGFloat(rangeSpan))
                                ageMin = min(max(newMin, range.lowerBound), ageMax)
                            }
                    )
                
                // 右つまみ（最大）
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .overlay(Circle().stroke(Color(hex: "2E5CFF"), lineWidth: 2))
                    .offset(x: maxX - thumbSize / 2)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fingerXInBar = (maxX - thumbSize / 2) + value.location.x
                                let fraction = max(0, min(1, fingerXInBar / w))
                                let newMax = range.lowerBound + Int(fraction * CGFloat(rangeSpan))
                                ageMax = max(min(newMax, range.upperBound), ageMin)
                            }
                    )
            }
            .frame(height: thumbSize)
        }
        .frame(height: 24)
    }
}

// MARK: - Filter Detail Sheet
struct FilterDetailSheet: View {
    let selectedMode: String
    @Binding var prefecture: String
    @Binding var ageGroup: String
    @Binding var ageMin: Int
    @Binding var ageMax: Int
    @Binding var rankMode: String
    @Binding var activeTime: String
    @Binding var runningGoal: String
    @Binding var personalBest: String
    @Binding var bestFull: String
    @Binding var bestHalf: String
    @Binding var easyPace: String
    @Binding var runSpot: String
    
    // 登録時の値（表示・初期値用）
    var myRank: String = "Rank B"
    var myBestFull: String = ""
    var myBestHalf: String = ""
    var myJogPace: String = "5:30/km"
    
    // Practices用
    @Binding var practiceCategory: PracticeCategory?
    @Binding var practiceDay: String
    @Binding var practiceSpot: String
    @Binding var practiceCapacity: String
    @Binding var practiceStartTime: String
    let onApply: () -> Void
    let onClear: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var localRunSpot: String = ""
    
    // 47都道府県（JISコード順）
    private let prefectures = [
        "指定なし",
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県",
        "岐阜県", "静岡県", "愛知県", "三重県",
        "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
        "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県",
        "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]
    private let ageGroups = ["指定なし", "20代", "30代", "40代", "50代", "60代以上"]
    private let schedules = ["指定なし", "平日 朝", "平日 夜", "土日 朝", "土日 午前", "土日 午後", "土日 夜", "不定期"]
    private let rankModes = ["すべて", "自分より上のみ", "自分と同じ以上", "自分より下のみ"]
    private let runningGoals = ["指定なし", "ファンラン", "ダイエット", "サブ3", "サブ4", "自己記録更新"]
    private let bestTimes = ["指定なし", "サブ2.5", "サブ3", "サブ3.5", "サブ4", "サブ5", "完走", "未計測"]
    private let bestFullOptions = ["指定なし", "サブ2.5", "サブ3", "サブ3.5", "サブ4", "サブ4.5", "サブ5", "完走", "未計測"]
    private let bestHalfOptions = ["指定なし", "サブ1:10", "サブ1:20", "サブ1:30", "サブ1:40", "サブ2:00", "完走", "未計測"]
    private let easyPaces = [
        "指定なし",
        "4:00/km未満", "4:00/km", "4:30/km",
        "5:00/km", "5:30/km", "6:00/km", "6:30/km", "7:00/km〜"
    ]
    private let spotSuggestions = ["皇居", "大阪城公園", "駒沢公園", "みなとみらい", "代々木公園", "名古屋城", "大濠公園"]
    
    // Practices用
    private let daysOfWeek = ["指定なし", "平日", "土日", "月", "火", "水", "木", "金", "土", "日"]
    private let capacities = ["指定なし", "〜5名", "〜10名", "11名〜"]
    private let timeBands = ["指定なし", "朝 (〜9:00)", "昼 (9〜17時)", "夜 (17時〜)"]
    
    var body: some View {
        NavigationStack {
            Form {
                if selectedMode == "Runners" {
                    // ランク（階層型）
                    Section(header: Text("ランク")) {
                        Picker("マッチングするランク", selection: $rankMode) {
                            ForEach(rankModes, id: \.self) { mode in
                                Text(mode).tag(mode)
                            }
                        }
                        Text("自分のランク: \(myRank)")
                            .font(.caption)
                            .foregroundColor(Color(hex: "0F1A2E").opacity(0.6))
                    }
                    
                    // 基本情報
                    Section(header: Text("基本情報")) {
                        Picker("居住地", selection: $prefecture) {
                            ForEach(prefectures, id: \.self) { pref in
                                Text(pref).tag(pref)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("年齢（20〜80歳）")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "0F1A2E"))
                            HStack {
                                Text("\(ageMin)歳")
                                    .font(.subheadline.bold())
                                    .frame(width: 36, alignment: .leading)
                                Text("〜")
                                    .foregroundColor(.secondary)
                                Text("\(ageMax)歳")
                                    .font(.subheadline.bold())
                                    .frame(width: 36, alignment: .trailing)
                            }
                            AgeRangeSlider(ageMin: $ageMin, ageMax: $ageMax, range: 20...80)
                        }
                        
                        Picker("普段走る時間帯", selection: $activeTime) {
                            ForEach(schedules, id: \.self) { schedule in
                                Text(schedule).tag(schedule)
                            }
                        }
                    }
                    
                    // ランニング情報
                    Section(header: Text("ランニング情報")) {
                        Picker("目的", selection: $runningGoal) {
                            ForEach(runningGoals, id: \.self) { goal in
                                Text(goal).tag(goal)
                            }
                        }
                        
                        Picker("ベスト（フル）", selection: $bestFull) {
                            ForEach(bestFullOptions, id: \.self) { best in
                                Text(best).tag(best)
                            }
                        }
                        if !myBestFull.isEmpty {
                            Text("登録時の値: \(myBestFull)")
                                .font(.caption)
                                .foregroundColor(Color(hex: "0F1A2E").opacity(0.6))
                        }
                        
                        Picker("ベスト（ハーフ）", selection: $bestHalf) {
                            ForEach(bestHalfOptions, id: \.self) { best in
                                Text(best).tag(best)
                            }
                        }
                        if !myBestHalf.isEmpty {
                            Text("登録時の値: \(myBestHalf)")
                                .font(.caption)
                                .foregroundColor(Color(hex: "0F1A2E").opacity(0.6))
                        }
                        
                        Picker("普段のジョグペース", selection: $easyPace) {
                            ForEach(easyPaces, id: \.self) { pace in
                                Text(pace).tag(pace)
                            }
                        }
                        Text("登録時の値: \(myJogPace)")
                            .font(.caption)
                            .foregroundColor(Color(hex: "0F1A2E").opacity(0.6))
                    }
                    
                    // よく走る場所
                    Section(header: Text("よく走る場所")) {
                        TextField("場所を入力", text: $localRunSpot)
                            .onChange(of: localRunSpot) { newValue in
                                runSpot = newValue
                            }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(spotSuggestions, id: \.self) { spot in
                                    Button(action: {
                                        localRunSpot = spot
                                        runSpot = spot
                                    }) {
                                        Text(spot)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Color(hex: "0F1A2E"))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color(hex: "F5F7FA"))
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                } else {
                    // Practices用 詳細フィルター
                    Section(header: Text("カテゴリー")) {
                        Picker("カテゴリー", selection: $practiceCategory) {
                            Text("指定なし").tag(PracticeCategory?.none)
                            ForEach(PracticeCategory.allCases, id: \.self) { category in
                                Text(category.rawValue).tag(Optional(category))
                            }
                        }
                    }
                    
                    Section(header: Text("曜日")) {
                        Picker("曜日", selection: $practiceDay) {
                            ForEach(daysOfWeek, id: \.self) { day in
                                Text(day).tag(day)
                            }
                        }
                    }
                    
                    Section(header: Text("よく走る場所")) {
                        TextField("場所を入力", text: $practiceSpot)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(spotSuggestions, id: \.self) { spot in
                                    Button(action: {
                                        practiceSpot = spot
                                    }) {
                                        Text(spot)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Color(hex: "0F1A2E"))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color(hex: "F5F7FA"))
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    
                    Section(header: Text("定員")) {
                        Picker("定員", selection: $practiceCapacity) {
                            ForEach(capacities, id: \.self) { cap in
                                Text(cap).tag(cap)
                            }
                        }
                    }
                    
                    Section(header: Text("スタート時間")) {
                        Picker("スタート時間", selection: $practiceStartTime) {
                            ForEach(timeBands, id: \.self) { band in
                                Text(band).tag(band)
                            }
                        }
                    }
                }
            }
            .navigationTitle("詳細フィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左上: 閉じる
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "0F1A2E"))
                }
                // 右上: 条件をクリア
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("条件をクリア") {
                        onClear()
                        localRunSpot = ""
                        practiceCategory = nil
                        practiceDay = "指定なし"
                        practiceSpot = ""
                        practiceCapacity = "指定なし"
                        practiceStartTime = "指定なし"
                    }
                    .foregroundColor(Color(hex: "2E5CFF"))
                }
            }
            // 下部固定の「この条件で検索」ボタン
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    onApply()
                    dismiss()
                }) {
                    Text("この条件で検索")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "2E5CFF"))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                .background(Color.white.opacity(0.9))
            }
            .onAppear {
                localRunSpot = runSpot
            }
        }
    }
}

#Preview {
    NavigationStack {
        FindView()
    }
}

# TASUKI データフロー・規約マトリクス

## 1. データフロー一覧表

| 区分 | データ種別 | 取得元 | Firestore パス | 目的 | 保持期間 | 第三者提供 | 規約への反映 |
|------|------------|--------|----------------|------|----------|------------|--------------|
| アカウント | Firebase Auth UID | アプリ | users/{uid} のキー | 識別・認証 | 退会時まで | Firebase/Google | アカウント、ログイン手段、退会の扱い |
| プロフィール | 氏名・性別・年代・地域・ペース等 | アプリ（ProfileRegistrationView） | users/{uid} | マッチング・表示 | 退会時まで | Firebase/Google | プロフィール取得項目 |
| プロフィール | spotName, lat, lon | アプリ | users/{uid} | 位置ベース機能 | 退会時まで | Firebase/Google | 位置情報の共有範囲 |
| 走行記録 | GPS ルート、距離、時間、source | RunTracker / HealthKit | users/{uid}/activities | 記録・駅伝連携 | 退会時まで | Firebase/Google | GPS・走行データ |
| HealthKit | ワークアウト・距離・ルート | HealthKitManager | 間接: activities に反映 | 走行記録の取得・駅伝提出 | 退会時まで | Firebase/Google | 要配慮個人情報として明記 |
| 駅伝 | イベント・エントリー・区間・提出 | アプリ | ekiden_events, ekiden_entries, legs, submissions | バーチャル駅伝 | 退会時まで | Firebase/Google | 駅伝・チーム内共有 |
| チーム | メンバー・申請・teamId | TeamView, TeamManageView | teams, joinRequests, users/{uid}.teamId | チーム機能 | 退会時まで | Firebase/Google | チーム・メンバー情報 |
| チームチャット | メッセージ | TeamView | teams/{teamId}/teamChat | チーム内連絡 | 退会時まで | Firebase/Google | メッセージ保存方針 |
| 会話 | 1対1メッセージ | ChatView, ConversationManager | conversations, messages | マッチング後連絡 | 退会時まで | Firebase/Google | 会話データの保存方針 |
| ポイント | 累計・月間 | PointService | users/{uid} totalPoints, monthlyPoints | ゲーミフィケーション | 退会時まで | Firebase/Google | ポイント同期の有無 |
| 分析（任意） | RealityMining イベント | RealityMiningManager | users/{uid}/reality_events | 行動分析・改善 | 退会時まで | Firebase/Google | オプトイン明記・独立レイヤー |

## 2. 規約に記載すべき項目（確定）

- アカウント: Firebase Auth による認証、退会・削除の扱い
- プロフィール: 氏名、性別、年代、地域、ペース、位置（spot/lat/lon）
- 走行データ: GPS ルート、距離、時間、`users/{uid}/activities` へのアップロード
- HealthKit: ワークアウト・距離・ルート読取、駅伝提出での連携、要配慮個人情報の扱い
- 駅伝: ekiden_* コレクション、区間・提出・順位、チーム内共有
- チーム: teams, メンバー、申請、teamChat、users.teamId
- メッセージ: conversations, teams/{id}/teamChat の保存方針
- ポイント: ローカル + Firestore 同期
- RealityMining: 同意なしでは送信しない、規約とは別のオプトイン、イベント名・タイムスタンプ等

## 3. 関連ソース

- `UserManager.swift` → users/{uid}
- `RunTracker.swift`, `PerformanceFeatures.swift` → activities
- `HealthKitManager.swift` → 間接的に activities へ
- `EkidenDataService.swift`, `EkidenModels.swift` → ekiden_*
- `TeamView.swift`, `TeamJoinCreateView.swift`, `TeamManageView.swift` → teams
- `ConversationManager.swift` → conversations
- `PointService.swift` → users 内ポイント
- `RealityMiningManager.swift` → users/{uid}/reality_events

---

## 4. 有料プラン条項の照合結果

**実装状況**: StoreKit、課金、サブスクリプション関連の実装はコードベースに存在しない。

**方針**: 第5条・第6条を「将来提供予定」に変更し、現時点では有料機能がない旨を明記する。将来的に実装する場合は条文を再改訂する。

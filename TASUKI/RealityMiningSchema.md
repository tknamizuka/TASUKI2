# Reality Mining Feature Schema

`users/{uid}/behavior_features/{yyyymmdd}` に保存する想定スキーマ:

- `generatedAt` (Timestamp): 集計生成時刻
- `weeklyRunCount` (Int): 直近7日のラン関連イベント回数
- `weeklyRunTrendDelta` (Int): 直近7日とその前7日のラン関連イベント差分
- `socialActivityScore` (Double): 0.0-1.0 の社会活動スコア
- `consistencyScore` (Double): 0.0-1.0 の継続性スコア
- `weekendActivityRatio` (Double): 全イベントに占める土日イベント割合
- `routineSpreadScore` (Double): 直近7日で活動した曜日の分散スコア（0.0-1.0）
- `behaviorShiftScore` (Double): 先週比での行動変化の大きさ（0.0-1.0）
- `medianMessageIntervalSec` (Double): メッセージ送信間隔の中央値（秒）
- `topActiveHour` (Int): 最頻活動時間帯（0-23）

`users/{uid}/reality_events/{eventId}` から抽出する主なイベント:

- `run_tracking_start`
- `run_tracking_stop`
- `race_joined`
- `race_finish_submitted`
- `time_trial_submitted`
- `message_sent`
- `screen_view`

## Cloud Job の最小仕様

日次バッチ（Cloud Functions / Cloud Run / 任意ジョブ）で以下を実行:

1. 対象日と直近7日分の `reality_events` を読み込む
2. イベント名、時間帯、曜日分布、先週比を集計
3. 上記スキーマで `behavior_features/{yyyymmdd}` に upsert
4. 失敗時はリトライし、処理ログを残す

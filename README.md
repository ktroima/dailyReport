# 日報管理ツール（dailyReport）

## 機能

- 日報JSONの自動/対話入力（今日のタスク・工数、総括メモ）
- 翌日のタスク入力（タイトル/メモ/優先度）
- リマインダー（朝: 昨日サマリ、夕: 今日記入促し）
- 通知後に詳細ダイアログ表示（JSONを開く導線あり）

## 要件

- macOS（launchd・osascriptを使用）
- bash
- jq

## セットアップ

### 1. リマインダーの設定

必要に応じて `config.sh` を編集してリマインダー時間を変更します（デフォルト: 朝9時、夕18時）。

```bash
# config.sh の例
MORNING_HOUR=9;   MORNING_MINUTE=0  # 業務開始時刻
EVENING_HOUR=18;  EVENING_MINUTE=0  # 業務終了時刻
NOTIFICATION_SOUND="Glass"           # 通知音
```

### 2. plistファイルを生成してlaunchdへ登録

```bash
# plistファイルを生成
./generate_plist.sh

# 生成されたplistをLaunchAgentsへコピー
cp com.workmanagement.morning.plist  ~/Library/LaunchAgents/
cp com.workmanagement.evening.plist  ~/Library/LaunchAgents/

# リマインダーを起動
launchctl load ~/Library/LaunchAgents/com.workmanagement.morning.plist
launchctl load ~/Library/LaunchAgents/com.workmanagement.evening.plist
```

## 基本的な使い方

### 日報の編集

以下のコマンドを入力すると日報入力が開始されます。対話形式で回答していく形で入力が進みます。

フロー: タスク入力→メモ→工数→追加の有無→（繰り返し）→1日の総括メモ→翌日のタスク入力→保存して終了。

```bash
# 今日の日報を編集
./edit_report.sh
# 特定の日付の日報を編集
./edit_report.sh 2025-11-17
```

## 設定変更

リマインダーの時間を変更したい場合、以下の操作を行うことで変更が可能です。

1) `config.sh` を編集

```bash
# リマインダー時刻
# 業務開始時刻のリマインダー
MORNING_HOUR=9;   MORNING_MINUTE=0
# 業務終了時刻のリマインダー
EVENING_HOUR=18;  EVENING_MINUTE=0
# 通知音
NOTIFICATION_SOUND="Glass"
```

2) plistを再生成（生成物。パス情報が含まれるためGit管理しない）

```bash
./generate_plist.sh
```

3) launchdへ再登録

```bash
# 生成されたplistをLaunchAgentsへコピー
cp com.workmanagement.morning.plist  ~/Library/LaunchAgents/
cp com.workmanagement.evening.plist  ~/Library/LaunchAgents/

# 既存のリマインダーを停止（エラーは無視）
launchctl unload ~/Library/LaunchAgents/com.workmanagement.morning.plist 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.workmanagement.evening.plist 2>/dev/null || true

# 新しい設定でリマインダーを起動
launchctl load   ~/Library/LaunchAgents/com.workmanagement.morning.plist
launchctl load   ~/Library/LaunchAgents/com.workmanagement.evening.plist
```

## スクリプトの詳細

### config.sh

システム全体の設定を管理する設定ファイルです。

- リマインダー時刻の設定
- 通知音の設定
- 作業ディレクトリの設定

### generate_plist.sh

launchd用のplistファイルを生成するスクリプトです。

```bash
./generate_plist.sh
```

実行すると、`config.sh`の設定に基づいて以下のファイルが生成されます:
- `com.workmanagement.morning.plist`: 朝のリマインダー設定
- `com.workmanagement.evening.plist`: 夕方のリマインダー設定

### edit_report.sh

対話形式で日報を入力・編集するメインスクリプトです。

```bash
# 今日の日報を編集
./edit_report.sh

# 特定の日付の日報を編集
./edit_report.sh 2025-11-22
```

処理フロー:
1. 今日のタスク入力（タイトル、メモ、工数）
2. 1日の総括メモ入力
3. 今日の日報をJSON形式で保存
4. 翌日のタスク入力（タイトル、メモ、優先度）
5. 翌日の日報をJSON形式で保存

### morning_summary.sh

業務開始時に昨日の日報サマリを通知で表示するスクリプトです。

```bash
./morning_summary.sh
```

表示内容:
- 完了タスク数
- 未完了タスク数
- メモの件数
- 総工数

通常はlaunchdから自動実行されますが、手動でも実行可能です。

### evening_reminder.sh

業務終了時に今日の日報記入を促す通知を表示するスクリプトです。

```bash
./evening_reminder.sh
```

通常はlaunchdから自動実行されますが、手動でも実行可能です。日報ファイルが存在しない場合は、テンプレートファイルを自動生成します。

### show_report_details.sh

日報の詳細をダイアログ形式で表示するスクリプトです。

```bash
# 今日の日報を表示
./show_report_details.sh

# 特定の日付の日報を表示
./show_report_details.sh 2025-11-22
```

表示内容:
- タスク一覧（タイトル、工数、優先度、メモ）
- メモ一覧
- 総工数

「ファイルを開く」ボタンをクリックすると、JSONファイルを直接開くことができます。

## アーキテクチャ

### システム構成

```
launchd (定時実行)
  ├── morning_summary.sh (朝: 昨日のサマリ表示)
  └── evening_reminder.sh (夕: 今日の記入促し)
        ↓
  macOS通知センター
        ↓
  show_report_details.sh (詳細表示)

ユーザー操作
  └── edit_report.sh (日報編集)
        ↓
  日報ファイル (YYYY/MM/YYYY-MM-DD.json)
```

### データ構造

日報ファイルはJSON形式で以下の構造を持ちます:

```json
{
  "date": "2025-11-22",
  "tasks": [
    {
      "id": "task-001",
      "title": "タスク名",
      "hours": 2.5,
      "memo": "メモ内容",
      "priority": "medium",
      "status": "pending",
      "created_at": "2025-11-22T10:00:00"
    }
  ],
  "notes": ["総括メモ"],
  "time_tracking": {
    "start_time": null,
    "end_time": null,
    "breaks": []
  }
}
```

### ディレクトリ構造

```
dailyReport/
├── config.sh                       # 設定ファイル
├── generate_plist.sh               # plist生成
├── edit_report.sh                  # 日報編集
├── morning_summary.sh              # 朝のリマインダー
├── evening_reminder.sh             # 夕方のリマインダー
├── show_report_details.sh          # 詳細表示
├── docs/                           # ドキュメント
│   ├── troubleshooting.md
│   ├── architecture.md
│   └── CONTRIBUTING.md
└── YYYY/MM/YYYY-MM-DD.json         # 日報ファイル
```

詳細なアーキテクチャについては、[docs/architecture.md](docs/architecture.md)を参照してください。

## トラブルシューティング

問題が発生した場合は、[docs/troubleshooting.md](docs/troubleshooting.md)を参照してください。

主なトラブルシューティング:
- jqがインストールされていない場合
- launchdが起動しない場合
- 通知が表示されない場合
- 日報ファイルが破損した場合

## 貢献

プロジェクトへの貢献を歓迎します。詳細は[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)を参照してください。

## 今後の展望

- バグチェック
- 運用してみて面倒に感じた箇所の改善
- 月毎の日報サマリ作成機能
- ブラウザを利用して画面上でレポートの確認を可能にする
- CSVエクスポート機能

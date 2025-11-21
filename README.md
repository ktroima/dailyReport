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

## 手動リマインダー実行方法

```bash
# 朝：昨日サマリ
./morning_summary.sh
# 夕：今日の記入促し
./evening_reminder.sh
# 任意日付の詳細ダイアログ
./show_report_details.sh 2025-11-17
```

## 月次サマリ機能

月間の日報を集計して統計情報を表示する機能です。

### 使用方法

```bash
# 今月のサマリを表示（テキスト形式）
./monthly_summary.sh

# 特定の年月を指定
./monthly_summary.sh -y 2025 -m 11

# JSON形式で出力
./monthly_summary.sh -f json

# HTML形式で出力
./monthly_summary.sh -f html > monthly_report.html

# グラフも生成（gnuplotが必要）
./monthly_summary.sh -g
```

### オプション

- `-y YEAR`: 年を指定（例: 2025）
- `-m MONTH`: 月を指定（例: 11）
- `-f FORMAT`: 出力形式を指定（text|json|html）[デフォルト: text]
- `-g`: グラフを生成（gnuplotが必要）
- `-h`: ヘルプを表示

### 集計内容

月次サマリでは以下の統計情報を提供します:

1. **基本統計**
   - 日報数（日）
   - 総作業時間（時間）
   - 完了タスク数（個）
   - 平均作業時間/日（時間）

2. **工数の多かった日TOP5**
   - 作業時間が多かった日をランキング形式で表示

3. **よく使われたキーワードTOP10**
   - タスクタイトルとメモから頻出キーワードを抽出

### 出力形式

#### テキスト形式（デフォルト）
コンソール上で見やすいテキストフォーマットで統計情報を表示します。

#### JSON形式
機械的に処理しやすいJSON形式で出力します。他のツールとの連携に便利です。

```bash
./monthly_summary.sh -f json > summary.json
```

#### HTML形式
ブラウザで見やすいHTML形式で出力します。

```bash
./monthly_summary.sh -f html > monthly_report.html
# ブラウザで開く
open monthly_report.html
```

### グラフ生成

`-g` オプションを指定すると、gnuplotを使用して作業時間の推移グラフ（PNG形式）を生成します。

```bash
# グラフ生成（gnuplotが必要）
./monthly_summary.sh -g

# グラフは以下のパスに保存されます
# monthly_summary_YYYY_MM.png
```

gnuplotのインストール:
```bash
brew install gnuplot
```

## 今後の展望

- バグチェック
- 運用してみて面倒に感じた箇所の改善
- ブラウザを利用して画面上でレポートの確認を可能にする
- READMEの記述精査

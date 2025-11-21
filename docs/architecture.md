# アーキテクチャドキュメント

## 概要

日報管理ツール（dailyReport）は、macOS上でbashスクリプトとlaunchdを使用して動作する軽量な日報管理システムです。このドキュメントでは、システムの構成、データフロー、各コンポーネントの役割について説明します。

## システム構成

```
┌─────────────────────────────────────────────────────────────┐
│                        macOS System                          │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                      launchd                          │  │
│  │  ┌─────────────────┐  ┌─────────────────┐           │  │
│  │  │ morning.plist   │  │ evening.plist   │           │  │
│  │  │ (9:00 AM)       │  │ (6:00 PM)       │           │  │
│  │  └────────┬────────┘  └────────┬────────┘           │  │
│  └───────────┼────────────────────┼─────────────────────┘  │
│              │                    │                         │
│              ▼                    ▼                         │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │morning_summary.sh│  │evening_reminder. │               │
│  │                  │  │       sh         │               │
│  └────────┬─────────┘  └────────┬─────────┘               │
│           │                     │                          │
│           │                     │                          │
│           ▼                     ▼                          │
│  ┌─────────────────────────────────────┐                  │
│  │      osascript (Notification)       │                  │
│  │  ┌──────────────────────────────┐   │                  │
│  │  │  macOS Notification Center   │   │                  │
│  │  └──────────────────────────────┘   │                  │
│  └──────────────┬──────────────────────┘                  │
│                 │                                          │
│                 ▼                                          │
│  ┌──────────────────────────────────┐                     │
│  │   show_report_details.sh         │                     │
│  │   (ユーザーが「はい」を選択)      │                     │
│  └──────────────┬───────────────────┘                     │
│                 │                                          │
└─────────────────┼──────────────────────────────────────────┘
                  │
                  ▼
      ┌───────────────────────┐
      │  User Interaction     │
      │  ┌─────────────────┐  │
      │  │ edit_report.sh  │  │
      │  └────────┬────────┘  │
      └───────────┼───────────┘
                  │
                  ▼
      ┌───────────────────────┐
      │   File System         │
      │   YYYY/MM/           │
      │   └── YYYY-MM-DD.json│
      └───────────────────────┘
```

## コンポーネント詳細

### 1. 設定・管理スクリプト

#### config.sh
- 役割: システム全体の設定を一元管理
- 設定項目:
  - `WORK_DIR`: 日報ファイルの保存場所
  - `MORNING_HOUR`, `MORNING_MINUTE`: 朝のリマインダー時刻
  - `EVENING_HOUR`, `EVENING_MINUTE`: 夕方のリマインダー時刻
  - `NOTIFICATION_SOUND`: 通知音の設定
- 他のすべてのスクリプトから読み込まれる

#### generate_plist.sh
- 役割: launchd用のplistファイルを生成
- 処理内容:
  1. `config.sh`から設定を読み込む
  2. `com.workmanagement.morning.plist`を生成
  3. `com.workmanagement.evening.plist`を生成
  4. スクリプトの絶対パスをplistに埋め込む
- 出力ファイル:
  - `com.workmanagement.morning.plist`
  - `com.workmanagement.evening.plist`

### 2. 日報編集スクリプト

#### edit_report.sh
- 役割: 対話形式で日報を入力・編集
- 処理フロー:
  ```
  1. 日付の取得（引数または現在日時）
  2. 既存日報の読み込み（存在する場合）
  3. 今日のタスク入力ループ
     - タスクタイトル
     - メモ
     - 工数（時間）
  4. 1日の総括メモ入力
  5. 今日の日報をJSON形式で保存
  6. 翌日のタスク入力ループ
     - タスクタイトル
     - メモ
     - 優先度（low/medium/high）
  7. 翌日のタスクをJSON形式で保存
  ```
- 使用技術:
  - `jq`: JSON処理
  - `date`: 日付計算（macOS/Linux互換）
- データ構造:
  - タスクID: `task-001`, `task-002`, ... (自動採番)
  - 工数: 数値（時間単位）
  - 優先度: "low", "medium", "high"

### 3. リマインダースクリプト

#### morning_summary.sh
- 役割: 朝に昨日の日報サマリを通知
- 処理フロー:
  ```
  1. 昨日の日付を計算
  2. 昨日の日報ファイルを確認
  3. jqでタスク・メモ・工数を集計
  4. osascriptで通知を表示
  5. ユーザーに詳細表示の選択肢を提示
  6. 「はい」の場合、show_report_details.shを起動
  ```
- 通知内容:
  - 完了タスク数
  - 未完了タスク数
  - メモの件数
  - 総工数

#### evening_reminder.sh
- 役割: 夕方に今日の日報記入を促す
- 処理フロー:
  ```
  1. 今日の日付を取得
  2. 今日の日報ファイルを確認
  3. jqでタスクの状況を分析
  4. osascriptで通知を表示
  5. ユーザーに詳細表示の選択肢を提示
  6. 日報が存在しない場合、テンプレートを作成
  ```
- 通知内容:
  - 完了タスク数
  - 未完了タスク数
  - メモの件数
  - 総工数

### 4. 表示スクリプト

#### show_report_details.sh
- 役割: 日報の詳細をダイアログ形式で表示
- 処理フロー:
  ```
  1. 日付の取得（引数または現在日時）
  2. 日報ファイルの存在確認
  3. jqでタスク・メモを抽出
  4. フォーマット済みテキストを生成
  5. osascriptでダイアログ表示
  6. 「ファイルを開く」ボタンでJSONファイルを開く
  ```
- 表示内容:
  - タスク一覧（タイトル、工数、優先度、メモ）
  - メモ一覧
  - 総工数

## データフロー

### 日報作成フロー

```
┌──────────────┐
│ ユーザー入力 │
└──────┬───────┘
       │
       ▼
┌──────────────────┐
│ edit_report.sh   │
│ ・タスク情報収集 │
│ ・jqでJSON生成   │
└──────┬───────────┘
       │
       ▼
┌──────────────────────┐
│ ファイルシステム      │
│ YYYY/MM/YYYY-MM-DD.   │
│        json           │
│ {                     │
│   "date": "...",      │
│   "tasks": [...],     │
│   "notes": [...],     │
│   "time_tracking": {} │
│ }                     │
└───────────────────────┘
```

### リマインダーフロー

```
┌──────────────┐
│   launchd    │
│ (定時起動)   │
└──────┬───────┘
       │
       ▼
┌─────────────────────┐
│ morning_summary.sh  │
│ evening_reminder.sh │
│ ・日報ファイル読込  │
│ ・jqで集計          │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│   osascript         │
│ ・通知表示          │
│ ・ダイアログ表示    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ユーザーアクション   │
│ ・「はい」選択      │
└──────┬──────────────┘
       │
       ▼
┌──────────────────────┐
│show_report_details.sh│
│ ・詳細情報表示       │
└──────────────────────┘
```

## ディレクトリ構造

```
dailyReport/
├── config.sh                       # 設定ファイル
├── generate_plist.sh               # plist生成スクリプト
├── edit_report.sh                  # 日報編集スクリプト
├── morning_summary.sh              # 朝のリマインダー
├── evening_reminder.sh             # 夕方のリマインダー
├── show_report_details.sh          # 詳細表示スクリプト
├── com.workmanagement.morning.plist # launchd設定（生成物）
├── com.workmanagement.evening.plist # launchd設定（生成物）
├── morning.log                     # 朝のログ（生成物）
├── morning.error.log               # 朝のエラーログ（生成物）
├── evening.log                     # 夕方のログ（生成物）
├── evening.error.log               # 夕方のエラーログ（生成物）
├── docs/                           # ドキュメント
│   ├── troubleshooting.md
│   ├── architecture.md
│   └── CONTRIBUTING.md
├── README.md
└── YYYY/                           # 年ディレクトリ
    └── MM/                         # 月ディレクトリ
        └── YYYY-MM-DD.json         # 日報ファイル
```

## データモデル

### 日報JSONスキーマ

```json
{
  "date": "YYYY-MM-DD",
  "tasks": [
    {
      "id": "task-001",
      "title": "タスク名",
      "hours": 2.5,
      "memo": "メモ内容",
      "priority": "medium",
      "status": "pending",
      "created_at": "YYYY-MM-DDTHH:MM:SS"
    }
  ],
  "notes": [
    "総括メモ1",
    "総括メモ2"
  ],
  "time_tracking": {
    "start_time": null,
    "end_time": null,
    "breaks": []
  }
}
```

### フィールド説明

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|------|
| date | string | 日報の日付（YYYY-MM-DD形式） | ✓ |
| tasks | array | タスクの配列 | ✓ |
| tasks[].id | string | タスクID（task-XXX形式） | ✓ |
| tasks[].title | string | タスクのタイトル | ✓ |
| tasks[].hours | number | 工数（時間） | ✓ |
| tasks[].memo | string | タスクのメモ | - |
| tasks[].priority | string | 優先度（low/medium/high） | - |
| tasks[].status | string | ステータス（pending/completed） | - |
| tasks[].created_at | string | 作成日時（ISO 8601形式） | ✓ |
| notes | array | 総括メモの配列 | ✓ |
| time_tracking | object | 時間追跡情報（将来の拡張用） | ✓ |

## 技術スタック

| カテゴリ | 技術 | 用途 |
|----------|------|------|
| スクリプト言語 | bash | メインの処理言語 |
| JSON処理 | jq | JSONの生成・解析・変換 |
| スケジューラ | launchd | 定時実行 |
| 通知 | osascript | macOS通知の表示 |
| ダイアログ | osascript | ユーザー対話 |
| 日付計算 | date コマンド | macOS/Linux互換 |

## jqの主要な使用パターン

### 1. タスクの追加

```bash
# 新しいタスクを配列に追加
TODAY_TASKS=$(echo "$TODAY_TASKS" | jq ". + [$new_task]")
```

### 2. 集計処理

```bash
# 総工数の計算
TOTAL_HOURS=$(jq '[.tasks[] | .hours] | add // 0' "$DAILY_REPORT")

# タスク数のカウント
TASK_COUNT=$(jq '[.tasks] | flatten | length' "$DAILY_REPORT")

# 未完了タスクのフィルタリング
PENDING_TASKS=$(jq '[.tasks[] | select(.status == "pending")] | length' "$DAILY_REPORT")
```

### 3. JSON生成

```bash
# 新しいタスクオブジェクトの生成
new_task=$(jq -n \
    --arg id "$task_id" \
    --arg title "$task_title" \
    --arg hours "$task_hours" \
    --arg memo "$task_memo" \
    '{id: $id, title: $title, hours: ($hours | tonumber), memo: $memo}')
```

### 4. タスクIDの自動採番

```bash
# 既存のタスクから最大IDを取得し、+1する
TASK_ID_COUNTER=$(echo "$TODAY_TASKS" | jq -r '[.[] | .id | scan("[0-9]+") | tonumber] | max // 0' | awk '{print $1+1}')
```

## セキュリティと権限

### 必要な権限

1. ファイルシステム: 読み書き権限（日報ファイルの保存）
2. launchd: LaunchAgentsへのアクセス
3. osascript: 通知の表示権限
4. osascript: オートメーション権限（ダイアログ表示）

### データ保護

- 日報データはローカルファイルシステムに保存
- 外部サーバーへの送信なし
- ユーザーのホームディレクトリ配下に保存
- Git管理から除外すべきファイル:
  - `*.plist`（パス情報が含まれる）
  - `*.log`（個人のログ）
  - `YYYY/MM/*.json`（個人の日報データ）

## 拡張性

### 将来の拡張可能性

1. データ分析機能
   - 月次サマリの自動生成
   - グラフ化（工数の推移など）

2. エクスポート機能
   - CSV形式での出力
   - Markdown形式での出力

3. Webインターフェース
   - ブラウザでの閲覧・編集機能
   - 静的サイト生成

4. 時間追跡機能
   - 開始時刻・終了時刻の記録
   - 休憩時間の記録

5. タグ・カテゴリ機能
   - タスクへのタグ付け
   - カテゴリ別の集計

## パフォーマンス考慮事項

- jqは軽量で高速なため、日報ファイルのサイズが数MBでも問題なく処理可能
- launchdは低リソースでバックグラウンド実行
- ファイル数が増えても（年単位）、検索性能に影響なし（日付ベースのディレクトリ構造）

## 依存関係

```
macOS (10.14以降推奨)
├── bash (標準インストール済み)
├── jq (要インストール)
├── date (標準インストール済み)
├── launchd (標準インストール済み)
└── osascript (標準インストール済み)
```

## まとめ

このシステムは、シンプルで軽量なアーキテクチャを採用しており、以下の特徴があります:

- 標準的なmacOSツールを活用
- ファイルベースのデータ管理（データベース不要）
- 外部依存が少ない（jqのみ）
- 拡張性が高い（JSONベース）
- セットアップが簡単
- メンテナンスが容易

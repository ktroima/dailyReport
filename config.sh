#!/bin/bash

# 日報管理システム設定ファイル
# このファイルを編集して、環境に合わせて設定を変更してください

# ============================================
# 基本設定
# ============================================

# 作業ディレクトリのパス（このファイルがあるディレクトリを自動検出）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}"

# ============================================
# リマインダー時間設定
# ============================================

# 業務開始時リマインダー（昨日の日報サマリ表示）
MORNING_HOUR=9
MORNING_MINUTE=0

# 業務終了時リマインダー（今日の日報記入を促す）
EVENING_HOUR=18
EVENING_MINUTE=0

# ============================================
# 通知設定
# ============================================

# 通知音（Glass, Basso, Blow, Bottle, Frog, Funk, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink）
NOTIFICATION_SOUND="Glass"

# ============================================
# 日報フォーマット設定
# ============================================

# タイムゾーン
TIMEZONE="Asia/Tokyo"

# 日付フォーマット
DATE_FORMAT="%Y-%m-%d"
DATETIME_FORMAT="%Y-%m-%dT%H:%M:%S"
DATE_REGEX="^[0-9]{4}-[0-9]{2}-[0-9]{2}$"

# タスクID設定
TASK_ID_PREFIX="task-"
TASK_ID_PADDING=3

# デフォルト値
DEFAULT_TASK_HOURS=0
DEFAULT_TASK_COUNTER=1
DEFAULT_PRIORITY="medium"

# 優先度の選択肢
PRIORITY_LOW="low"
PRIORITY_MEDIUM="medium"
PRIORITY_HIGH="high"

# UI設定
SEPARATOR_LINE="=========================================="

# JSON空配列
EMPTY_JSON_ARRAY="[]"



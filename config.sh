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
NOTIFICATION_SOUND="${NOTIFICATION_SOUND:-Glass}"

# 通知後の待機時間（秒）
NOTIFICATION_DELAY="${NOTIFICATION_DELAY:-1}"

# ============================================
# ダイアログ設定
# ============================================

# ダイアログのタイムアウト時間（秒）
DIALOG_TIMEOUT="${DIALOG_TIMEOUT:-30}"

# 詳細表示の最大文字数
DIALOG_MAX_LENGTH="${DIALOG_MAX_LENGTH:-1000}"

# ダイアログの確認ボタンラベル
DIALOG_BUTTON_YES="${DIALOG_BUTTON_YES:-はい}"
DIALOG_BUTTON_NO="${DIALOG_BUTTON_NO:-いいえ}"
DIALOG_BUTTON_CLOSE="${DIALOG_BUTTON_CLOSE:-閉じる}"
DIALOG_BUTTON_OPEN="${DIALOG_BUTTON_OPEN:-ファイルを開く}"

# ============================================
# リトライ設定
# ============================================

# コマンド実行時の最大リトライ回数
MAX_RETRY_COUNT="${MAX_RETRY_COUNT:-3}"

# リトライ間の待機時間（秒）
RETRY_DELAY="${RETRY_DELAY:-2}"

# ============================================
# タスク表示設定
# ============================================

# タスク一覧で表示する最大件数（head -n）
TASK_DISPLAY_LIMIT="${TASK_DISPLAY_LIMIT:-3}"

# ============================================
# 設定ファイルの妥当性チェック
# ============================================

validate_config() {
    local errors=0

    # 時間設定のチェック
    if ! [[ "$MORNING_HOUR" =~ ^[0-9]+$ ]] || [ "$MORNING_HOUR" -lt 0 ] || [ "$MORNING_HOUR" -gt 23 ]; then
        echo "エラー: MORNING_HOURは0-23の整数である必要があります（現在: ${MORNING_HOUR}）" >&2
        errors=$((errors + 1))
    fi

    if ! [[ "$MORNING_MINUTE" =~ ^[0-9]+$ ]] || [ "$MORNING_MINUTE" -lt 0 ] || [ "$MORNING_MINUTE" -gt 59 ]; then
        echo "エラー: MORNING_MINUTEは0-59の整数である必要があります（現在: ${MORNING_MINUTE}）" >&2
        errors=$((errors + 1))
    fi

    if ! [[ "$EVENING_HOUR" =~ ^[0-9]+$ ]] || [ "$EVENING_HOUR" -lt 0 ] || [ "$EVENING_HOUR" -gt 23 ]; then
        echo "エラー: EVENING_HOURは0-23の整数である必要があります（現在: ${EVENING_HOUR}）" >&2
        errors=$((errors + 1))
    fi

    if ! [[ "$EVENING_MINUTE" =~ ^[0-9]+$ ]] || [ "$EVENING_MINUTE" -lt 0 ] || [ "$EVENING_MINUTE" -gt 59 ]; then
        echo "エラー: EVENING_MINUTEは0-59の整数である必要があります（現在: ${EVENING_MINUTE}）" >&2
        errors=$((errors + 1))
    fi

    # タイムアウト値のチェック
    if ! [[ "$DIALOG_TIMEOUT" =~ ^[0-9]+$ ]] || [ "$DIALOG_TIMEOUT" -lt 0 ]; then
        echo "エラー: DIALOG_TIMEOUTは0以上の整数である必要があります（現在: ${DIALOG_TIMEOUT}）" >&2
        errors=$((errors + 1))
    fi

    # 最大文字数のチェック
    if ! [[ "$DIALOG_MAX_LENGTH" =~ ^[0-9]+$ ]] || [ "$DIALOG_MAX_LENGTH" -lt 100 ]; then
        echo "エラー: DIALOG_MAX_LENGTHは100以上の整数である必要があります（現在: ${DIALOG_MAX_LENGTH}）" >&2
        errors=$((errors + 1))
    fi

    # リトライ回数のチェック
    if ! [[ "$MAX_RETRY_COUNT" =~ ^[0-9]+$ ]] || [ "$MAX_RETRY_COUNT" -lt 0 ]; then
        echo "エラー: MAX_RETRY_COUNTは0以上の整数である必要があります（現在: ${MAX_RETRY_COUNT}）" >&2
        errors=$((errors + 1))
    fi

    # リトライ待機時間のチェック
    if ! [[ "$RETRY_DELAY" =~ ^[0-9]+$ ]] || [ "$RETRY_DELAY" -lt 0 ]; then
        echo "エラー: RETRY_DELAYは0以上の整数である必要があります（現在: ${RETRY_DELAY}）" >&2
        errors=$((errors + 1))
    fi

    # タスク表示件数のチェック
    if ! [[ "$TASK_DISPLAY_LIMIT" =~ ^[0-9]+$ ]] || [ "$TASK_DISPLAY_LIMIT" -lt 1 ]; then
        echo "エラー: TASK_DISPLAY_LIMITは1以上の整数である必要があります（現在: ${TASK_DISPLAY_LIMIT}）" >&2
        errors=$((errors + 1))
    fi

    # 通知音の存在チェック（macOSの場合）
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local sound_path="/System/Library/Sounds/${NOTIFICATION_SOUND}.aiff"
        if [ ! -f "$sound_path" ]; then
            echo "警告: 指定された通知音が見つかりません: ${NOTIFICATION_SOUND}" >&2
            echo "  利用可能な通知音: Glass, Basso, Blow, Bottle, Frog, Funk, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink" >&2
        fi
    fi

    return $errors
}

# 環境変数による設定の説明を表示
show_config_help() {
    cat <<EOF
日報管理システム - 設定可能な環境変数

【リマインダー時間設定】
  MORNING_HOUR      : 業務開始時リマインダーの時（デフォルト: ${MORNING_HOUR}）
  MORNING_MINUTE    : 業務開始時リマインダーの分（デフォルト: ${MORNING_MINUTE}）
  EVENING_HOUR      : 業務終了時リマインダーの時（デフォルト: ${EVENING_HOUR}）
  EVENING_MINUTE    : 業務終了時リマインダーの分（デフォルト: ${EVENING_MINUTE}）

【通知設定】
  NOTIFICATION_SOUND: 通知音の名前（デフォルト: ${NOTIFICATION_SOUND}）
  NOTIFICATION_DELAY: 通知後の待機時間（秒）（デフォルト: ${NOTIFICATION_DELAY}）

【ダイアログ設定】
  DIALOG_TIMEOUT    : ダイアログのタイムアウト時間（秒）（デフォルト: ${DIALOG_TIMEOUT}）
  DIALOG_MAX_LENGTH : 詳細表示の最大文字数（デフォルト: ${DIALOG_MAX_LENGTH}）
  DIALOG_BUTTON_YES : 確認ボタンの「はい」ラベル（デフォルト: ${DIALOG_BUTTON_YES}）
  DIALOG_BUTTON_NO  : 確認ボタンの「いいえ」ラベル（デフォルト: ${DIALOG_BUTTON_NO}）
  DIALOG_BUTTON_CLOSE: 閉じるボタンのラベル（デフォルト: ${DIALOG_BUTTON_CLOSE}）
  DIALOG_BUTTON_OPEN: ファイルを開くボタンのラベル（デフォルト: ${DIALOG_BUTTON_OPEN}）

【リトライ設定】
  MAX_RETRY_COUNT   : コマンド実行時の最大リトライ回数（デフォルト: ${MAX_RETRY_COUNT}）
  RETRY_DELAY       : リトライ間の待機時間（秒）（デフォルト: ${RETRY_DELAY}）

【タスク表示設定】
  TASK_DISPLAY_LIMIT: タスク一覧で表示する最大件数（デフォルト: ${TASK_DISPLAY_LIMIT}）

使用例:
  NOTIFICATION_SOUND=Basso DIALOG_TIMEOUT=60 ./morning_summary.sh
  export MORNING_HOUR=8 MORNING_MINUTE=30
  ./generate_plist.sh
EOF
}

# コマンドライン引数で --config-help が指定された場合はヘルプを表示
if [ "$1" = "--config-help" ]; then
    show_config_help
    exit 0
fi

# 自動で妥当性チェックを実行（SKIP_CONFIG_VALIDATION=1で無効化可能）
if [ "${SKIP_CONFIG_VALIDATION:-0}" != "1" ]; then
    if ! validate_config; then
        echo "設定に問題があります。設定ファイルを確認してください: ${SCRIPT_DIR}/config.sh" >&2
        exit 1
    fi
fi

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



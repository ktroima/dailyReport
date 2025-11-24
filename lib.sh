#!/bin/bash

# 共通関数ライブラリ
# 日報管理スクリプトで共通して使用される関数を定義

# ------------------------------
# 日付処理関数
# ------------------------------

# 日付を取得する（macOS/Linux対応）
# 引数: $1=オフセット日数（例: -1で昨日、+1で明日）
# 戻り値: YYYY-MM-DD形式の日付
get_date_with_offset() {
    local offset="${1:-0}"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOSの場合
        if [ "$offset" -eq 0 ]; then
            TZ=Asia/Tokyo date +%Y-%m-%d
        else
            TZ=Asia/Tokyo date -v${offset}d +%Y-%m-%d 2>/dev/null
        fi
    else
        # Linuxの場合
        if [ "$offset" -eq 0 ]; then
            date +%Y-%m-%d
        else
            date -d "${offset} day" +%Y-%m-%d
        fi
    fi
}

# 指定された日付から相対的な日付を計算（macOS/Linux対応）
# 引数: $1=基準日付（YYYY-MM-DD）、$2=オフセット日数
# 戻り値: YYYY-MM-DD形式の日付
calculate_date_from() {
    local base_date="$1"
    local offset="${2:-0}"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOSの場合
        TZ=Asia/Tokyo date -j -v${offset}d -f "%Y-%m-%d" "$base_date" +%Y-%m-%d 2>/dev/null
        if [ $? -ne 0 ]; then
            # フォールバック
            TZ=Asia/Tokyo date -v${offset}d +%Y-%m-%d
        fi
    else
        # Linuxの場合
        date -d "$base_date ${offset} day" +%Y-%m-%d
    fi
}

# 日付から年を取得
# 引数: $1=日付（YYYY-MM-DD）
# 戻り値: YYYY形式の年
get_year_from_date() {
    echo "$1" | cut -d'-' -f1
}

# 日付から月を取得
# 引数: $1=日付（YYYY-MM-DD）
# 戻り値: MM形式の月
get_month_from_date() {
    echo "$1" | cut -d'-' -f2
}

# ------------------------------
# 日報ファイル読み込み関数
# ------------------------------

# 日報ファイルから統計情報を取得
# 引数: $1=日報ファイルパス
# グローバル変数に結果を設定: TOTAL_TASKS, COMPLETED_TASKS, PENDING_TASKS, NOTES_COUNT, TOTAL_HOURS
load_report_stats() {
    local report_file="$1"

    if [ ! -f "$report_file" ]; then
        TOTAL_TASKS=0
        COMPLETED_TASKS=0
        PENDING_TASKS=0
        NOTES_COUNT=0
        TOTAL_HOURS=0
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        return 1
    fi

    TOTAL_TASKS=$(jq '[.tasks + .completed_tasks] | flatten | length' "$report_file" 2>/dev/null || echo "0")
    COMPLETED_TASKS=$(jq '[.completed_tasks] | flatten | length' "$report_file" 2>/dev/null || echo "0")
    PENDING_TASKS=$(jq '[.tasks[] | select(.status == "pending" or .status == "in_progress")] | length' "$report_file" 2>/dev/null || echo "0")
    NOTES_COUNT=$(jq '.notes | length' "$report_file" 2>/dev/null || echo "0")
    TOTAL_HOURS=$(jq '[.tasks[] | .hours] | add // 0' "$report_file" 2>/dev/null || echo "0")

    return 0
}

# 日報ファイルからタスク情報を読み込む
# 引数: $1=日報ファイルパス
# 戻り値: タスクのJSON配列
load_tasks_from_report() {
    local report_file="$1"

    if [ -f "$report_file" ]; then
        jq -c '.tasks // []' "$report_file" 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

# 日報ファイルからノート情報を読み込む
# 引数: $1=日報ファイルパス
# 戻り値: ノートのJSON配列
load_notes_from_report() {
    local report_file="$1"

    if [ -f "$report_file" ]; then
        jq -c '.notes // []' "$report_file" 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

# ------------------------------
# タスクID処理関数
# ------------------------------

# タスク配列から次のタスクIDカウンターを取得
# 引数: $1=タスクのJSON配列
# 戻り値: 次のタスクIDカウンター番号
get_next_task_id_counter() {
    local tasks="$1"

    if [ "$tasks" = "[]" ] || [ -z "$tasks" ]; then
        echo "1"
        return
    fi

    local max_id=$(echo "$tasks" | jq -r '[.[] | .id | scan("[0-9]+") | tonumber] | max // 0' 2>/dev/null)

    if [ -z "$max_id" ] || [ "$max_id" = "null" ]; then
        echo "1"
    else
        echo $((max_id + 1))
    fi
}

# ------------------------------
# 通知処理関数
# ------------------------------

# macOS通知を表示
# 引数: $1=タイトル、$2=メッセージ、$3=サウンド名（オプション）
show_notification() {
    local title="$1"
    local message="$2"
    local sound="${3:-Basso}"

    osascript -e "display notification \"${message}\" with title \"${title}\" sound name \"${sound}\""
}

# ダイアログで詳細表示の確認を行う
# 引数: $1=メッセージ、$2=タイトル、$3=スクリプトパス、$4=日付
# 戻り値: ユーザーが「はい」を選択した場合は0、それ以外は1
show_dialog_with_details() {
    local message="$1"
    local title="$2"
    local script_path="$3"
    local date="$4"

    local response=$(osascript <<EOF
set response to display dialog "${message}" buttons {"いいえ", "はい"} default button "はい" with title "${title}" with icon note
if button returned of response is "はい" then
    do shell script "'${script_path}' '${date}'"
end if
EOF
)

    return $?
}

# 日報サマリ通知を表示（朝の通知用）
# 引数: $1=日付、$2=日報ファイルパス、$3=通知サウンド、$4=詳細表示スクリプトパス
show_morning_summary_notification() {
    local date="$1"
    local report_file="$2"
    local sound="$3"
    local details_script="$4"

    if [ ! -f "$report_file" ]; then
        show_notification "業務開始 - 昨日のサマリ" "昨日（${date}）の日報がまだ作成されていません。" "$sound"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        show_notification "業務開始 - 昨日のサマリ" "昨日（${date}）の日報を確認しましょう。" "$sound"
        return 1
    fi

    load_report_stats "$report_file"

    local summary="昨日（${date}）の業務サマリ\n"
    summary+="📋 タスク: 完了 ${COMPLETED_TASKS}件 / 未完了 ${PENDING_TASKS}件\n"
    summary+="📝 メモ: ${NOTES_COUNT}件\n"
    summary+="⏱ 総工数: ${TOTAL_HOURS}時間"

    show_notification "業務開始 - 昨日のサマリ" "${summary}" "$sound"

    sleep 1
    show_dialog_with_details "昨日の日報の詳細を表示しますか？" "業務開始リマインダー" "$details_script" "$date"
}

# 日報リマインダー通知を表示（夕方の通知用）
# 引数: $1=日付、$2=日報ファイルパス、$3=通知サウンド、$4=詳細表示スクリプトパス、$5=作業ディレクトリ
show_evening_reminder_notification() {
    local date="$1"
    local report_file="$2"
    local sound="$3"
    local details_script="$4"
    local work_dir="$5"

    if [ ! -f "$report_file" ]; then
        show_notification "業務終了 - 今日の日報を記入" "今日（${date}）の日報がまだ作成されていません。業務内容を記録しましょう。" "$sound"

        # ディレクトリとテンプレートファイルを作成
        local year=$(get_year_from_date "$date")
        local month=$(get_month_from_date "$date")
        mkdir -p "${work_dir}/${year}/${month}"

        cat > "$report_file" <<EOF
{
  "date": "${date}",
  "tasks": [],
  "completed_tasks": [],
  "notes": [],
  "meetings": [],
  "reminders": [],
  "time_tracking": {
    "start_time": null,
    "end_time": null,
    "breaks": []
  }
}
EOF
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        show_notification "業務終了 - 今日の日報を記入" "今日（${date}）の日報を記入しましょう。" "$sound"
        return 1
    fi

    load_report_stats "$report_file"

    local summary
    if [ "$PENDING_TASKS" -gt 0 ]; then
        summary="今日（${date}）の業務を振り返りましょう\n"
        summary+="✅ 完了: ${COMPLETED_TASKS}件\n"
        summary+="⏳ 未完了: ${PENDING_TASKS}件\n"
        summary+="📝 メモ: ${NOTES_COUNT}件\n"
        summary+="⏱ 総工数: ${TOTAL_HOURS}時間"
    else
        summary="今日（${date}）の日報を完成させましょう。\n"
        summary+="総工数: ${TOTAL_HOURS}時間"
    fi

    show_notification "業務終了 - 今日の日報を記入" "${summary}" "$sound"

    sleep 1
    show_dialog_with_details "日報の詳細を表示しますか？" "業務終了リマインダー" "$details_script" "$date"
}

# ------------------------------
# ヘルパー関数
# ------------------------------

# jqがインストールされているかチェック
# 戻り値: インストールされている場合は0、それ以外は1
check_jq_installed() {
    if ! command -v jq &> /dev/null; then
        echo "エラー: jqが必要です。インストールしてください: brew install jq"
        return 1
    fi
    return 0
}

# 日付形式を検証（YYYY-MM-DD）
# 引数: $1=検証する日付文字列
# 戻り値: 正しい形式の場合は0、それ以外は1
validate_date_format() {
    local date="$1"
    if [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        return 0
    else
        echo "エラー: 日付は YYYY-MM-DD 形式で指定してください（例: 2025-11-17）"
        return 1
    fi
}

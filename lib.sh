#!/bin/bash

# 共通関数ライブラリ
# 日報管理スクリプトで使用される共通関数を提供

# ================================================
# 日付処理関連
# ================================================

# 日付を計算する（OS別の対応）
# 引数1: 基準日（YYYY-MM-DD形式、省略時は今日）
# 引数2: 日数オフセット（例: -1 で昨日、+1 で明日）
# 戻り値: 計算された日付（YYYY-MM-DD形式）
calculate_date() {
    local base_date="${1:-$(TZ=Asia/Tokyo date +%Y-%m-%d)}"
    local offset="${2:-0}"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOSの場合
        if [ "$offset" -ne 0 ]; then
            TZ=Asia/Tokyo date -j -v"${offset}d" -f "%Y-%m-%d" "$base_date" +%Y-%m-%d 2>/dev/null
        else
            echo "$base_date"
        fi
    else
        # Linuxの場合
        if [ "$offset" -ne 0 ]; then
            date -d "$base_date $offset day" +%Y-%m-%d
        else
            echo "$base_date"
        fi
    fi
}

# 日付から年を取得
# 引数: 日付（YYYY-MM-DD形式）
# 戻り値: 年（YYYY形式）
get_year_from_date() {
    echo "$1" | cut -d'-' -f1
}

# 日付から月を取得
# 引数: 日付（YYYY-MM-DD形式）
# 戻り値: 月（MM形式）
get_month_from_date() {
    echo "$1" | cut -d'-' -f2
}

# 日報ファイルのパスを取得
# 引数1: 作業ディレクトリ
# 引数2: 日付（YYYY-MM-DD形式）
# 戻り値: 日報ファイルのフルパス
get_report_path() {
    local work_dir="$1"
    local date="$2"
    local year=$(get_year_from_date "$date")
    local month=$(get_month_from_date "$date")
    echo "${work_dir}/${year}/${month}/${date}.json"
}

# ================================================
# 日報読み込み関連
# ================================================

# 日報からタスク統計を取得
# 引数: 日報ファイルのパス
# 戻り値: 連想配列（total_tasks, completed_tasks, pending_tasks, notes_count, total_hours）
get_report_statistics() {
    local report_file="$1"

    if [ ! -f "$report_file" ]; then
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        return 1
    fi

    # 統計情報を取得
    local total_tasks=$(jq '[.tasks + .completed_tasks] | flatten | length' "$report_file" 2>/dev/null)
    local completed_tasks=$(jq '[.completed_tasks] | flatten | length' "$report_file" 2>/dev/null)
    local pending_tasks=$(jq '[.tasks[] | select(.status == "pending" or .status == "in_progress")] | length' "$report_file" 2>/dev/null)
    local notes_count=$(jq '.notes | length' "$report_file" 2>/dev/null)
    local total_hours=$(jq '[.tasks[] | .hours] | add // 0' "$report_file" 2>/dev/null)

    # 結果を環境変数として設定（呼び出し元で使用可能）
    echo "TOTAL_TASKS=$total_tasks"
    echo "COMPLETED_TASKS=$completed_tasks"
    echo "PENDING_TASKS=$pending_tasks"
    echo "NOTES_COUNT=$notes_count"
    echo "TOTAL_HOURS=$total_hours"
}

# ================================================
# タスクID管理関連
# ================================================

# タスクIDカウンターを取得
# 引数: タスク配列のJSON文字列
# 戻り値: 次に使用するタスクID番号
get_next_task_id_counter() {
    local tasks_json="$1"

    if [ "$tasks_json" = "[]" ] || [ -z "$tasks_json" ]; then
        echo "1"
        return
    fi

    local max_id=$(echo "$tasks_json" | jq -r '[.[] | .id | scan("[0-9]+") | tonumber] | max // 0' 2>/dev/null)

    if [ -z "$max_id" ] || [ "$max_id" = "null" ]; then
        echo "1"
    else
        echo "$((max_id + 1))"
    fi
}

# ================================================
# 通知処理関連（macOS専用）
# ================================================

# シンプルな通知を表示
# 引数1: タイトル
# 引数2: メッセージ
# 引数3: サウンド名（省略可）
show_notification() {
    local title="$1"
    local message="$2"
    local sound="${3:-Blow}"

    osascript -e "display notification \"${message}\" with title \"${title}\" sound name \"${sound}\""
}

# 詳細ダイアログを表示し、ユーザーの選択を取得
# 引数1: メッセージ
# 引数2: タイトル
# 引数3: 実行するスクリプトのパス
# 引数4: スクリプトに渡す引数
# 戻り値: ユーザーが「はい」を選択した場合のみスクリプトを実行
show_detail_dialog() {
    local message="$1"
    local title="$2"
    local script_path="$3"
    local script_arg="$4"

    osascript <<EOF
set response to display dialog "${message}" buttons {"いいえ", "はい"} default button "はい" with title "${title}" with icon note
if button returned of response is "はい" then
    do shell script "'${script_path}' '${script_arg}'"
end if
EOF
}

# 日報サマリ通知を表示（統計情報とダイアログ付き）
# 引数1: 日付
# 引数2: 日報ファイルのパス
# 引数3: タイトル
# 引数4: 詳細表示スクリプトのパス
# 引数5: サウンド名（省略可）
show_report_summary_notification() {
    local date="$1"
    local report_file="$2"
    local notification_title="$3"
    local detail_script="$4"
    local sound="${5:-Blow}"

    if [ ! -f "$report_file" ]; then
        show_notification "$notification_title" "${date}の日報がまだ作成されていません。" "$sound"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        show_notification "$notification_title" "${date}の日報を確認しましょう。" "$sound"
        return 1
    fi

    # 統計情報を取得
    eval "$(get_report_statistics "$report_file")"

    # サマリメッセージを構築
    local summary="${date}の業務サマリ\n"
    summary+="📋 タスク: 完了 ${COMPLETED_TASKS}件 / 未完了 ${PENDING_TASKS}件\n"
    summary+="📝 メモ: ${NOTES_COUNT}件\n"
    summary+="⏱ 総工数: ${TOTAL_HOURS}時間"

    # 通知を表示
    show_notification "$notification_title" "$summary" "$sound"

    # 詳細表示のダイアログ
    sleep 1
    show_detail_dialog "日報の詳細を表示しますか？" "$notification_title" "$detail_script" "$date"
}

# ================================================
# JSONファイル操作関連
# ================================================

# 日報ファイルが存在しない場合、ディレクトリを作成
# 引数1: 作業ディレクトリ
# 引数2: 年
# 引数3: 月
ensure_report_directory() {
    local work_dir="$1"
    local year="$2"
    local month="$3"

    mkdir -p "${work_dir}/${year}/${month}"
}

# 空の日報ファイルを作成
# 引数1: 日報ファイルのパス
# 引数2: 日付（YYYY-MM-DD形式）
create_empty_report() {
    local report_file="$1"
    local date="$2"

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
}

# ================================================
# バリデーション関連
# ================================================

# 日付形式の検証（YYYY-MM-DD）
# 引数: 日付文字列
# 戻り値: 0（正常）、1（エラー）
validate_date_format() {
    local date="$1"

    if [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        return 0
    else
        return 1
    fi
}

# jqコマンドの存在チェック
# 戻り値: 0（存在）、1（存在しない）
check_jq_command() {
    if command -v jq &> /dev/null; then
        return 0
    else
        echo "エラー: jqが必要です。インストールしてください: brew install jq" >&2
        return 1
    fi
}

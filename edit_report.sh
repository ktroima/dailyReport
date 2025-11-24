#!/bin/bash

# 日報編集コマンド（簡略版）
# 対話形式で日報を編集します

# 設定ファイルと共通関数を読み込む
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh" 2>/dev/null || WORK_DIR="${SCRIPT_DIR}"
source "${SCRIPT_DIR}/lib.sh"

# 日付の取得（オプション引数があれば使用、なければ今日）
if [ -n "$1" ]; then
    TARGET_DATE="$1"
    # 日付形式の検証（YYYY-MM-DD）
    if ! validate_date_format "$TARGET_DATE"; then
        exit 1
    fi
else
    # 日本時間で今日の日付を取得
    TARGET_DATE=$(get_date_with_offset 0)
fi

YEAR=$(get_year_from_date "$TARGET_DATE")
MONTH=$(get_month_from_date "$TARGET_DATE")
DAILY_REPORT="${WORK_DIR}/${YEAR}/${MONTH}/${TARGET_DATE}.json"

# 翌日の日付を計算
NEXT_DATE=$(calculate_date_from "$TARGET_DATE" +1)
NEXT_YEAR=$(get_year_from_date "$NEXT_DATE")
NEXT_MONTH=$(get_month_from_date "$NEXT_DATE")
NEXT_DAILY_REPORT="${WORK_DIR}/${NEXT_YEAR}/${NEXT_MONTH}/${NEXT_DATE}.json"

# ディレクトリが存在しない場合は作成
mkdir -p "${WORK_DIR}/${YEAR}/${MONTH}"
mkdir -p "${WORK_DIR}/${NEXT_YEAR}/${NEXT_MONTH}"

# jqのチェック
check_jq_installed || exit 1

# 既存の日報を読み込む
TODAY_TASKS=$(load_tasks_from_report "$DAILY_REPORT")
TODAY_NOTES=$(load_notes_from_report "$DAILY_REPORT")

if [ -f "$DAILY_REPORT" ]; then
    echo "既存の日報を読み込みました: ${TARGET_DATE}"
else
    echo "新しい日報を作成します: ${TARGET_DATE}"
fi

# タスクIDのカウンター（既存のタスクから最大IDを取得）
TASK_ID_COUNTER=$(get_next_task_id_counter "$TODAY_TASKS")

# 今日のタスク入力
input_today_tasks() {
    while true; do
        echo ""
        echo "$SEPARATOR_LINE"
        echo "今日（${TARGET_DATE}）行ったタスクを入力"
        echo "$SEPARATOR_LINE"

        if ! read_task_common; then
            ask_continue || break
            continue
        fi

        # 工数
        read -p "工数（時間、例: 2.5）: " task_hours
        if [ -z "$task_hours" ]; then
            task_hours="$DEFAULT_TASK_HOURS"
        fi

        # タスクを追加
        local current_time=$(date +"$DATETIME_FORMAT")
        local task_id="${TASK_ID_PREFIX}$(printf "%0${TASK_ID_PADDING}d" $TASK_ID_COUNTER)"
        TASK_ID_COUNTER=$((TASK_ID_COUNTER + 1))

        local new_task=$(jq -n \
            --arg id "$task_id" \
            --arg title "$task_title" \
            --arg hours "$task_hours" \
            --arg memo "$task_memo" \
            --arg priority "$DEFAULT_PRIORITY" \
            --arg created "$current_time" \
            '{id: $id, title: $title, hours: ($hours | tonumber), memo: $memo, priority: $priority, created_at: $created}')

        TODAY_TASKS=$(echo "$TODAY_TASKS" | jq ". + [$new_task]")
        echo "タスクを追加しました: $task_title (工数: ${task_hours}時間)"

        echo ""
        ask_continue || break
    done
}

# メモ入力
input_notes() {
    echo ""
    echo "$SEPARATOR_LINE"
    echo "1日の総括メモを入力"
    echo "$SEPARATOR_LINE"
    read -p "総括メモ（空欄可）: " summary_note
    if [ -n "$summary_note" ]; then
        TODAY_NOTES=$(echo "$TODAY_NOTES" | jq ". + [\"$summary_note\"]")
        echo "総括メモを追加しました"
    fi
}

# 優先度を選択
select_priority() {
    echo "優先度を選択してください:"
    echo "1) $PRIORITY_LOW"
    echo "2) $PRIORITY_MEDIUM"
    echo "3) $PRIORITY_HIGH"
    read -p "選択 (1-3, デフォルト: 2): " priority_choice
    case "$priority_choice" in
        1) priority="$PRIORITY_LOW" ;;
        3) priority="$PRIORITY_HIGH" ;;
        *) priority="$PRIORITY_MEDIUM" ;;
    esac
}

# 翌日のタスク入力
input_next_day_tasks() {
    # 翌日の既存データを読み込む
    NEXT_DAY_TASKS=$(load_tasks_from_report "$NEXT_DAILY_REPORT")

    # タスクIDのカウンター
    NEXT_TASK_ID_COUNTER=$(get_next_task_id_counter "$NEXT_DAY_TASKS")
    
    echo ""
    echo "$SEPARATOR_LINE"
    echo "翌日（${NEXT_DATE}）行いたいタスクを入力"
    echo "$SEPARATOR_LINE"

    while true; do
        if ! read_task_common; then
            ask_continue || break
            continue
        fi

        # 優先度
        select_priority

        # タスクを追加
        local current_time=$(date +"$DATETIME_FORMAT")
        local task_id="${TASK_ID_PREFIX}$(printf "%0${TASK_ID_PADDING}d" $NEXT_TASK_ID_COUNTER)"
        NEXT_TASK_ID_COUNTER=$((NEXT_TASK_ID_COUNTER + 1))

        local new_task=$(jq -n \
            --arg id "$task_id" \
            --arg title "$task_title" \
            --arg memo "$task_memo" \
            --arg priority "$priority" \
            --arg created "$current_time" \
            '{id: $id, title: $title, memo: $memo, priority: $priority, status: "pending", created_at: $created}')

        NEXT_DAY_TASKS=$(echo "$NEXT_DAY_TASKS" | jq ". + [$new_task]")
        echo "タスクを追加しました: $task_title"

        echo ""
        ask_continue || break
    done
}

# ============================================
# 保存関数
# ============================================

# 今日のJSONファイルを作成
create_today_json() {
    local output_file="$1"
    jq -n \
        --arg date "$TARGET_DATE" \
        --argjson tasks "$TODAY_TASKS" \
        --argjson notes "$TODAY_NOTES" \
        '{
            date: $date,
            tasks: $tasks,
            notes: $notes,
            time_tracking: {
                start_time: null,
                end_time: null,
                breaks: []
            }
        }' > "$output_file"
}

# 翌日のJSONファイルを作成
create_next_day_json() {
    local output_file="$1"
    jq -n \
        --arg date "$NEXT_DATE" \
        --argjson tasks "$NEXT_DAY_TASKS" \
        '{
            date: $date,
            tasks: $tasks,
            notes: [],
            time_tracking: {
                start_time: null,
                end_time: null,
                breaks: []
            }
        }' > "$output_file"
}

# 日報を保存
save_report() {
    # 今日の日報を保存
    echo ""
    echo "今日の日報を保存しています..."
    create_today_json "$DAILY_REPORT"
    echo "日報を保存しました: ${DAILY_REPORT}"

    # 翌日のタスクを保存
    echo ""
    echo "翌日のタスクを保存しています..."
    create_next_day_json "$NEXT_DAILY_REPORT"
    echo "タスクを保存しました: ${NEXT_DAILY_REPORT}"
}

# ============================================
# メイン処理
# ============================================

main() {
    # 1. ディレクトリとデータの初期化
    setup_directories "$1"

    echo "$SEPARATOR_LINE"
    echo "日報入力: ${TARGET_DATE}"
    echo "$SEPARATOR_LINE"

    # 2. 今日のタスク入力
    input_today_tasks

    # 3. 1日の総括メモを入力
    input_notes

    # 4. 翌日のタスク入力
    input_next_day_tasks

    # 5. 日報を保存
    save_report

    echo ""
    echo "日報の入力が完了しました！"
}

# スクリプト実行
main "$@"

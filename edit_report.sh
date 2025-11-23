#!/bin/bash

# 日報編集コマンド（簡略版）
# 対話形式で日報を編集します

# 設定ファイルを読み込む
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh" 2>/dev/null || WORK_DIR="${SCRIPT_DIR}"

# ============================================
# グローバル変数の初期化
# ============================================

# 日付関連の変数
TARGET_DATE=""
NEXT_DATE=""
YEAR=""
MONTH=""
NEXT_YEAR=""
NEXT_MONTH=""
DAILY_REPORT=""
NEXT_DAILY_REPORT=""

# タスク・メモ関連の変数
TODAY_TASKS=""
TODAY_NOTES=""
NEXT_DAY_TASKS=""
TASK_ID_COUNTER=""
NEXT_TASK_ID_COUNTER=""

# ============================================
# ユーティリティ関数
# ============================================

# 日付の検証
validate_date() {
    local date="$1"
    if ! [[ "$date" =~ $DATE_REGEX ]]; then
        echo "エラー: 日付は YYYY-MM-DD 形式で指定してください（例: 2025-11-17）"
        exit 1
    fi
}

# 翌日の日付を計算
calculate_next_date() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOSの場合
        NEXT_DATE=$(TZ="$TIMEZONE" date -j -v+1d -f "$DATE_FORMAT" "$TARGET_DATE" +"$DATE_FORMAT" 2>/dev/null)
        if [ -z "$NEXT_DATE" ]; then
            # フォールバック: 今日から1日後を計算
            NEXT_DATE=$(TZ="$TIMEZONE" date -v+1d +"$DATE_FORMAT")
        fi
    else
        # Linuxの場合
        NEXT_DATE=$(date -d "$TARGET_DATE +1 day" +"$DATE_FORMAT")
    fi
}

# タスクIDカウンターの初期化
init_task_counter() {
    local tasks="$1"
    if [ "$tasks" != "$EMPTY_JSON_ARRAY" ]; then
        local counter=$(echo "$tasks" | jq -r "[.[] | .id | scan(\"[0-9]+\") | tonumber] | max // 0" | awk '{print $1+1}')
        if [ -z "$counter" ] || [ "$counter" = "null" ]; then
            echo "$DEFAULT_TASK_COUNTER"
        else
            echo "$counter"
        fi
    else
        echo "$DEFAULT_TASK_COUNTER"
    fi
}

# ============================================
# セットアップ関数
# ============================================

# ディレクトリ初期化
setup_directories() {
    # 日付の取得（オプション引数があれば使用、なければ今日）
    if [ -n "$1" ]; then
        TARGET_DATE="$1"
        validate_date "$TARGET_DATE"
    else
        # 日本時間で今日の日付を取得
        TARGET_DATE=$(TZ="$TIMEZONE" date +"$DATE_FORMAT")
    fi

    # 年月日を分解
    YEAR=$(echo "$TARGET_DATE" | cut -d'-' -f1)
    MONTH=$(echo "$TARGET_DATE" | cut -d'-' -f2)
    DAILY_REPORT="${WORK_DIR}/${YEAR}/${MONTH}/${TARGET_DATE}.json"

    # 翌日の日付を計算
    calculate_next_date
    NEXT_YEAR=$(echo "$NEXT_DATE" | cut -d'-' -f1)
    NEXT_MONTH=$(echo "$NEXT_DATE" | cut -d'-' -f2)
    NEXT_DAILY_REPORT="${WORK_DIR}/${NEXT_YEAR}/${NEXT_MONTH}/${NEXT_DATE}.json"

    # ディレクトリが存在しない場合は作成
    mkdir -p "${WORK_DIR}/${YEAR}/${MONTH}"
    mkdir -p "${WORK_DIR}/${NEXT_YEAR}/${NEXT_MONTH}"

    # jqのチェック
    if ! command -v jq &> /dev/null; then
        echo "エラー: jqが必要です。インストールしてください: brew install jq"
        exit 1
    fi

    # 既存の日報を読み込む
    if [ -f "$DAILY_REPORT" ]; then
        TODAY_TASKS=$(jq -c ".tasks // $EMPTY_JSON_ARRAY" "$DAILY_REPORT" 2>/dev/null || echo "$EMPTY_JSON_ARRAY")
        TODAY_NOTES=$(jq -c ".notes // $EMPTY_JSON_ARRAY" "$DAILY_REPORT" 2>/dev/null || echo "$EMPTY_JSON_ARRAY")
        echo "既存の日報を読み込みました: ${TARGET_DATE}"
    else
        TODAY_TASKS="$EMPTY_JSON_ARRAY"
        TODAY_NOTES="$EMPTY_JSON_ARRAY"
        echo "新しい日報を作成します: ${TARGET_DATE}"
    fi

    # タスクIDカウンターの初期化
    TASK_ID_COUNTER=$(init_task_counter "$TODAY_TASKS")
}

# ============================================
# 入力関数
# ============================================

# タスク入力の共通処理
read_task_common() {
    # タスクタイトル
    read -p "タスクタイトル: " task_title
    if [ -z "$task_title" ]; then
        echo "タスクタイトルが空のため、スキップします。"
        return 1
    fi

    # メモ
    read -p "メモ（空欄可）: " task_memo
    return 0
}

# 続行確認
ask_continue() {
    read -p "タスクを追加しますか？ (y/n): " add_more
    if [ "$add_more" != "y" ] && [ "$add_more" != "Y" ]; then
        return 1
    fi
    return 0
}

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
    if [ -f "$NEXT_DAILY_REPORT" ]; then
        NEXT_DAY_TASKS=$(jq -c ".tasks // $EMPTY_JSON_ARRAY" "$NEXT_DAILY_REPORT" 2>/dev/null || echo "$EMPTY_JSON_ARRAY")
    else
        NEXT_DAY_TASKS="$EMPTY_JSON_ARRAY"
    fi

    # タスクIDカウンターの初期化
    NEXT_TASK_ID_COUNTER=$(init_task_counter "$NEXT_DAY_TASKS")

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

#!/bin/bash

# 日報編集コマンド（簡略版）
# 対話形式で日報を編集します

# 設定ファイルを読み込む
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh" 2>/dev/null || WORK_DIR="${SCRIPT_DIR}"

# 日付の取得（オプション引数があれば使用、なければ今日）
if [ -n "$1" ]; then
    TARGET_DATE="$1"
    # 日付形式の検証（YYYY-MM-DD）
    if ! [[ "$TARGET_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "エラー: 日付は YYYY-MM-DD 形式で指定してください（例: 2025-11-17）"
        exit 1
    fi
else
    # 日本時間で今日の日付を取得
    TARGET_DATE=$(TZ=Asia/Tokyo date +%Y-%m-%d)
fi

YEAR=$(echo "$TARGET_DATE" | cut -d'-' -f1)
MONTH=$(echo "$TARGET_DATE" | cut -d'-' -f2)
DAILY_REPORT="${WORK_DIR}/${YEAR}/${MONTH}/${TARGET_DATE}.json"

# 翌日の日付を計算（macOS用）
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOSの場合
    NEXT_DATE=$(TZ=Asia/Tokyo date -j -v+1d -f "%Y-%m-%d" "$TARGET_DATE" +%Y-%m-%d 2>/dev/null)
    if [ -z "$NEXT_DATE" ]; then
        # フォールバック: 今日から1日後を計算
        NEXT_DATE=$(TZ=Asia/Tokyo date -v+1d +%Y-%m-%d)
    fi
else
    # Linuxの場合
    NEXT_DATE=$(date -d "$TARGET_DATE +1 day" +%Y-%m-%d)
fi
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
    TODAY_TASKS=$(jq -c '.tasks // []' "$DAILY_REPORT" 2>/dev/null || echo "[]")
    TODAY_NOTES=$(jq -c '.notes // []' "$DAILY_REPORT" 2>/dev/null || echo "[]")
    echo "既存の日報を読み込みました: ${TARGET_DATE}"
else
    TODAY_TASKS="[]"
    TODAY_NOTES="[]"
    echo "新しい日報を作成します: ${TARGET_DATE}"
fi

# タスクIDのカウンター（既存のタスクから最大IDを取得）
if [ "$TODAY_TASKS" != "[]" ]; then
    TASK_ID_COUNTER=$(echo "$TODAY_TASKS" | jq -r '[.[] | .id | scan("[0-9]+") | tonumber] | max // 0' | awk '{print $1+1}')
    if [ -z "$TASK_ID_COUNTER" ] || [ "$TASK_ID_COUNTER" = "null" ]; then
        TASK_ID_COUNTER=1
    fi
else
    TASK_ID_COUNTER=1
fi

# 今日のタスク入力ループ
input_today_tasks() {
    while true; do
        echo ""
        echo "=========================================="
        echo "今日（${TARGET_DATE}）行ったタスクを入力"
        echo "=========================================="
        
        # タスクタイトル
        read -p "タスクタイトル: " task_title
        if [ -z "$task_title" ]; then
            echo "タスクタイトルが空のため、スキップします。"
            read -p "タスクを追加しますか？ (y/n): " add_more
            if [ "$add_more" != "y" ] && [ "$add_more" != "Y" ]; then
                break
            fi
            continue
        fi
        
        # メモ
        read -p "メモ（空欄可）: " task_memo
        
        # 工数
        read -p "工数（時間、例: 2.5）: " task_hours
        if [ -z "$task_hours" ]; then
            task_hours="0"
        fi
        
        # タスクを追加
        current_time=$(date +%Y-%m-%dT%H:%M:%S)
        task_id="task-$(printf "%03d" $TASK_ID_COUNTER)"
        TASK_ID_COUNTER=$((TASK_ID_COUNTER + 1))
        
        new_task=$(jq -n \
            --arg id "$task_id" \
            --arg title "$task_title" \
            --arg hours "$task_hours" \
            --arg memo "$task_memo" \
            --arg priority "$priority" \
            --arg created "$current_time" \
            '{id: $id, title: $title, hours: ($hours | tonumber), memo: $memo, priority: $priority, created_at: $created}')
        
        TODAY_TASKS=$(echo "$TODAY_TASKS" | jq ". + [$new_task]")
        echo "タスクを追加しました: $task_title (工数: ${task_hours}時間)"
        
        # タスクを追加するか確認
        echo ""
        read -p "タスクを追加しますか？ (y/n): " add_more
        if [ "$add_more" != "y" ] && [ "$add_more" != "Y" ]; then
            break
        fi
    done
}

# 1日の総括メモを入力
input_summary_note() {
    echo ""
    echo "=========================================="
    echo "1日の総括メモを入力"
    echo "=========================================="
    read -p "総括メモ（空欄可）: " summary_note
    if [ -n "$summary_note" ]; then
        TODAY_NOTES=$(echo "$TODAY_NOTES" | jq ". + [\"$summary_note\"]")
        echo "総括メモを追加しました"
    fi
}

# 翌日のタスク入力
input_next_day_tasks() {
    # 翌日の既存データを読み込む
    if [ -f "$NEXT_DAILY_REPORT" ]; then
        NEXT_DAY_TASKS=$(jq -c '.tasks // []' "$NEXT_DAILY_REPORT" 2>/dev/null || echo "[]")
    else
        NEXT_DAY_TASKS="[]"
    fi
    
    # タスクIDのカウンター
    if [ "$NEXT_DAY_TASKS" != "[]" ]; then
        NEXT_TASK_ID_COUNTER=$(echo "$NEXT_DAY_TASKS" | jq -r '[.[] | .id | scan("[0-9]+") | tonumber] | max // 0' | awk '{print $1+1}')
        if [ -z "$NEXT_TASK_ID_COUNTER" ] || [ "$NEXT_TASK_ID_COUNTER" = "null" ]; then
            NEXT_TASK_ID_COUNTER=1
        fi
    else
        NEXT_TASK_ID_COUNTER=1
    fi
    
    echo ""
    echo "=========================================="
    echo "翌日（${NEXT_DATE}）行いたいタスクを入力"
    echo "=========================================="
    
    while true; do
        # タスクタイトル
        read -p "タスクタイトル: " task_title
        if [ -z "$task_title" ]; then
            echo "タスクタイトルが空のため、スキップします。"
            read -p "タスクを追加しますか？ (y/n): " add_more
            if [ "$add_more" != "y" ] && [ "$add_more" != "Y" ]; then
                break
            fi
            continue
        fi
        
        # メモ
        read -p "メモ（空欄可）: " task_memo
        
        # 優先度
        echo "優先度を選択してください:"
        echo "1) low"
        echo "2) medium"
        echo "3) high"
        read -p "選択 (1-3, デフォルト: 2): " priority_choice
        case "$priority_choice" in
            1) priority="low" ;;
            3) priority="high" ;;
            *) priority="medium" ;;
        esac
        
        # タスクを追加
        current_time=$(date +%Y-%m-%dT%H:%M:%S)
        task_id="task-$(printf "%03d" $NEXT_TASK_ID_COUNTER)"
        NEXT_TASK_ID_COUNTER=$((NEXT_TASK_ID_COUNTER + 1))
        
        new_task=$(jq -n \
            --arg id "$task_id" \
            --arg title "$task_title" \
            --arg memo "$task_memo" \
            --arg priority "$priority" \
            --arg created "$current_time" \
            '{id: $id, title: $title, memo: $memo, priority: $priority, status: "pending", created_at: $created}')
        
        NEXT_DAY_TASKS=$(echo "$NEXT_DAY_TASKS" | jq ". + [$new_task]")
        echo "タスクを追加しました: $task_title"
        
        # タスクを追加するか確認
        echo ""
        read -p "タスクを追加しますか？ (y/n): " add_more
        if [ "$add_more" != "y" ] && [ "$add_more" != "Y" ]; then
            break
        fi
    done
}

# 今日のJSONファイルを作成
create_today_json_file() {
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
create_next_day_json_file() {
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

# 今日の日報を保存
save_today_report() {
    echo ""
    echo "今日の日報を保存しています..."
    create_today_json_file "$DAILY_REPORT"
    echo "日報を保存しました: ${DAILY_REPORT}"
}

# 翌日の日報を保存
save_next_day_report() {
    echo ""
    echo "翌日のタスクを保存しています..."
    create_next_day_json_file "$NEXT_DAILY_REPORT"
    echo "タスクを保存しました: ${NEXT_DAILY_REPORT}"
}

# メイン処理
echo "=========================================="
echo "日報入力: ${TARGET_DATE}"
echo "=========================================="

# 1. 今日のタスク入力
input_today_tasks

# 2. 1日の総括メモを入力
input_summary_note

# 3. 今日の日報を保存
save_today_report

# 4. 翌日のタスク入力
input_next_day_tasks

# 5. 翌日のタスクを保存
save_next_day_report

echo ""
echo "日報の入力が完了しました！"

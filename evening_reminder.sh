#!/bin/bash

# 業務終了時の今日の日報記入リマインダースクリプト
# launchdから定時実行され、今日の日報記入を促す通知を表示します

# 設定ファイルを読み込む
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# 今日の日付と日報ファイルパスを取得
TODAY=$(date +%Y-%m-%d)
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAILY_REPORT="${WORK_DIR}/${YEAR}/${MONTH}/${TODAY}.json"

# 今日の日報ファイルが存在するかチェック
if [ -f "$DAILY_REPORT" ]; then
    # jqが使える場合、タスクの状況を確認
    if command -v jq &> /dev/null; then
        TOTAL_TASKS=$(jq '[.tasks + .completed_tasks] | flatten | length' "$DAILY_REPORT" 2>/dev/null)
        COMPLETED_TASKS=$(jq '[.completed_tasks] | flatten | length' "$DAILY_REPORT" 2>/dev/null)
        PENDING_TASKS=$(jq '[.tasks[] | select(.status == "pending" or .status == "in_progress")] | length' "$DAILY_REPORT" 2>/dev/null)
        NOTES_COUNT=$(jq '.notes | length' "$DAILY_REPORT" 2>/dev/null)
        
        # タスクの詳細を取得
        TASK_LIST=$(jq -r '.tasks[] | "・\(.title) (\(.hours)時間)"' "$DAILY_REPORT" 2>/dev/null | head -3 | tr '\n' ' ')
        TOTAL_HOURS=$(jq '[.tasks[] | .hours] | add // 0' "$DAILY_REPORT" 2>/dev/null)
        
        if [ "$PENDING_TASKS" -gt 0 ]; then
            SUMMARY="今日（${TODAY}）の業務を振り返りましょう\n"
            SUMMARY+="✅ 完了: ${COMPLETED_TASKS}件\n"
            SUMMARY+="⏳ 未完了: ${PENDING_TASKS}件\n"
            SUMMARY+="📝 メモ: ${NOTES_COUNT}件\n"
            SUMMARY+="⏱ 総工数: ${TOTAL_HOURS}時間"
            
            # 通知を表示（クリックで詳細表示）
            osascript -e "display notification \"${SUMMARY}\" with title \"業務終了 - 今日の日報を記入\" sound name \"${NOTIFICATION_SOUND}\""
            
            # 通知の後に詳細表示のオプションを提供
            sleep 1
            osascript <<EOF
set response to display dialog "日報の詳細を表示しますか？" buttons {"いいえ", "はい"} default button "はい" with title "業務終了リマインダー" with icon note
if button returned of response is "はい" then
    do shell script "'${WORK_DIR}/show_report_details.sh' '${TODAY}'"
end if
EOF
        else
            SUMMARY="今日（${TODAY}）の日報を完成させましょう。\n"
            SUMMARY+="総工数: ${TOTAL_HOURS}時間"
            
            osascript -e "display notification \"${SUMMARY}\" with title \"業務終了 - 今日の日報を記入\" sound name \"${NOTIFICATION_SOUND}\""
            
            # 通知の後に詳細表示のオプションを提供
            sleep 1
            osascript <<EOF
set response to display dialog "日報の詳細を表示しますか？" buttons {"いいえ", "はい"} default button "はい" with title "業務終了リマインダー" with icon note
if button returned of response is "はい" then
    do shell script "'${WORK_DIR}/show_report_details.sh' '${TODAY}'"
end if
EOF
        fi
    else
        # jqが使えない場合、シンプルな通知
        osascript -e "display notification \"今日（${TODAY}）の日報を記入しましょう。\" with title \"業務終了 - 今日の日報を記入\" sound name \"${NOTIFICATION_SOUND}\""
    fi
else
    # 今日の日報が存在しない場合
    osascript -e "display notification \"今日（${TODAY}）の日報がまだ作成されていません。業務内容を記録しましょう。\" with title \"業務終了 - 今日の日報を記入\" sound name \"${NOTIFICATION_SOUND}\""

    # ディレクトリが存在しない場合は作成
    mkdir -p "${WORK_DIR}/${YEAR}/${MONTH}"

    # 空の日報ファイルを作成（テンプレート）
    # HEREDOCを使用してJSONテンプレートを生成
    # このテンプレートは後でedit_report.shで編集される
    cat > "$DAILY_REPORT" <<EOF
{
  "date": "${TODAY}",
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
fi


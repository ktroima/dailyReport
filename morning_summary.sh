#!/bin/bash

# 業務開始時の昨日の日報サマリ表示スクリプト

# 設定ファイルを読み込む
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)
YEAR=$(date -v-1d +%Y 2>/dev/null || date -d "yesterday" +%Y)
MONTH=$(date -v-1d +%m 2>/dev/null || date -d "yesterday" +%m)
YESTERDAY_REPORT="${WORK_DIR}/${YEAR}/${MONTH}/${YESTERDAY}.json"

# 昨日の日報ファイルが存在するかチェック
if [ -f "$YESTERDAY_REPORT" ]; then
    # jqが使える場合、詳細なサマリを表示
    if command -v jq &> /dev/null; then
        TOTAL_TASKS=$(jq '[.tasks + .completed_tasks] | flatten | length' "$YESTERDAY_REPORT" 2>/dev/null)
        COMPLETED_TASKS=$(jq '[.completed_tasks] | flatten | length' "$YESTERDAY_REPORT" 2>/dev/null)
        PENDING_TASKS=$(jq '[.tasks[] | select(.status == "pending" or .status == "in_progress")] | length' "$YESTERDAY_REPORT" 2>/dev/null)
        NOTES_COUNT=$(jq '.notes | length' "$YESTERDAY_REPORT" 2>/dev/null)
        
        # タスクの詳細を取得
        TASK_LIST=$(jq -r '.tasks[] | "・\(.title) (\(.hours)時間)"' "$YESTERDAY_REPORT" 2>/dev/null | head -3 | tr '\n' ' ')
        TOTAL_HOURS=$(jq '[.tasks[] | .hours] | add // 0' "$YESTERDAY_REPORT" 2>/dev/null)
        
        SUMMARY="昨日（${YESTERDAY}）の業務サマリ\n"
        SUMMARY+="📋 タスク: 完了 ${COMPLETED_TASKS}件 / 未完了 ${PENDING_TASKS}件\n"
        SUMMARY+="📝 メモ: ${NOTES_COUNT}件\n"
        SUMMARY+="⏱ 総工数: ${TOTAL_HOURS}時間"
        
        # 通知を表示（クリックで詳細表示）
        osascript -e "display notification \"${SUMMARY}\" with title \"業務開始 - 昨日のサマリ\" sound name \"${NOTIFICATION_SOUND}\""
        
        # 通知の後に詳細表示のオプションを提供
        sleep 1
        osascript <<EOF
set response to display dialog "昨日の日報の詳細を表示しますか？" buttons {"いいえ", "はい"} default button "はい" with title "業務開始リマインダー" with icon note
if button returned of response is "はい" then
    do shell script "'${WORK_DIR}/show_report_details.sh' '${YESTERDAY}'"
end if
EOF
    else
        # jqが使えない場合、シンプルな通知
        osascript -e "display notification \"昨日（${YESTERDAY}）の日報を確認しましょう。\" with title \"業務開始 - 昨日のサマリ\" sound name \"${NOTIFICATION_SOUND}\""
    fi
else
    # 昨日の日報が存在しない場合
    osascript -e "display notification \"昨日（${YESTERDAY}）の日報がまだ作成されていません。\" with title \"業務開始 - 昨日のサマリ\" sound name \"${NOTIFICATION_SOUND}\""
fi


#!/bin/bash

# 日報の詳細を表示するスクリプト
# 通知ダイアログから呼び出され、日報の詳細をダイアログで表示します
# 使い方: ./show_report_details.sh [YYYY-MM-DD]

# 設定ファイルを読み込む
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh" 2>/dev/null || WORK_DIR="${SCRIPT_DIR}"

# 日付の取得（オプション引数があれば使用、なければ今日）
if [ -n "$1" ]; then
    TARGET_DATE="$1"
else
    # 日本時間で今日の日付を取得
    TARGET_DATE=$(TZ=Asia/Tokyo date +%Y-%m-%d)
fi

YEAR=$(echo "$TARGET_DATE" | cut -d'-' -f1)
MONTH=$(echo "$TARGET_DATE" | cut -d'-' -f2)
DAILY_REPORT="${WORK_DIR}/${YEAR}/${MONTH}/${TARGET_DATE}.json"

# jqのチェック
if ! command -v jq &> /dev/null; then
    osascript -e "display dialog \"jqが必要です。インストールしてください: brew install jq\" buttons {\"OK\"} default button \"OK\""
    exit 1
fi

# 日報ファイルが存在するかチェック
if [ ! -f "$DAILY_REPORT" ]; then
    osascript -e "display dialog \"日報ファイルが見つかりません: ${TARGET_DATE}\" buttons {\"OK\"} default button \"OK\""
    exit 1
fi

# 日報の詳細を取得
TASKS=$(jq -r '.tasks // []' "$DAILY_REPORT" 2>/dev/null)
NOTES=$(jq -r '.notes // []' "$DAILY_REPORT" 2>/dev/null)

# タスクの詳細を整形
TASK_DETAILS=""
if [ "$TASKS" != "[]" ] && [ -n "$TASKS" ]; then
    TASK_COUNT=$(echo "$TASKS" | jq 'length')
    TASK_DETAILS="📋 タスク一覧 (${TASK_COUNT}件):\n\n"

    # 一時ファイルを使用してタスク詳細を取得
    # jqの-rオプション: raw出力（引用符なし）
    # if .memo != "" and .memo != null: メモが存在する場合のみ表示
    TASK_TEMP=$(mktemp)
    echo "$TASKS" | jq -r '.[] | "・\(.title)\n  工数: \(.hours)時間 | 優先度: \(.priority)\n  \(if .memo != "" and .memo != null then "メモ: \(.memo)" else "" end)\n"' > "$TASK_TEMP"
    TASK_DETAILS+=$(cat "$TASK_TEMP")
    rm "$TASK_TEMP"
    TASK_DETAILS+="\n"
fi

# メモの詳細を整形
NOTE_DETAILS=""
if [ "$NOTES" != "[]" ] && [ -n "$NOTES" ]; then
    NOTE_COUNT=$(echo "$NOTES" | jq 'length')
    NOTE_DETAILS="📝 メモ (${NOTE_COUNT}件):\n\n"
    
    # 一時ファイルを使用してメモ詳細を取得
    NOTE_TEMP=$(mktemp)
    echo "$NOTES" | jq -r '.[] | "・\(.)"' > "$NOTE_TEMP"
    NOTE_DETAILS+=$(cat "$NOTE_TEMP")
    rm "$NOTE_TEMP"
    NOTE_DETAILS+="\n"
fi

# 総工数を計算
TOTAL_HOURS=$(echo "$TASKS" | jq '[.[] | .hours] | add // 0' 2>/dev/null)

# 詳細メッセージを構築
DETAIL_MESSAGE="日付: ${TARGET_DATE}\n"
DETAIL_MESSAGE+="総工数: ${TOTAL_HOURS}時間\n\n"
DETAIL_MESSAGE+="${TASK_DETAILS}"
DETAIL_MESSAGE+="${NOTE_DETAILS}"

# ダイアログで表示（長い場合はスクロール可能）
# メッセージをエスケープ
# sed: シングルクォートとダブルクォートをエスケープ（osascript用）
ESCAPED_MESSAGE=$(echo "$DETAIL_MESSAGE" | sed "s/'/\\\\'/g" | sed 's/"/\\"/g')

# osascriptでダイアログを表示
# AppleScriptの処理内容:
# 1. メッセージが長い場合（1000文字以上）は切り詰める
# 2. display dialog: ダイアログを表示
# 3. giving up after 30: 30秒後に自動的に閉じる
# 4. "ファイルを開く"ボタンでJSONファイルを開く
osascript <<EOF
set detailText to "${ESCAPED_MESSAGE}"
set maxLength to 1000
if length of detailText > maxLength then
    set detailText to text 1 thru maxLength of detailText & "\n\n(内容が長いため一部を表示しています)"
end if
try
    set response to display dialog detailText buttons {"閉じる", "ファイルを開く"} default button "閉じる" with title "日報詳細: ${TARGET_DATE}" with icon note giving up after 30
    if button returned of response is "ファイルを開く" then
        do shell script "open '${DAILY_REPORT}'"
    end if
on error
    -- タイムアウトまたはキャンセル
end try
EOF


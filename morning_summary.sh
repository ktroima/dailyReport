#!/bin/bash

# 業務開始時の昨日の日報サマリ表示スクリプト
# launchdから定時実行され、昨日の業務内容を通知で表示します

# 設定ファイルを読み込む
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# 昨日の日付を計算（macOS/Linux互換）
# macOSの場合: date -v-1d
# Linuxの場合: date -d "yesterday"
YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)
YEAR=$(date -v-1d +%Y 2>/dev/null || date -d "yesterday" +%Y)
MONTH=$(date -v-1d +%m 2>/dev/null || date -d "yesterday" +%m)
YESTERDAY_REPORT="${WORK_DIR}/${YEAR}/${MONTH}/${YESTERDAY}.json"

# 昨日の日報ファイルが存在するかチェック
if [ -f "$YESTERDAY_REPORT" ]; then
    # jqが使える場合、詳細なサマリを表示
    if command -v jq &> /dev/null; then
        # 各種統計情報をjqで集計
        # .tasks + .completed_tasks: 両配列を結合
        # flatten: ネストした配列を平坦化
        # length: 配列の長さを取得
        TOTAL_TASKS=$(jq '[.tasks + .completed_tasks] | flatten | length' "$YESTERDAY_REPORT" 2>/dev/null)
        COMPLETED_TASKS=$(jq '[.completed_tasks] | flatten | length' "$YESTERDAY_REPORT" 2>/dev/null)

        # select(.status == "pending" or .status == "in_progress"): 未完了タスクをフィルタリング
        PENDING_TASKS=$(jq '[.tasks[] | select(.status == "pending" or .status == "in_progress")] | length' "$YESTERDAY_REPORT" 2>/dev/null)
        NOTES_COUNT=$(jq '.notes | length' "$YESTERDAY_REPORT" 2>/dev/null)

        # タスクの詳細を取得（最初の3件のみ）
        # -r: raw出力（引用符なし）
        # head -3: 最初の3行のみ
        # tr '\n' ' ': 改行をスペースに変換
        TASK_LIST=$(jq -r '.tasks[] | "・\(.title) (\(.hours)時間)"' "$YESTERDAY_REPORT" 2>/dev/null | head -3 | tr '\n' ' ')

        # [.tasks[] | .hours]: 全タスクの工数を配列化
        # add // 0: 合計を計算、配列が空の場合は0
        TOTAL_HOURS=$(jq '[.tasks[] | .hours] | add // 0' "$YESTERDAY_REPORT" 2>/dev/null)
        
        SUMMARY="昨日（${YESTERDAY}）の業務サマリ\n"
        SUMMARY+="📋 タスク: 完了 ${COMPLETED_TASKS}件 / 未完了 ${PENDING_TASKS}件\n"
        SUMMARY+="📝 メモ: ${NOTES_COUNT}件\n"
        SUMMARY+="⏱ 総工数: ${TOTAL_HOURS}時間"
        
        # osascriptでmacOS通知を表示
        # display notification: 通知センターに通知を表示
        # with title: 通知のタイトル
        # sound name: 通知音（config.shで設定）
        osascript -e "display notification \"${SUMMARY}\" with title \"業務開始 - 昨日のサマリ\" sound name \"${NOTIFICATION_SOUND}\""

        # 通知の後に詳細表示のオプションを提供
        # sleep: 通知が表示されるまで少し待つ
        sleep 1

        # osascriptでダイアログを表示
        # display dialog: ユーザーに選択肢を提示
        # button returned: ユーザーが選択したボタンを取得
        # do shell script: シェルスクリプトを実行（詳細表示スクリプトを起動）
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


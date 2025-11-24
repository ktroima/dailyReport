#!/bin/bash

# 業務開始時の昨日の日報サマリ表示スクリプト

# 設定ファイルと共通関数を読み込む
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib.sh"

# 昨日の日付を取得
YESTERDAY=$(get_date_with_offset -1)
YEAR=$(get_year_from_date "$YESTERDAY")
MONTH=$(get_month_from_date "$YESTERDAY")
YESTERDAY_REPORT="${WORK_DIR}/${YEAR}/${MONTH}/${YESTERDAY}.json"

# 昨日の日報サマリ通知を表示
show_morning_summary_notification "$YESTERDAY" "$YESTERDAY_REPORT" "$NOTIFICATION_SOUND" "${WORK_DIR}/show_report_details.sh"


#!/bin/bash

# 業務終了時の今日の日報記入リマインダースクリプト

# 設定ファイルと共通関数を読み込む
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib.sh"

# 今日の日付を取得
TODAY=$(get_date_with_offset 0)
YEAR=$(get_year_from_date "$TODAY")
MONTH=$(get_month_from_date "$TODAY")
DAILY_REPORT="${WORK_DIR}/${YEAR}/${MONTH}/${TODAY}.json"

# 今日の日報リマインダー通知を表示
show_evening_reminder_notification "$TODAY" "$DAILY_REPORT" "$NOTIFICATION_SOUND" "${WORK_DIR}/show_report_details.sh" "$WORK_DIR"


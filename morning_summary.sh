#!/bin/bash

# 業務開始時の昨日の日報サマリ表示スクリプト

# 設定ファイルと共通関数ライブラリを読み込む
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib.sh"

# 昨日の日付を計算
YESTERDAY=$(calculate_date "$(TZ=Asia/Tokyo date +%Y-%m-%d)" -1)
YESTERDAY_REPORT=$(get_report_path "$WORK_DIR" "$YESTERDAY")

# 昨日の日報サマリ通知を表示
show_report_summary_notification \
    "$YESTERDAY" \
    "$YESTERDAY_REPORT" \
    "業務開始 - 昨日のサマリ" \
    "${WORK_DIR}/show_report_details.sh" \
    "${NOTIFICATION_SOUND}"


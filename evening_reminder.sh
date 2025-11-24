#!/bin/bash

# 業務終了時の今日の日報記入リマインダースクリプト

# 設定ファイルと共通関数ライブラリを読み込む
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib.sh"

# 今日の日付を取得
TODAY=$(TZ=Asia/Tokyo date +%Y-%m-%d)
DAILY_REPORT=$(get_report_path "$WORK_DIR" "$TODAY")

# 今日の日報ファイルが存在するかチェック
if [ -f "$DAILY_REPORT" ]; then
    # 日報サマリ通知を表示
    show_report_summary_notification \
        "$TODAY" \
        "$DAILY_REPORT" \
        "業務終了 - 今日の日報を記入" \
        "${WORK_DIR}/show_report_details.sh" \
        "${NOTIFICATION_SOUND}"
else
    # 今日の日報が存在しない場合
    show_notification \
        "業務終了 - 今日の日報を記入" \
        "今日（${TODAY}）の日報がまだ作成されていません。業務内容を記録しましょう。" \
        "${NOTIFICATION_SOUND}"

    # ディレクトリとテンプレートファイルを作成
    YEAR=$(get_year_from_date "$TODAY")
    MONTH=$(get_month_from_date "$TODAY")
    ensure_report_directory "$WORK_DIR" "$YEAR" "$MONTH"
    create_empty_report "$DAILY_REPORT" "$TODAY"
fi


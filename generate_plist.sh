#!/bin/bash

# plistファイル生成スクリプト
# config.shの設定を読み込んで、launchd用のplistファイルを生成します

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# 業務開始時リマインダーのplist生成
cat > "${SCRIPT_DIR}/com.workmanagement.morning.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.workmanagement.morning</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${WORK_DIR}/morning_summary.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>${MORNING_HOUR}</integer>
        <key>Minute</key>
        <integer>${MORNING_MINUTE}</integer>
    </dict>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>${WORK_DIR}/morning.log</string>
    <key>StandardErrorPath</key>
    <string>${WORK_DIR}/morning.error.log</string>
</dict>
</plist>
EOF

# 業務終了時リマインダーのplist生成
cat > "${SCRIPT_DIR}/com.workmanagement.evening.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.workmanagement.evening</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${WORK_DIR}/evening_reminder.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>${EVENING_HOUR}</integer>
        <key>Minute</key>
        <integer>${EVENING_MINUTE}</integer>
    </dict>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>${WORK_DIR}/evening.log</string>
    <key>StandardErrorPath</key>
    <string>${WORK_DIR}/evening.error.log</string>
</dict>
</plist>
EOF

echo "plistファイルを生成しました:"
echo "  - com.workmanagement.morning.plist (${MORNING_HOUR}:${MORNING_MINUTE})"
echo "  - com.workmanagement.evening.plist (${EVENING_HOUR}:${EVENING_MINUTE})"



#!/bin/bash

# 月次サマリスクリプト
# 月間の日報を集計して統計情報を出力します

# 設定ファイルを読み込む
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh" 2>/dev/null || WORK_DIR="${SCRIPT_DIR}"

# デフォルト値
OUTPUT_FORMAT="text"
GENERATE_GRAPH=false

# 使用方法を表示
show_usage() {
    cat << EOF
月次サマリスクリプト - 日報の月次集計

使用方法:
  $0 [OPTIONS]

OPTIONS:
  -y YEAR       年を指定 (例: 2025)
  -m MONTH      月を指定 (例: 11)
  -f FORMAT     出力形式を指定 (text|json|html) [デフォルト: text]
  -g            グラフを生成 (gnuplotが必要)
  -h            このヘルプを表示

例:
  $0                    # 今月のサマリを表示
  $0 -y 2025 -m 10      # 2025年10月のサマリを表示
  $0 -f json            # JSON形式で出力
  $0 -f html            # HTML形式で出力
  $0 -g                 # グラフも生成
EOF
}

# jqのチェック
if ! command -v jq &> /dev/null; then
    echo "エラー: jqが必要です。インストールしてください: brew install jq" >&2
    exit 1
fi

# 引数の解析
while getopts "y:m:f:gh" opt; do
    case $opt in
        y) TARGET_YEAR="$OPTARG" ;;
        m) TARGET_MONTH="$OPTARG" ;;
        f) OUTPUT_FORMAT="$OPTARG" ;;
        g) GENERATE_GRAPH=true ;;
        h) show_usage; exit 0 ;;
        *) show_usage; exit 1 ;;
    esac
done

# 年月が指定されていない場合は今月を使用
if [ -z "$TARGET_YEAR" ] || [ -z "$TARGET_MONTH" ]; then
    TARGET_YEAR=$(TZ=Asia/Tokyo date +%Y)
    TARGET_MONTH=$(TZ=Asia/Tokyo date +%m)
fi

# 月の0埋め処理
TARGET_MONTH=$(printf "%02d" $TARGET_MONTH)

# 対象ディレクトリ
TARGET_DIR="${WORK_DIR}/${TARGET_YEAR}/${TARGET_MONTH}"

# ディレクトリの存在チェック
if [ ! -d "$TARGET_DIR" ]; then
    echo "エラー: ${TARGET_YEAR}年${TARGET_MONTH}月の日報が見つかりません: ${TARGET_DIR}" >&2
    exit 1
fi

# 日報ファイルを収集
JSON_FILES=($(find "$TARGET_DIR" -name "*.json" -type f | sort))

if [ ${#JSON_FILES[@]} -eq 0 ]; then
    echo "エラー: ${TARGET_YEAR}年${TARGET_MONTH}月の日報ファイルが見つかりません" >&2
    exit 1
fi

# データ集計
TOTAL_HOURS=0
TOTAL_TASKS=0
declare -A KEYWORD_COUNT
declare -A DAILY_HOURS

# 各日報ファイルを処理
for json_file in "${JSON_FILES[@]}"; do
    # 日付を取得
    date=$(jq -r '.date // empty' "$json_file")
    if [ -z "$date" ]; then
        continue
    fi

    # タスク数を集計
    task_count=$(jq '.tasks | length' "$json_file" 2>/dev/null || echo 0)
    TOTAL_TASKS=$((TOTAL_TASKS + task_count))

    # 工数を集計
    day_hours=$(jq '[.tasks[].hours // 0] | add // 0' "$json_file" 2>/dev/null || echo 0)
    TOTAL_HOURS=$(echo "$TOTAL_HOURS + $day_hours" | bc)
    DAILY_HOURS["$date"]=$day_hours

    # キーワードを抽出（タスクタイトルとメモから）
    keywords=$(jq -r '.tasks[] | .title, .memo // "" | select(length > 0)' "$json_file" 2>/dev/null)
    while IFS= read -r line; do
        # スペースで分割して各単語をカウント
        for word in $line; do
            # 2文字以上の単語のみカウント
            if [ ${#word} -ge 2 ]; then
                KEYWORD_COUNT["$word"]=$((${KEYWORD_COUNT["$word"]:-0} + 1))
            fi
        done
    done <<< "$keywords"
done

# 工数の多かった日TOP5を抽出
TOP_DAYS=$(for date in "${!DAILY_HOURS[@]}"; do
    echo "${DAILY_HOURS[$date]} $date"
done | sort -rn | head -5)

# よく使われたキーワードTOP10
TOP_KEYWORDS=$(for keyword in "${!KEYWORD_COUNT[@]}"; do
    echo "${KEYWORD_COUNT[$keyword]} $keyword"
done | sort -rn | head -10)

# 出力処理
case "$OUTPUT_FORMAT" in
    text)
        output_text
        ;;
    json)
        output_json
        ;;
    html)
        output_html
        ;;
    *)
        echo "エラー: 無効な出力形式: $OUTPUT_FORMAT" >&2
        echo "有効な形式: text, json, html" >&2
        exit 1
        ;;
esac

# グラフ生成
if [ "$GENERATE_GRAPH" = true ]; then
    generate_graph
fi

exit 0

# テキスト形式で出力
output_text() {
    cat << EOF
========================================
月次サマリ: ${TARGET_YEAR}年${TARGET_MONTH}月
========================================

【基本統計】
  日報数: ${#JSON_FILES[@]}日
  総作業時間: ${TOTAL_HOURS}時間
  完了タスク数: ${TOTAL_TASKS}個
  平均作業時間/日: $(echo "scale=2; $TOTAL_HOURS / ${#JSON_FILES[@]}" | bc)時間

【工数の多かった日 TOP5】
EOF

    local rank=1
    while IFS= read -r line; do
        hours=$(echo "$line" | awk '{print $1}')
        date=$(echo "$line" | awk '{print $2}')
        echo "  ${rank}. ${date}: ${hours}時間"
        rank=$((rank + 1))
    done <<< "$TOP_DAYS"

    cat << EOF

【よく使われたキーワード TOP10】
EOF

    rank=1
    while IFS= read -r line; do
        count=$(echo "$line" | awk '{print $1}')
        keyword=$(echo "$line" | cut -d' ' -f2-)
        echo "  ${rank}. ${keyword}: ${count}回"
        rank=$((rank + 1))
    done <<< "$TOP_KEYWORDS"

    echo ""
    echo "=========================================="
}

# JSON形式で出力
output_json() {
    # TOP5の日をJSON配列に変換
    local top_days_json="["
    local first=true
    while IFS= read -r line; do
        hours=$(echo "$line" | awk '{print $1}')
        date=$(echo "$line" | awk '{print $2}')
        if [ "$first" = true ]; then
            first=false
        else
            top_days_json+=","
        fi
        top_days_json+="{\"date\":\"$date\",\"hours\":$hours}"
    done <<< "$TOP_DAYS"
    top_days_json+="]"

    # TOP10のキーワードをJSON配列に変換
    local top_keywords_json="["
    first=true
    while IFS= read -r line; do
        count=$(echo "$line" | awk '{print $1}')
        keyword=$(echo "$line" | cut -d' ' -f2-)
        if [ "$first" = true ]; then
            first=false
        else
            top_keywords_json+=","
        fi
        # キーワードをエスケープ
        keyword_escaped=$(echo "$keyword" | jq -Rs .)
        top_keywords_json+="{\"keyword\":$keyword_escaped,\"count\":$count}"
    done <<< "$TOP_KEYWORDS"
    top_keywords_json+="]"

    # 平均作業時間を計算
    local avg_hours=$(echo "scale=2; $TOTAL_HOURS / ${#JSON_FILES[@]}" | bc)

    # JSON出力
    jq -n \
        --arg year "$TARGET_YEAR" \
        --arg month "$TARGET_MONTH" \
        --arg total_days "${#JSON_FILES[@]}" \
        --arg total_hours "$TOTAL_HOURS" \
        --arg total_tasks "$TOTAL_TASKS" \
        --arg avg_hours "$avg_hours" \
        --argjson top_days "$top_days_json" \
        --argjson top_keywords "$top_keywords_json" \
        '{
            summary: {
                year: $year,
                month: $month,
                total_days: ($total_days | tonumber),
                total_hours: ($total_hours | tonumber),
                total_tasks: ($total_tasks | tonumber),
                average_hours_per_day: ($avg_hours | tonumber)
            },
            top_days: $top_days,
            top_keywords: $top_keywords
        }'
}

# HTML形式で出力
output_html() {
    local avg_hours=$(echo "scale=2; $TOTAL_HOURS / ${#JSON_FILES[@]}" | bc)

    cat << EOF
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>月次サマリ - ${TARGET_YEAR}年${TARGET_MONTH}月</title>
    <style>
        body {
            font-family: 'Helvetica Neue', Arial, 'Hiragino Kaku Gothic ProN', 'Hiragino Sans', Meiryo, sans-serif;
            max-width: 900px;
            margin: 40px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 3px solid #4CAF50;
            padding-bottom: 10px;
        }
        h2 {
            color: #555;
            margin-top: 30px;
            border-left: 4px solid #4CAF50;
            padding-left: 10px;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .stat-card {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 5px;
            border-left: 4px solid #4CAF50;
        }
        .stat-label {
            font-size: 0.9em;
            color: #666;
            margin-bottom: 5px;
        }
        .stat-value {
            font-size: 1.8em;
            font-weight: bold;
            color: #333;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #4CAF50;
            color: white;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .rank {
            font-weight: bold;
            color: #4CAF50;
        }
        .footer {
            margin-top: 30px;
            text-align: center;
            color: #999;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>月次サマリ - ${TARGET_YEAR}年${TARGET_MONTH}月</h1>

        <h2>基本統計</h2>
        <div class="stats">
            <div class="stat-card">
                <div class="stat-label">日報数</div>
                <div class="stat-value">${#JSON_FILES[@]}<span style="font-size: 0.5em;">日</span></div>
            </div>
            <div class="stat-card">
                <div class="stat-label">総作業時間</div>
                <div class="stat-value">${TOTAL_HOURS}<span style="font-size: 0.5em;">時間</span></div>
            </div>
            <div class="stat-card">
                <div class="stat-label">完了タスク数</div>
                <div class="stat-value">${TOTAL_TASKS}<span style="font-size: 0.5em;">個</span></div>
            </div>
            <div class="stat-card">
                <div class="stat-label">平均作業時間/日</div>
                <div class="stat-value">${avg_hours}<span style="font-size: 0.5em;">時間</span></div>
            </div>
        </div>

        <h2>工数の多かった日 TOP5</h2>
        <table>
            <thead>
                <tr>
                    <th style="width: 80px;">順位</th>
                    <th>日付</th>
                    <th>作業時間</th>
                </tr>
            </thead>
            <tbody>
EOF

    local rank=1
    while IFS= read -r line; do
        hours=$(echo "$line" | awk '{print $1}')
        date=$(echo "$line" | awk '{print $2}')
        echo "                <tr>"
        echo "                    <td class=\"rank\">${rank}</td>"
        echo "                    <td>${date}</td>"
        echo "                    <td>${hours}時間</td>"
        echo "                </tr>"
        rank=$((rank + 1))
    done <<< "$TOP_DAYS"

    cat << EOF
            </tbody>
        </table>

        <h2>よく使われたキーワード TOP10</h2>
        <table>
            <thead>
                <tr>
                    <th style="width: 80px;">順位</th>
                    <th>キーワード</th>
                    <th>出現回数</th>
                </tr>
            </thead>
            <tbody>
EOF

    rank=1
    while IFS= read -r line; do
        count=$(echo "$line" | awk '{print $1}')
        keyword=$(echo "$line" | cut -d' ' -f2-)
        echo "                <tr>"
        echo "                    <td class=\"rank\">${rank}</td>"
        echo "                    <td>${keyword}</td>"
        echo "                    <td>${count}回</td>"
        echo "                </tr>"
        rank=$((rank + 1))
    done <<< "$TOP_KEYWORDS"

    cat << EOF
            </tbody>
        </table>

        <div class="footer">
            Generated by monthly_summary.sh
        </div>
    </div>
</body>
</html>
EOF
}

# グラフ生成
generate_graph() {
    if ! command -v gnuplot &> /dev/null; then
        echo "警告: gnuplotがインストールされていないため、グラフを生成できません" >&2
        echo "インストール: brew install gnuplot" >&2
        return 1
    fi

    # データファイルを作成
    local data_file="/tmp/monthly_summary_${TARGET_YEAR}_${TARGET_MONTH}.dat"
    echo "# Date Hours" > "$data_file"

    for date in $(echo "${!DAILY_HOURS[@]}" | tr ' ' '\n' | sort); do
        hours=${DAILY_HOURS[$date]}
        echo "$date $hours" >> "$data_file"
    done

    # グラフファイル名
    local graph_file="${WORK_DIR}/monthly_summary_${TARGET_YEAR}_${TARGET_MONTH}.png"

    # gnuplotスクリプトを実行
    gnuplot << EOF
set terminal png size 1200,600 font "Arial,12"
set output "${graph_file}"
set title "月次作業時間グラフ - ${TARGET_YEAR}年${TARGET_MONTH}月"
set xlabel "日付"
set ylabel "作業時間（時間）"
set grid
set xdata time
set timefmt "%Y-%m-%d"
set format x "%m/%d"
set xtics rotate by -45
set style fill solid 0.5
set boxwidth 0.8 relative
plot "${data_file}" using 1:2 with boxes title "作業時間" linecolor rgb "#4CAF50"
EOF

    if [ -f "$graph_file" ]; then
        echo "グラフを生成しました: ${graph_file}"
    else
        echo "エラー: グラフの生成に失敗しました" >&2
        return 1
    fi

    # 一時ファイルを削除
    rm -f "$data_file"
}
